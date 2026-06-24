import Foundation
import UIKit
import BackgroundTasks
import Network
import CoreLocation

/// Main entry point for the CDAds SDK.
///
/// **Usage (native iOS app)**
/// ```swift
/// // AppDelegate.application(_:didFinishLaunchingWithOptions:)
/// // Identity values (host, partnerKey, etc.) come from CDAdsParams in Info.plist.
/// var config = CDAdsConfiguration()
/// config.environment = .test
/// config.logLevel    = .debug
/// CDAds.initialize(with: config)
/// ```
///
/// **Usage (Flutter plugin)**
/// The Flutter bridge calls `CDAds.initialize(with:)` then delegates all
/// subsequent calls to `CDAds.shared`.
///
/// **Background task requirement**
/// Add `"com.chalkdigital.cdads.backgroundLocationTask"` to
/// `BGTaskSchedulerPermittedIdentifiers` in the host app's Info.plist so iOS
/// will grant the periodic background processing slot.
@MainActor
public final class CDAds {

    // MARK: - Public

    public nonisolated static let sdkVersion      = "4.0.0"
    public nonisolated static let sdkBuildVersion = "1.0.0"

    /// Access the SDK after `initialize(with:)` has been called.
    /// Throws a fatal error in debug builds if called before initialisation.
    public static var shared: CDAds {
        guard let instance = _instance else {
            fatalError("CDAds.initialize(with:) must be called before accessing CDAds.shared.")
        }
        return instance
    }

    public private(set) var configuration: CDAdsConfiguration

    // MARK: - Modules (lazily created after init)

    public private(set) lazy var interstitialManager = CDAInterstitialAdManager(config: configuration)
    public private(set) lazy var rewardedVideoManager = CDARewardedVideoManager(config: configuration)
    public private(set) lazy var nativeAdManager = CDANativeAdManager(config: configuration)

    /// Location tracking module. Only active when `config.enableLocationTracking == true`.
    public private(set) lazy var location: CDALocationManager = CDALocationManager(config: configuration)

    // MARK: - Init

    /// Call once, as early as possible in app startup (inside `application(_:didFinishLaunchingWithOptions:)`).
    ///
    /// Pass `launchOptions` so the SDK can detect CoreLocation-triggered background launches
    /// (UIApplicationLaunchOptionsLocationKey — covers significant-location-change, region
    /// monitoring/geofence, and visit-monitoring relaunches alike) and resume location tracking
    /// immediately.
    /// Subsequent calls apply `configuration` to the already-running instance instead of
    /// re-running `start()` — important because `registerBackgroundTask()` calls
    /// `BGTaskScheduler.register(forTaskWithIdentifier:)`, which throws a fatal
    /// `NSInternalInconsistencyException` ("All launch handlers must be registered before
    /// application finishes launching") if invoked a second time after the app has finished
    /// launching. This split is what lets `cdads_flutter`'s plugin registration call this early
    /// with bare defaults (to satisfy that launch-timing requirement with no host-app
    /// AppDelegate changes required) while the real config arrives later via the Dart-side
    /// `CDAds.initialize()` Pigeon call.
    @discardableResult
    public static func initialize(with configuration: CDAdsConfiguration,
                                  launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> CDAds {
        if let existing = _instance {
            existing.applyConfiguration(configuration)
            return existing
        }
        let instance = CDAds(configuration: configuration)
        _instance = instance
        instance.start(launchOptions: launchOptions)
        return instance
    }

    /// Applies a configuration update to an already-running instance. Does not re-register
    /// the background task or restart network monitoring — both are one-time `start()` steps.
    private func applyConfiguration(_ newConfiguration: CDAdsConfiguration) {
        let wasLocationEnabled = configuration.enableLocationTracking
        configuration = newConfiguration
        CDALogger.configure(level: newConfiguration.logLevel)
        location.updateConfiguration(newConfiguration)
        if newConfiguration.enableLocationTracking, !wasLocationEnabled {
            location.start()
        } else if !newConfiguration.enableLocationTracking, wasLocationEnabled {
            location.stop()
        }
    }

    // MARK: - Runtime updates

    /// Update GDPR consent at runtime (e.g. after the consent dialog).
    public func updateConsent(gdprApplies: Bool, hasConsent: Bool) {
        configuration.gdprApplies = gdprApplies
        configuration.hasConsent  = hasConsent
        CDALogger.info("Consent updated — gdpr:\(gdprApplies) consent:\(hasConsent)")
    }

    /// Toggle location tracking without re-initialising the SDK.
    public func setLocationEnabled(_ enabled: Bool) {
        configuration.enableLocationTracking = enabled
        if enabled {
            location.start()
        } else {
            location.stop()
        }
    }

    // MARK: - Private

    static var _instance: CDAds?

    /// Background processing task identifier — must be declared in the host app's
    /// `BGTaskSchedulerPermittedIdentifiers` Info.plist array.
    private static let bgTaskIdentifier = "com.chalkdigital.cdads.backgroundLocationTask"

    private var networkMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "com.chalkdigital.cdads.networkMonitor", qos: .utility)

    private init(configuration: CDAdsConfiguration) {
        self.configuration = configuration
    }

    private func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        CDALogger.configure(level: configuration.logLevel)
        CDALogger.info("CDAds v\(CDAds.sdkVersion) initialising — env:\(configuration.environment)")

        // BGTaskScheduler registration must happen before the app finishes launching.
        registerBackgroundTask()

        // Start network reachability monitoring so we refresh the public IP on
        // each new network connection (mirrors ObjC CDNetworkReachabilityObserver).
        startNetworkMonitor()

        // Detect a CoreLocation-triggered background launch (significant-location-change,
        // geofence/region-monitoring exit, or visit monitoring all share this same key) so
        // we process the pending location fix before iOS suspends the app again.
        let launchedByLocationEvent = launchOptions?[.location] != nil
        if launchedByLocationEvent {
            CDALogger.info("App launched by a CoreLocation event — starting location manager")
        }

        if configuration.enableLocationTracking || launchedByLocationEvent {
            location.start()
        }
    }

    // MARK: - Background Processing Task (BGProcessingTaskRequest)

    /// Registers the SDK's background processing task with BGTaskScheduler.
    /// Must be called before `application(_:didFinishLaunchingWithOptions:)` returns.
    private func registerBackgroundTask() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            Task { @MainActor [weak self] in
                self?.handleBackgroundTask(task)
            }
        }
        CDALogger.debug("BGTaskScheduler registration \(registered ? "succeeded" : "failed") for \(Self.bgTaskIdentifier)")

        // Watch for background transitions to schedule the next run
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func applicationDidEnterBackground() {
        scheduleBackgroundTask()
    }

    /// Schedules the next background processing run (earliest 15 minutes from now,
    /// requires network connectivity).  Re-scheduled each time the task fires so it
    /// repeats indefinitely while the app is installed.
    private func scheduleBackgroundTask() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskIdentifier)
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        request.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(request)
            CDALogger.debug("Background task scheduled (earliest: 15 min)")
        } catch {
            CDALogger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Handles the BGProcessingTask: re-schedules the next run, flushes the
    /// pending location batch, then marks the task complete.
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Re-schedule immediately so the next run is already queued
        scheduleBackgroundTask()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await self.location.performBackgroundFetch()
            task.setTaskCompleted(success: true)
            CDALogger.debug("Background task completed")
        }
    }

    // MARK: - Network Reachability (NWPathMonitor)

    /// Monitors network path changes. When the network becomes reachable:
    ///  1. Clears the cached public IP so a fresh fetch occurs on the new interface.
    ///  2. Triggers `fetchPublicIP()` if location permission is granted.
    ///  3. Flushes any pending location batch.
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        // Seed synchronously — `pathUpdateHandler`'s first callback is asynchronous
        // and isn't guaranteed to have fired yet by the time a BGProcessingTask
        // launch immediately calls performBackgroundFetch() right after start().
        // Without this, that race left networkMonitorPath nil, so flushBatch()'s
        // network guard always skipped the upload — pending locations only ever
        // made it to the server on the next full foreground app launch, once the
        // monitor's callback had a chance to catch up.
        location.networkMonitorPath = monitor.currentPath
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Always keep location manager's path current so its network guard is reliable
                self.location.networkMonitorPath = path
                if path.status == .satisfied {
                    await self.handleNetworkBecameAvailable()
                } else {
                    CDALogger.debug("Network not reachable — batch uploads paused")
                }
            }
        }
        monitor.start(queue: networkMonitorQueue)
    }

    private func handleNetworkBecameAvailable() async {
        CDALogger.debug("Network became available — refreshing public IP")

        // Clear stale cached IP so the fetch uses the new network interface
        UserDefaults.standard.removeObject(forKey: "CDPublicIPKey")

        // Fetch public IP only when location permission is already granted.
        // Checking authorizationStatus alone is sufficient — an .authorized* status
        // implies services are enabled. Avoid CLLocationManager.locationServicesEnabled()
        // which can block the main thread.
        let authStatus = location.authorizationStatus
        if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
            await location.fetchPublicIP()
        }

        // Send any pending location records that may have queued while offline
        await location.performBackgroundFetch()
    }
}

// MARK: - Debug log access

public extension CDAds {

    /// Whether SDK log lines are being written to the in-app debug log
    /// (buffer + `debugLogFileURL`). Defaults to `false`. Completely
    /// independent of `configuration.logLevel`, which only controls
    /// Console.app/Xcode verbosity for development — this is the production
    /// "support mode" switch, equivalent to the old SDK's `CDFileLogsEnabled`.
    /// `CDADebugLogViewController`'s Enable button toggles this.
    static var isDebugFileLoggingEnabled: Bool {
        get { CDADebugLogStore.shared.isEnabled }
        set { CDADebugLogStore.shared.isEnabled = newValue }
    }

    /// The SDK's captured debug log text (oldest first) — populated only while
    /// `isDebugFileLoggingEnabled` is `true`. Drive an in-app log viewer with
    /// this instead of (or alongside) Console.app, since os_log's
    /// `.debug`/`.info` levels aren't reliably visible there without the
    /// device attached. See `CDADebugLogViewController` for a ready-made
    /// viewer, and `CDADebugTrigger` for the legacy `*##*` reveal code used in
    /// Tempo.
    static func debugLogs() -> String {
        CDADebugLogStore.shared.currentText()
    }

    /// Clears the in-app debug log buffer and its backing file.
    static func clearDebugLogs() {
        CDADebugLogStore.shared.clear()
    }

    /// File URL of the persisted debug log — pass to `UIActivityViewController`
    /// to share/export it.
    static var debugLogFileURL: URL {
        CDADebugLogStore.shared.fileURL
    }
}

// MARK: - Bridge-friendly nested aliases

/// Nested aliases, namespaced under `CDAds`, for SDK types whose bare name
/// collides with a same-named type generated by a host bridge (e.g. Pigeon,
/// for the Flutter plugin — its generated `CDAdsGeoInfo`/`CDAdsError` share a
/// bare name with these SDK types). Since `import CDAds` also brings the
/// `CDAds` *class* into scope, bridge code can't qualify by module name to
/// disambiguate (`CDAds.CDAdsGeoInfo` resolves as a member lookup on the
/// class, not the module) — these aliases give it a real member to find.
public extension CDAds {
    typealias GeoInfo = CDAdsGeoInfo
    typealias AdError = CDAdsError
    typealias NativeAdData = CDANativeAdData
    typealias Reward = CDAReward
}
