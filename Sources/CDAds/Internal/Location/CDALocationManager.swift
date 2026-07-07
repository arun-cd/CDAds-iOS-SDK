import Foundation
import AdSupport
import AppTrackingTransparency
import CoreLocation
import CoreTelephony
import Network
import UIKit

// MARK: - Constants

private let cdPublicIPKey = "CDPublicIPKey"
private let cdLastLocationUpdateTimeKey = "CDLastLocationUpdateTime"
private let cdLastKnownLocationKey = "CDLastKnownLocation"
private let cdLastTrackingLocationKey = "CDLastTrackingLocation"
private let cdPendingLocationsKey = "CDPendingLocations"
private let cdMaxPendingLocations = 500
private let cdBatchUploadLimit = 30
private let cdGeofenceChainIdentifier = "com.chalkdigital.cdads.chainedGeofence"
private let cdGeofenceChainRadius: CLLocationDistance = 200.0
private let cdDuplicateLocationTimeWindow: TimeInterval = 30.0
private let cdAcceptableAccuracy: CLLocationAccuracy = 65.0
private let cdMaxLocationManagerRunningInterval: TimeInterval = 30.0
private let cdMinBackgroundTime: TimeInterval = 60.0
private let cdMaxDwellTime: TimeInterval = 900.0

/// UserDefaults keys for server-pushed threshold overrides — names match the old
/// SDK's CDTrackingController.persistChanges: keys so the same backend response
/// shape can be reused.
private enum CDARemoteConfigKey {
    static let trackingInterval = "TrackingInterval"
    static let distanceFilter = "DistanceFilter"
    static let acceptableAccuracy = "AcceptableAccuracy"
    static let minBGTime = "MinBGTime"
    static let maxLocationManagerRunningInterval = "MaxLocationManagerRunningInterval"
    static let adLocationExpiryInterval = "AdLocationExpiryInterval"
}

/// Manages background location tracking and batch uploads to the ad server.
///
/// Enabled only when `CDAdsConfiguration.enableLocationTracking == true`.
/// The host app must include `NSLocationAlwaysAndWhenInUseUsageDescription`
/// in its Info.plist and request Always authorization before enabling this.
@MainActor
public final class CDALocationManager: NSObject {

    // MARK: - Public

    /// Notification posted on the main thread after the public IP is fetched or confirmed available.
    public static let publicIPFetchedNotification = Notification.Name("CDNotifyPublicIPFetched")

    /// Most recently recorded location.
    public private(set) var lastKnownLocation: CDAdsGeoInfo?

    /// Called on main thread whenever a new location batch is uploaded.
    public var onLocationUpdated: ((CDAdsGeoInfo) -> Void)?

    /// Current Core Location authorization status from the SDK's shared CLLocationManager instance.
    /// Use this instead of creating a new CLLocationManager just to read authorization status.
    var authorizationStatus: CLAuthorizationStatus {
        clManager.authorizationStatus
    }

    /// Awaits a location with at least a country code resolved — either a reverse-geocoded
    /// GPS fix or the IP-geolocation fallback — so callers that build ad requests don't fire
    /// before geo-targeting data is ready. The ad server can't return a fill without a
    /// country, so sending earlier than this is a wasted round trip. Polls briefly rather
    /// than blocking indefinitely: returns whatever's cached (possibly still nil) once
    /// `timeout` elapses, so a stalled network/geocoder doesn't block ads forever.
    ///
    /// Also mirrors old SDK's `shouldWaitToProceedForAdRequest`, which actively calls
    /// `fetchPublicIP` as part of this same ad-request-readiness check (unlike the
    /// reachability-changed callback, which only fetches if location permission already
    /// happens to be granted *at that exact moment* — a narrow window that can pass before
    /// the user answers the permission prompt, leaving the IP blank for the rest of the
    /// session otherwise). Every ad request gives the IP fetch another chance to happen.
    func waitForGeoReady(timeout: TimeInterval = 5.0) async -> CDAdsGeoInfo? {
        // When tracking is disabled and the user has never been asked, show the permission
        // dialog now (ad requests need location too) and wait for their response.
        // Once status moves away from .notDetermined, retry the full resolution logic.
        if !config.enableLocationTracking, clManager.authorizationStatus == .notDetermined {
            CDALogger.debug("waitForGeoReady: permission undetermined — requesting whenInUse authorization")
            clManager.requestWhenInUseAuthorization()
            let permDeadline = Date().addingTimeInterval(timeout)
            while Date() < permDeadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if clManager.authorizationStatus != .notDetermined {
                    CDALogger.debug("waitForGeoReady: permission resolved (\(clManager.authorizationStatus.rawValue)) — retrying geo resolution")
                    return await waitForGeoReady(timeout: timeout)
                }
            }
            CDALogger.debug("waitForGeoReady: permission dialog not answered within timeout — ad request suppressed")
            return nil
        }

        let lastUpdateTime = UserDefaults.standard.double(forKey: cdLastLocationUpdateTimeKey)
        let age: TimeInterval = lastUpdateTime > 0
            ? Date().timeIntervalSince1970 - lastUpdateTime
            : .infinity
        let permission = clManager.authorizationStatus
        let hasGPSPermission = permission == .authorizedAlways || permission == .authorizedWhenInUse

        if age > effectiveAdLocationExpiryInterval, hasGPSPermission {
            // Location is stale but GPS is available — request a fresh one-shot fix.
            // handleAcceptedFix will update lastKnownLocation immediately on receipt.
            if !isManagerRunning {
                locationFetchTrigger = "AdRequest"
                startLocationFix()
            }
        } else if age <= effectiveAdLocationExpiryInterval,
                  let loc = lastKnownLocation, loc.countryCode != nil {
            // Location is fresh and fully resolved — return immediately.
            return loc
        } else if age <= effectiveAdLocationExpiryInterval,
                  let loc = lastKnownLocation {
            // Fresh GPS fix exists but countryCode not yet resolved (GC/SLC skips geocoding).
            // Reverse geocode the existing coordinates now to enrich city/region/zip/countryCode.
            await reverseGeocode(location: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
        } else {
            // Stale location with no GPS permission, or no location at all — use IP fallback.
            await useIPGeolocationFallbackIfNeeded()
        }

        // Poll until a fully-resolved location (with countryCode) arrives or timeout expires.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let loc = lastKnownLocation, loc.countryCode != nil { return loc }
        }
        // Return nil if countryCode still unavailable — callers must not fire the ad request
        // without a country code, as the ad server requires it for routing (e.g. Japan subdomain).
        guard let loc = lastKnownLocation, loc.countryCode != nil else {
            CDALogger.debug("waitForGeoReady timed out — no countryCode resolved, ad request suppressed")
            return nil
        }
        return loc
    }

    /// Returns `true` if a public IP is cached in UserDefaults.
    public static var isPublicIPAvailable: Bool {
        let ip = UserDefaults.standard.string(forKey: cdPublicIPKey)
        return ip != nil && !ip!.isEmpty
    }

    // MARK: - Init

    init(config: CDAdsConfiguration) {
        self.config = config
        super.init()
        clManager.delegate           = self
        clManager.desiredAccuracy    = kCLLocationAccuracyHundredMeters
        clManager.distanceFilter     = config.locationDistanceFilter
        clManager.pausesLocationUpdatesAutomatically = false
        // Only opt in to background location updates when tracking is actually
        // enabled — setting this to true throws an NSInternalInconsistencyException
        // on hosts that haven't declared the `location` UIBackgroundModes entry,
        // which most apps using only the manual geo/IP override path will not have.
        if config.enableLocationTracking {
            clManager.allowsBackgroundLocationUpdates = true
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        restorePersistedState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    func start() {
        // Do not call CLLocationManager.locationServicesEnabled() here — it can
        // block the main thread. Authorization status already encodes device-level
        // restrictions: .restricted means services are off system-wide, .denied
        // means the user refused. Both are handled by the default case below.
        CDALogger.debug("start() called — authorizationStatus:\(clManager.authorizationStatus.rawValue) enableLocationTracking:\(config.enableLocationTracking)")
        switch clManager.authorizationStatus {
        case .authorizedAlways:
            // Arm SLC/visit monitoring as soon as Always is granted, not only on the
            // next background transition — mirrors old SDK's
            // checkAuthorizationAndStartLocationService, and means a process restart
            // with permission already granted still has a background fallback armed
            // even if the app never gets a chance to background cleanly.
            armSignificantChangeMonitoringIfNeeded()
            startLocationFix()
            startBatchUploadTimer()
            CDALogger.info("Location tracking started (authorizedAlways)")
        case .authorizedWhenInUse:
            startLocationFix()
            startBatchUploadTimer()
            CDALogger.info("Location tracking started (authorizedWhenInUse — no background tracking until Always is granted)")
        case .notDetermined:
            CDALogger.debug("Authorization not determined — requesting Always authorization")
            clManager.requestAlwaysAuthorization()
        case .restricted:
            CDALogger.warn("Location services restricted at system level")
            Task { @MainActor [weak self] in
                await self?.useIPGeolocationFallbackIfNeeded()
            }
        default:
            CDALogger.warn("Location permission not granted (status:\(clManager.authorizationStatus.rawValue)) — tracking disabled, using IP fallback")
            Task { @MainActor [weak self] in
                await self?.useIPGeolocationFallbackIfNeeded()
            }
        }
    }

    private func armSignificantChangeMonitoringIfNeeded() {
        guard !isMonitoringSignificantChanges else {
            CDALogger.debug("SLC/Visit monitoring already armed — skipping")
            return
        }
        clManager.startMonitoringSignificantLocationChanges()
        clManager.startMonitoringVisits()
        isMonitoringSignificantChanges = true
        CDALogger.debug("SLC + Visit monitoring armed")
    }

    func stop() {
        clManager.stopUpdatingLocation()
        if isMonitoringSignificantChanges {
            clManager.stopMonitoringSignificantLocationChanges()
            clManager.stopMonitoringVisits()
            isMonitoringSignificantChanges = false
        }
        disableGeofenceChaining()
        isManagerRunning = false
        batchTimer?.invalidate()
        batchTimer = nil
        CDALogger.info("Location tracking stopped")
    }

    /// Applies a config update after construction — e.g. when the Flutter plugin's early,
    /// bare-default `CDAds.initialize()` call (made to satisfy BGTaskScheduler's launch-timing
    /// requirement, before `location` is force-created by `startNetworkMonitor()`) is later
    /// followed by the Dart-side call carrying the real config. `allowsBackgroundLocationUpdates`
    /// and `distanceFilter` are otherwise init-time-only, so without this they'd stay stuck on
    /// whatever was active the first time `location` was accessed.
    func updateConfiguration(_ newConfig: CDAdsConfiguration) {
        config = newConfig
        clManager.distanceFilter = newConfig.locationDistanceFilter
        clManager.allowsBackgroundLocationUpdates = newConfig.enableLocationTracking
    }

    // MARK: - Location fix request

    private func startLocationFix() {
        guard !isManagerRunning else {
            CDALogger.debug("[trigger:\(locationFetchTrigger)] fetch cycle already running — skipping")
            return
        }
        isManagerRunning = true
        locationManagerStartTime = Date().timeIntervalSince1970
        CDALogger.debug("[trigger:\(locationFetchTrigger)] requestLocation() called")
        clManager.requestLocation()
    }

    // MARK: - Remote config overrides

    /// Reads a server-pushed override from UserDefaults, falling back to `defaultValue`
    /// when absent or non-positive — mirrors old SDK's CDUtil getCD*-style getters.
    private func overridable(_ key: String, default defaultValue: Double) -> Double {
        let stored = UserDefaults.standard.double(forKey: key)
        return stored > 0 ? stored : defaultValue
    }

    private var effectiveTrackingInterval: TimeInterval {
        overridable(CDARemoteConfigKey.trackingInterval, default: config.locationUpdateInterval)
    }
    private var effectiveDistanceFilter: CLLocationDistance {
        overridable(CDARemoteConfigKey.distanceFilter, default: config.locationDistanceFilter)
    }
    private var effectiveAcceptableAccuracy: CLLocationAccuracy {
        overridable(CDARemoteConfigKey.acceptableAccuracy, default: cdAcceptableAccuracy)
    }
    private var effectiveMinBackgroundTime: TimeInterval {
        overridable(CDARemoteConfigKey.minBGTime, default: cdMinBackgroundTime)
    }
    private var effectiveMaxLocationManagerRunningInterval: TimeInterval {
        overridable(CDARemoteConfigKey.maxLocationManagerRunningInterval, default: cdMaxLocationManagerRunningInterval)
    }
    private var effectiveAdLocationExpiryInterval: TimeInterval {
        overridable(CDARemoteConfigKey.adLocationExpiryInterval, default: config.locationExpiryInterval)
    }

    /// Persists server-pushed threshold overrides from a `/track` response —
    /// mirrors old SDK's `CDTrackingController.persistChanges:`.
    private func applyRemoteConfigOverrides(_ body: CDTrackResponseBody?) {
        guard let body else { return }
        let defaults = UserDefaults.standard
        var applied: [String] = []
        if let v = body.trackingInterval, v > 0 { defaults.set(v, forKey: CDARemoteConfigKey.trackingInterval); applied.append("TrackingInterval=\(v)") }
        if let v = body.distanceFilter, v > 0 { defaults.set(v, forKey: CDARemoteConfigKey.distanceFilter); applied.append("DistanceFilter=\(v)") }
        if let v = body.acceptableAccuracy, v > 0 { defaults.set(v, forKey: CDARemoteConfigKey.acceptableAccuracy); applied.append("AcceptableAccuracy=\(v)") }
        if let v = body.minBGTime, v > 0 { defaults.set(v, forKey: CDARemoteConfigKey.minBGTime); applied.append("MinBGTime=\(v)") }
        if let v = body.maxLocationManagerRunningInterval, v > 0 {
            defaults.set(v, forKey: CDARemoteConfigKey.maxLocationManagerRunningInterval)
            applied.append("MaxLocationManagerRunningInterval=\(v)")
        }
        if let v = body.adLocationExpiryInterval, v > 0 {
            defaults.set(v, forKey: CDARemoteConfigKey.adLocationExpiryInterval)
            applied.append("AdLocationExpiryInterval=\(v)")
        }
        if !applied.isEmpty {
            CDALogger.debug("Remote config overrides applied: \(applied.joined(separator: ", "))")
        }
    }

    // MARK: - Public IP

    /// Fetches the device's public IP and caches it in UserDefaults.
    /// Posts `publicIPFetchedNotification` on completion (success or failure).
    ///
    /// Concurrent callers (e.g. two banners loading within milliseconds of each other at
    /// launch, each going through `waitForGeoReady()`) await the *same* in-flight fetch
    /// instead of one bailing out immediately — the previous `guard !inProgress else return`
    /// let the second caller's ad/tracking request proceed with a still-blank IP even though
    /// the first caller's fetch succeeded a moment later, which is exactly the "1st/2nd
    /// request blank, 3rd/4th has it" pattern.
    func fetchPublicIP() async {
        if Self.isPublicIPAvailable {
            NotificationCenter.default.post(name: Self.publicIPFetchedNotification, object: nil)
            return
        }
        if let existing = publicIPFetchTask {
            await existing.value
            return
        }
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            let cmsBase = CDAPlistParams.shared.effectiveCmsApiURL()
            guard let url = URL(string: "\(cmsBase)/geocode/ip2geo/v1") else { return }
            CDALogger.debug("Fetching public IP from \(url)")
            do {
                let response = try await CDANetworkSession.shared.get(url, as: CDIPGeoResponse.self)
                if let ip = response.response?.clientIp, !ip.isEmpty {
                    UserDefaults.standard.set(ip, forKey: cdPublicIPKey)
                    CDALogger.debug("Public IP cached: \(ip)")
                }
            } catch {
                CDALogger.error("Public IP fetch failed: \(error.localizedDescription)")
            }
        }
        publicIPFetchTask = task
        await task.value
        publicIPFetchTask = nil
        NotificationCenter.default.post(name: Self.publicIPFetchedNotification, object: nil)
    }

    /// Falls back to IP-based geolocation for ad-serving when GPS isn't available
    /// (permission denied/restricted) — mirrors old SDK's
    /// `onLocationServiceNotAvailable`/`geolocateIP`. Reuses the cached location
    /// instead of re-fetching if it's still within `effectiveAdLocationExpiryInterval`.
    private func useIPGeolocationFallbackIfNeeded() async {
        let lastUpdate = UserDefaults.standard.double(forKey: cdLastLocationUpdateTimeKey)
        // Only skip the fetch if the cached location is both fresh AND fully resolved
        // (has a countryCode). A fresh-but-no-countryCode location still needs the
        // IP-geo call so the ad request can include country targeting.
        if lastUpdate > 0, let loc = lastKnownLocation, loc.countryCode != nil {
            let age = Date().timeIntervalSince1970 - lastUpdate
            if age < effectiveAdLocationExpiryInterval {
                CDALogger.debug("IP geolocation fallback skipped — cached location still fresh (\(Int(age))s old)")
                return
            }
        }
        await fetchIPGeolocationFallback()
    }

    private func fetchIPGeolocationFallback() async {
        let cmsBase = CDAPlistParams.shared.effectiveCmsApiURL()
        guard let url = URL(string: "\(cmsBase)/geocode/ip2geo/v1") else { return }
        CDALogger.debug("Fetching IP geolocation fallback from \(url)")
        do {
            let response = try await CDANetworkSession.shared.get(url, as: CDIPGeoResponse.self)
            guard let body = response.response, let lat = body.latitude, let lon = body.longitude else {
                CDALogger.warn("IP geolocation fallback — no coordinates in response")
                return
            }
            if let ip = body.clientIp, !ip.isEmpty {
                UserDefaults.standard.set(ip, forKey: cdPublicIPKey)
            }
            var geo = CDAdsGeoInfo(latitude: lat, longitude: lon)
            geo.sourceType = .ipLookup
            geo.ipAddress  = body.clientIp
            lastKnownLocation = geo
            if let data = try? JSONEncoder().encode(geo) {
                UserDefaults.standard.set(data, forKey: cdLastKnownLocationKey)
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cdLastLocationUpdateTimeKey)
            onLocationUpdated?(geo)
            CDALogger.info("IP geolocation fallback resolved (\(lat), \(lon))")
            NotificationCenter.default.post(name: Self.publicIPFetchedNotification, object: nil)
            await reverseGeocode(location: CLLocation(latitude: lat, longitude: lon))
        } catch {
            CDALogger.error("IP geolocation fallback failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private var config: CDAdsConfiguration
    private let clManager = CLLocationManager()
    private var batchTimer: Timer?
    private var pendingLocations: [CDALocationEntry] = []
    private var isFlushingBatch = false

    // Current network path — updated by CDAds NWPathMonitor, used to gate batch uploads
    var networkMonitorPath: NWPath?

    // Geofence chaining state
    private var isMonitoringGeofence = false
    private var isMonitoringSignificantChanges = false

    // Single-shot fetch cycle state — set on requestLocation(), cleared on didUpdateLocations.
    private var locationManagerStartTime: TimeInterval = 0
    private var isManagerRunning = false

    // Trigger label written to logs (SLC = significant location change, GC = geofence chain)
    private var locationFetchTrigger = "unknown"

    // Public IP fetch guard
    private var publicIPFetchTask: Task<Void, Never>?

    // Last raw CLLocation for deduplication
    private var lastRawLocation: CLLocation?

    // Timestamp of the most recently accepted fix — used in didExitRegion to suppress a
    // GC-triggered fetch when SLC/visit already handled the same movement event.
    private var lastAcceptedFixTime: TimeInterval = 0

    // Anchor for dwell-time merging — kept independent of `pendingLocations` (which
    // empties on every successful upload) so dwell accumulation survives across
    // upload boundaries, mirroring old SDK's separately persisted CDLastTrackingLocation.
    private var lastTrackingEntry: CDALocationEntry?

    // Reverse geocoding
    private let geocoder = CLGeocoder()
    private var isReverseGeocodingLocation = false

    // MARK: - Persistence

    private func restorePersistedState() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: cdLastKnownLocationKey),
           let geo = try? JSONDecoder().decode(CDAdsGeoInfo.self, from: data) {
            lastKnownLocation = geo
            CDALogger.debug("Restored last known location: \(geo.latitude), \(geo.longitude)")
        }
        if let data = defaults.data(forKey: cdPendingLocationsKey),
           let entries = try? JSONDecoder().decode([CDALocationEntry].self, from: data),
           !entries.isEmpty {
            pendingLocations = entries
            CDALogger.debug("Restored \(entries.count) pending location(s)")
        }
        if let data = defaults.data(forKey: cdLastTrackingLocationKey),
           let entry = try? JSONDecoder().decode(CDALocationEntry.self, from: data) {
            lastTrackingEntry = entry
        }
    }

    private func savePendingLocations() {
        if let data = try? JSONEncoder().encode(pendingLocations) {
            UserDefaults.standard.set(data, forKey: cdPendingLocationsKey)
        }
    }

    private func saveLastTrackingEntry() {
        if let data = try? JSONEncoder().encode(lastTrackingEntry) {
            UserDefaults.standard.set(data, forKey: cdLastTrackingLocationKey)
        }
    }

    // MARK: - App Lifecycle

    @objc private func handleAppDidEnterBackground() {
        CDALogger.debug("App entered background — authorizationStatus:\(clManager.authorizationStatus.rawValue)")
        guard clManager.authorizationStatus == .authorizedAlways else {
            CDALogger.debug("Not authorizedAlways — SLC/Visit/geofence backstops not armed")
            return
        }
        armSignificantChangeMonitoringIfNeeded()
        if let last = lastKnownLocation {
            enableGeofenceChainingAtLocation(last)
        } else {
            CDALogger.debug("No last known location yet — geofence chain not armed on this background transition")
        }
    }

    @objc private func handleAppWillEnterForeground() {
        CDALogger.debug("App entering foreground — disarming SLC/Visit backstops, keeping geofence chain active")
        if isMonitoringSignificantChanges {
            clManager.stopMonitoringSignificantLocationChanges()
            clManager.stopMonitoringVisits()
            isMonitoringSignificantChanges = false
        }
        // Geofence chain stays armed — it drives location recording in both foreground
        // and background. SLC/Visit are background-only backstops; the timer-based fixed
        // interval is intentionally not restarted here.
        if config.enableLocationTracking {
            startBatchUploadTimer()
        }
    }

    // MARK: - Geofence Chaining

    private func enableGeofenceChainingAtLocation(_ location: CDAdsGeoInfo) {
        guard clManager.authorizationStatus == .authorizedAlways else { return }
        disableGeofenceChaining()
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            radius: cdGeofenceChainRadius,
            identifier: cdGeofenceChainIdentifier
        )
        region.notifyOnExit  = true
        region.notifyOnEntry = false
        isMonitoringGeofence = true
        clManager.startMonitoring(for: region)
        CDALogger.debug("Geofence chain enabled at (\(location.latitude), \(location.longitude))")
    }

    private func disableGeofenceChaining() {
        guard isMonitoringGeofence else { return }
        for region in clManager.monitoredRegions where region.identifier == cdGeofenceChainIdentifier {
            clManager.stopMonitoring(for: region)
        }
        isMonitoringGeofence = false
        CDALogger.debug("Geofence chain disabled")
    }

    // MARK: - Location Deduplication

    /// Returns the better of two locations, or the incoming one if they are far apart / old enough.
    private func bestLocation(between previous: CLLocation?, and incoming: CLLocation) -> CLLocation {
        guard let prev = previous else { return incoming }
        let timeDiff = abs(prev.timestamp.timeIntervalSince1970 - incoming.timestamp.timeIntervalSince1970)
        let distance = prev.distance(from: incoming)
        guard timeDiff <= cdDuplicateLocationTimeWindow,
              distance <= effectiveDistanceFilter else {
            CDALogger.debug("[dedup] distinct location (\(String(format: "%.1f", distance))m apart, \(String(format: "%.0f", timeDiff))s apart) - using incoming")
            return incoming
        }
        // Within dedup window: keep the more accurate fix
        let winner: CLLocation
        let reason: String
        if prev.horizontalAccuracy >= 0 && incoming.horizontalAccuracy >= 0 {
            if prev.horizontalAccuracy <= incoming.horizontalAccuracy {
                winner = prev
                reason = "last location more accurate (\(String(format: "%.1f", prev.horizontalAccuracy))m vs \(String(format: "%.1f", incoming.horizontalAccuracy))m)"
            } else {
                winner = incoming
                reason = "incoming location more accurate (\(String(format: "%.1f", incoming.horizontalAccuracy))m vs \(String(format: "%.1f", prev.horizontalAccuracy))m)"
            }
        } else if prev.horizontalAccuracy >= 0 {
            winner = prev
            reason = "last location has valid accuracy, incoming does not"
        } else {
            winner = incoming
            reason = "incoming location has valid accuracy, last does not"
        }
        CDALogger.debug("[dedup] duplicate location (\(String(format: "%.1f", distance))m apart, \(String(format: "%.0f", timeDiff))s apart) - kept \(winner === prev ? "last" : "incoming") - reason: \(reason)")
        return winner
    }

    // MARK: - Timer & Upload

    /// Flush any pending locations immediately (called by the BGProcessingTask handler).
    /// BGProcessingTask's execution budget isn't meant for an active GPS fetch — this is
    /// purely a network-sync pass over whatever SLC/Visit/geofence callbacks already
    /// queued, not a trigger for a fresh location request.
    func performBackgroundFetch() async {
        await flushBatch()
    }

    /// Appends a new tracking entry whenever *either* the device has moved at least
    /// `effectiveDistanceFilter` *or* `cdMaxDwellTime` has elapsed since the last
    /// *tracked* point — distance and dwell time are OR'd, not AND'ed. While neither
    /// condition is met, the fix is merged into the last entry by accumulating dwell
    /// time instead of inserting a new row. Once `cdMaxDwellTime` is reached, dwell
    /// time stops accumulating on that row — the incoming fix is recorded as a fresh
    /// entry instead (with its own dwell time starting back at zero), even though it
    /// may be at the same location as the last one. Mirrors old SDK's
    /// `CDTrackingController.updateLocation:` dwell-time collapsing, so a stationary
    /// device produces one row per `cdMaxDwellTime` rather than one per fix.
    ///
    /// The merge anchor is `lastTrackingEntry`, not `pendingLocations.last` — the
    /// pending queue empties on every successful upload, so anchoring on it would
    /// reset dwell accumulation to zero right after each flush.
    private func appendOrMergeIntoPendingLocations(_ entry: CDALocationEntry) {
        if let last = lastTrackingEntry {
            let lastLocation = CLLocation(latitude: last.geo.latitude, longitude: last.geo.longitude)
            let newLocation = CLLocation(latitude: entry.geo.latitude, longitude: entry.geo.longitude)
            let distance = lastLocation.distance(from: newLocation)
            if distance < effectiveDistanceFilter {
                let dwellTime = Double(entry.epocTime - last.epocTime)
                guard dwellTime > 0 else {
                    CDALogger.debug("[dwell] dropped — non-positive dwell time")
                    return
                }
                if dwellTime < cdMaxDwellTime {
                    var merged = entry
                    merged.dwellTime = last.dwellTime + dwellTime
                    // If the anchor row is still sitting in the queue (not yet
                    // uploaded), update it in place instead of adding a new row.
                    // If it's already been uploaded and evicted, append fresh —
                    // the cumulative dwellTime still carries forward correctly.
                    if let idx = pendingLocations.indices.last,
                       pendingLocations[idx].epocTime == last.epocTime,
                       pendingLocations[idx].geo.latitude == last.geo.latitude,
                       pendingLocations[idx].geo.longitude == last.geo.longitude {
                        pendingLocations[idx] = merged
                    } else {
                        pendingLocations.append(merged)
                        capPendingLocations()
                    }
                    savePendingLocations()
                    lastTrackingEntry = merged
                    saveLastTrackingEntry()
                    CDALogger.debug("[dwell] merged, dwellTime now \(merged.dwellTime)s")
                    return
                }
            }
        }
        pendingLocations.append(entry)
        capPendingLocations()
        savePendingLocations()
        lastTrackingEntry = entry
        saveLastTrackingEntry()
        CDALogger.debug("[queue] appended new tracking entry — pendingLocations.count:\(pendingLocations.count)")
    }

    private func capPendingLocations() {
        if pendingLocations.count > cdMaxPendingLocations {
            pendingLocations.removeFirst(pendingLocations.count - cdMaxPendingLocations)
        }
    }

    private func startBatchUploadTimer() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(
            withTimeInterval: effectiveTrackingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.flushBatch()
            }
        }
    }

    // Entry point for every external trigger (timer, didUpdateLocations, BG fetch,
    // authorization changes). `flushBatchLocked` itself awaits a network call, which
    // yields the @MainActor — without this guard, two overlapping triggers each
    // snapshot the same `pendingLocations` prefix, and the second one's eventual
    // `removeFirst(batch.count)` uses a now-stale count, crashing past the array's
    // (already shrunk by the first call) bounds.
    private func flushBatch(retryCount: Int = 2) async {
        guard !isFlushingBatch else { return }
        isFlushingBatch = true
        defer { isFlushingBatch = false }
        await flushBatchLocked(retryCount: retryCount)
    }

    private func flushBatchLocked(retryCount: Int) async {
        guard !pendingLocations.isEmpty else { return }

        // Mirror ObjC CDTrackingController: skip the upload when network is not
        // reachable.  NWPathMonitor keeps `currentNetworkPath` current at all
        // times (including background SLC launches), so this check is reliable.
        guard CDAds._instance.flatMap({ _ in networkMonitorPath })?.status == .satisfied else {
            CDALogger.debug("Batch Tracking Request skipped — network not available")
            return
        }

        guard let config = CDAds._instance?.configuration else { return }
        let serverBase = CDAPlistParams.shared.serverURL ?? config.effectiveHost
        guard let url = URL(string: "\(serverBase)/track") else { return }

        // Upload at most cdBatchUploadLimit (30) at a time, oldest first, recursing
        // until the queue drains — mirrors old SDK's CDTrackingController fetchLimit,
        // avoiding one huge POST after a long offline spell. Entries only leave
        // `pendingLocations` once their chunk is confirmed uploaded.
        let batch = Array(pendingLocations.prefix(cdBatchUploadLimit))

        CDALogger.debug("Batch Tracking Request Url: \(url)")
        do {
            // Mirrors old SDK's CDDeviceInfo.dnt gate exactly: device-identifying fields are
            // only populated when tracking is enabled AND the host app has told the SDK it
            // already has the user's tracking permission (clientHasUserTrackingPermission —
            // NOT a generic GDPR/consent flag); otherwise they're blanked and uid is zeroed.
            let trackingConsented = config.enableTracking && config.clientHasUserTrackingPermission
            let screen = screenSize()
            let body = CDALocationBatchBody(
                sdkTrackingEnabled:        trackingConsented ? 1 : 0,
                limitedAdvertiserTracking: limitedAdTracking(),
                deviceType:                trackingConsented ? "\(deviceTypeCode())" : "",
                deviceMake:                trackingConsented ? "apple" : "",
                deviceModel:               trackingConsented ? UIDevice.current.model : "",
                deviceOS:                  trackingConsented ? "iOS" : "",
                osVersion:                 trackingConsented ? UIDevice.current.systemVersion : "",
                uidType:                   trackingConsented ? "IDFA" : "",
                hardwareVersion:           trackingConsented ? hardwareVersionIdentifier() : "",
                jsenabled:                 trackingConsented ? .enabled : .blank,
                h:                         trackingConsented ? "\(screen.height)" : "",
                w:                         trackingConsented ? "\(screen.width)" : "",
                pixelRatio:                trackingConsented ? String(format: "%.1f", UIScreen.main.scale) : "",
                carrier:                   trackingConsented ? (resolveCarrierName() ?? "") : "",
                connectionType:            trackingConsented ? "\(currentConnectionType())" : "",
                uid:                       trackingConsented ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : "00000000-0000-0000-0000-000000000000",
                language:                  trackingConsented ? (Bundle.main.preferredLocalizations.first ?? "") : "",
                sdkkey:                    CDAPlistParams.shared.partnerKey ?? "",
                sdkversion:                CDAds.sdkVersion,
                sdkbuildversion:           CDAds.sdkBuildVersion,
                locationdata:              batch.map(CDALocationPayload.init)
            )
            let trackResponse = try await CDANetworkSession.shared.post(url, body: body, as: CDTrackResponse.self)

            // A 2xx HTTP status only means the request was *received* — old SDK's actual
            // sync confirmation is the response body's own `status` field (0 == success),
            // checked separately in CDTrackingController.m before ever deleting synced
            // rows. Without this, a 200 response carrying an application-level failure
            // (e.g. a validation/persistence error on the server) would still wipe
            // `pendingLocations` here even though the server never durably stored them.
            guard trackResponse.status == 0 else {
                CDALogger.error("Batch Tracking Request failed — server status:\(trackResponse.status.map(String.init) ?? "nil"), not deleting pending locations")
                return
            }

            applyRemoteConfigOverrides(trackResponse.response)
            CDALogger.debug("Uploaded \(batch.count) location(s)")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cdLastLocationUpdateTimeKey)
            pendingLocations.removeFirst(batch.count)
            savePendingLocations()
            if let last = batch.last {
                lastKnownLocation = last.geo
                if let data = try? JSONEncoder().encode(last.geo) {
                    UserDefaults.standard.set(data, forKey: cdLastKnownLocationKey)
                }
                onLocationUpdated?(last.geo)
            }
            if !pendingLocations.isEmpty {
                await flushBatchLocked(retryCount: 2)
            }
        } catch let err as NSError where err.code == NSURLErrorNetworkConnectionLost && retryCount > 0 {
            CDALogger.warn("Batch Tracking Request retrying (\(retryCount) left)")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await flushBatchLocked(retryCount: retryCount - 1)
        } catch {
            CDALogger.error("Location batch upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Connection type

    /// Returns 1 when limited, 0 when authorised — mirrors CDDeviceInfo.lmt. Old SDK never
    /// stringifies this field (always a raw NSNumber), unlike most of the other device fields.
    private func limitedAdTracking() -> Int {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized ? 0 : 1
        } else {
            return ASIdentifierManager.shared().isAdvertisingTrackingEnabled ? 0 : 1
        }
    }

    private func resolveCarrierName() -> String? {
        let info = CTTelephonyNetworkInfo()
        return info.serviceSubscriberCellularProviders?.values
            .first(where: { $0.carrierName != nil })?.carrierName
    }

    /// Numeric connection type matching old SDK CDDeviceInfo.connectiontype.
    /// 0=none, 2=WiFi, 3=cellular(unknown), 4=GPRS/Edge, 5=WCDMA/HSDPA, 6=LTE
    private func currentConnectionType() -> Int {
        guard let path = networkMonitorPath, path.status == .satisfied else { return 0 }
        if path.usesInterfaceType(.wifi) { return 2 }
        if path.usesInterfaceType(.cellular) {
            let info = CTTelephonyNetworkInfo()
            let radio = info.serviceCurrentRadioAccessTechnology?.values.first ?? ""
            switch radio {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge,
                 CTRadioAccessTechnologyCDMA1x:
                return 4
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA,
                 CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0,
                 CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB,
                 CTRadioAccessTechnologyeHRPD:
                return 5
            case CTRadioAccessTechnologyLTE:
                return 6
            default:
                return 3
            }
        }
        return 0
    }

    /// Matches old SDK CDDeviceInfo.devicetype: 5=iPad, 3=tvOS, 6=CarPlay, 4=iPhone/default.
    private func deviceTypeCode() -> Int {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return 5
        case .tv: return 3
        case .carPlay: return 6
        default: return 4
        }
    }

    /// Matches old SDK CDDeviceInfo.hwv — the machine identifier (e.g. "iPhone14,2") via uname().
    private func hardwareVersionIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    /// Matches old SDK's SCREEN_HEIGHT/SCREEN_WIDTH macros: UIScreen bounds, swapped to
    /// stay portrait-relative when the device is currently in a landscape orientation.
    private func screenSize() -> (height: Int, width: Int) {
        let bounds = UIScreen.main.bounds.size
        let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        let isPortrait = orientation == .portrait || orientation == .portraitUpsideDown || orientation == .unknown
        let height = isPortrait ? bounds.height : bounds.width
        let width  = isPortrait ? bounds.width  : bounds.height
        return (Int(height), Int(width))
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocode(location: CLLocation) async {
        guard !isReverseGeocodingLocation else { return }
        isReverseGeocodingLocation = true
        CDALogger.debug("Reverse geocoding lat:\(String(format: "%.6f", location.coordinate.latitude)) lon:\(String(format: "%.6f", location.coordinate.longitude))")
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en"))
            if let placemark = placemarks.first {
                let city        = placemark.locality ?? placemark.subLocality
                let region      = placemark.administrativeArea ?? placemark.subAdministrativeArea
                let zip         = placemark.postalCode
                // CLPlacemark gives alpha-2 ("JP"); old SDK converts to alpha-3 ("JPN") via
                // CDLocationManager.m's getAlpha3CountryCode: before storing it anywhere —
                // every downstream consumer (ad-request geo.country, JP ad-server subdomain
                // routing) expects alpha-3, so the conversion has to happen here at the source.
                let countryCode = placemark.isoCountryCode.flatMap { CDACountryCodes.alpha3(fromAlpha2: $0) }
                // Update the last pending entry with the enriched geo data — only if it
                // actually corresponds to this fix. Reverse geocoding is async and may
                // resolve after a newer fix has already been queued, so pendingLocations.last
                // could be a more recent, unrelated entry by the time this returns.
                if let idx = pendingLocations.indices.last,
                   pendingLocations[idx].geo.latitude == location.coordinate.latitude,
                   pendingLocations[idx].geo.longitude == location.coordinate.longitude {
                    pendingLocations[idx].geo.city        = city
                    pendingLocations[idx].geo.region      = region
                    pendingLocations[idx].geo.zip         = zip
                    pendingLocations[idx].geo.countryCode = countryCode
                    savePendingLocations()
                }
                // Also propagate to lastKnownLocation if it matches, and persist to UserDefaults
                // so the enriched geo (with countryCode) survives across calls.
                if var last = lastKnownLocation,
                   last.latitude == location.coordinate.latitude,
                   last.longitude == location.coordinate.longitude {
                    last.city        = city
                    last.region      = region
                    last.zip         = zip
                    last.countryCode = countryCode
                    lastKnownLocation = last
                    if let data = try? JSONEncoder().encode(last) {
                        UserDefaults.standard.set(data, forKey: cdLastKnownLocationKey)
                    }
                }
                CDALogger.debug("Reverse geocode: city:\(city ?? "-") region:\(region ?? "-") zip:\(zip ?? "-") country:\(countryCode ?? "-")")
            }
        } catch {
            CDALogger.warn("Reverse geocode failed: \(error.localizedDescription)")
        }
        isReverseGeocodingLocation = false
    }
}

// MARK: - CLLocationManagerDelegate

extension CDALocationManager: @preconcurrency CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let incoming = locations.last else { return }

        // When SLC/visit monitoring is what woke us (not our own gated fetch), accept
        // the fix directly — SLC/visit accuracy is coarse but already acceptable, same
        // as old SDK. Crucially, SLC/visit monitoring is left running (only disarmed on
        // foreground) so it stays armed as the background fallback in case the suspended
        // app can't get a Timer to fire for the next scheduled gated check.
        if isMonitoringSignificantChanges && !isManagerRunning {
            locationFetchTrigger = "SLC"
            CDALogger.debug("[trigger:SLC] significant location change received - starting location fetch")
            handleAcceptedFix(incoming)
            return
        }

        guard isManagerRunning else { return }

        let elapsedSinceStart = Date().timeIntervalSince1970 - locationManagerStartTime
        let accuracyAcceptable = incoming.horizontalAccuracy >= 0 && incoming.horizontalAccuracy <= effectiveAcceptableAccuracy
        guard accuracyAcceptable || elapsedSinceStart > effectiveMaxLocationManagerRunningInterval else {
            CDALogger.debug("[trigger:\(locationFetchTrigger)] rejected location update — accuracy \(String(format: "%.1f", incoming.horizontalAccuracy))m exceeds \(effectiveAcceptableAccuracy)m threshold")
            isManagerRunning = false
            return
        }

        isManagerRunning = false
        handleAcceptedFix(incoming)
    }

    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Leave SLC/visit monitoring running (see didUpdateLocations) — only disarmed on foreground.
        guard isMonitoringSignificantChanges, !isManagerRunning else { return }
        locationFetchTrigger = "Visit"
        CDALogger.debug("[trigger:Visit] visit received - starting location fetch")
        let visitLocation = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate
        )
        handleAcceptedFix(visitLocation)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways {
            armSignificantChangeMonitoringIfNeeded()
        }
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            startLocationFix()
            startBatchUploadTimer()
        } else if status == .denied || status == .restricted {
            Task { @MainActor [weak self] in
                await self?.useIPGeolocationFallbackIfNeeded()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        CDALogger.error("Location error: \(error.localizedDescription)")
        isManagerRunning = false
        // Next fix will be triggered by the next geofence exit or SLC wakeup.
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == cdGeofenceChainIdentifier else { return }
        isMonitoringGeofence = false
        CDALogger.debug("[trigger:GC] geofence exit received")
        // Skip if SLC/visit already accepted a fix within the dedup window — the geofence
        // exit may be a stale OS-queued callback for a fence that was already superseded
        // when SLC moved the anchor (e.g. SLC at 580m removes 400m fence, but iOS still
        // delivers the 400m exit event, causing a duplicate fix at ~600m).
        let timeSinceLastFix = Date().timeIntervalSince1970 - lastAcceptedFixTime
        guard lastAcceptedFixTime == 0 || timeSinceLastFix > cdDuplicateLocationTimeWindow else {
            CDALogger.debug("[trigger:GC] geofence exit — skipped, fix accepted \(Int(timeSinceLastFix))s ago (within \(Int(cdDuplicateLocationTimeWindow))s dedup window)")
            return
        }
        locationFetchTrigger = "GC"
        CDALogger.debug("[trigger:GC] geofence exit - starting location fetch")
        startBatchUploadTimer()
        startLocationFix()
    }

    /// Accepts a fix and routes it into dedup, the foreground/background tracking
    /// gate, the geofence re-arm, and reverse geocoding. Mirrors old SDK's
    /// `CDLocationManager.updateLocation:`.
    private func handleAcceptedFix(_ incoming: CLLocation) {
        lastAcceptedFixTime = Date().timeIntervalSince1970
        CDALogger.debug("[trigger:\(locationFetchTrigger)] didUpdateLocations - lat:\(String(format: "%.6f", incoming.coordinate.latitude)) lon:\(String(format: "%.6f", incoming.coordinate.longitude)) accuracy:\(String(format: "%.1f", incoming.horizontalAccuracy))m")

        let best = bestLocation(between: lastRawLocation, and: incoming)
        lastRawLocation = best

        var entry = CDALocationEntry(location: best)
        entry.geo.ipAddress  = UserDefaults.standard.string(forKey: cdPublicIPKey)
        entry.connectionType = currentConnectionType()

        // Update lastKnownLocation immediately so ad requests always see a current
        // location without waiting for the next batch upload (which may be minutes
        // away). cdLastLocationUpdateTimeKey is also stamped here so adLocationExpiryInterval
        // checks in waitForGeoReady() reflect the actual fix time, not the upload time.
        lastKnownLocation = entry.geo
        if let data = try? JSONEncoder().encode(entry.geo) {
            UserDefaults.standard.set(data, forKey: cdLastKnownLocationKey)
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cdLastLocationUpdateTimeKey)

        // Queue every eligible fix regardless of foreground/background state —
        // `appendOrMergeIntoPendingLocations` already decides, via `lastTrackingEntry`,
        // whether this is materially new (append) or a stationary re-fix (merge dwell
        // time instead of a fresh row), so foreground fixes get the same dedup as
        // background ones rather than a separate parameter.
        if config.enableLocationTracking {
            appendOrMergeIntoPendingLocations(entry)

            // In the background we rely on the periodic batch timer / BGProcessingTask
            // to drain the queue — no need to wake the radio on every single fix. In
            // the foreground there's no such constraint, so sync as soon as a fix is
            // eligible instead of waiting up to `effectiveTrackingInterval` for the timer.
            if UIApplication.shared.applicationState == .active {
                Task { @MainActor [weak self] in
                    await self?.flushBatch()
                }
            }
        }

        // Update geofence chain centred on the new best location
        enableGeofenceChainingAtLocation(entry.geo)

        // Reverse geocoding (city/region/zip/countryCode) is only needed before an ad request.
        // GC, SLC, and Visit triggers record raw lat/lon for tracking — no geocode API call needed.
        if locationFetchTrigger == "AdRequest" {
            Task { @MainActor [weak self] in
                await self?.reverseGeocode(location: best)
            }
        }
    }
}

// MARK: - Internal location entry (captures full CLLocation data + reverse-geocoded geo)

struct CDALocationEntry: Codable {
    var geo: CDAdsGeoInfo
    var altitude: Double
    var speed: Double
    var verticalAccuracy: Double
    var epocTime: Int        // Unix timestamp (seconds) when the fix was recorded
    var timezone: String
    var dwellTime: Double    // seconds dwell at this location
    var connectionType: Int  // old SDK numeric type: 0=none, 2=wifi, 3-6=cellular

    init(location: CLLocation) {
        geo = CDAdsGeoInfo(latitude: location.coordinate.latitude,
                           longitude: location.coordinate.longitude)
        geo.horizontalAccuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        geo.sourceType  = .gps
        altitude         = location.altitude
        speed            = location.speed >= 0 ? location.speed : 0
        verticalAccuracy = location.verticalAccuracy >= 0 ? location.verticalAccuracy : 0
        epocTime         = Int(location.timestamp.timeIntervalSince1970)
        timezone         = TimeZone.current.identifier
        dwellTime        = 0
        connectionType   = 0
    }
}

// MARK: - Internal payload models

/// `jsenabled` is the one field old SDK sends as a genuine JSON number when tracking is
/// consented (`_deviceInfo.js`, an NSNumber) but as an empty *string* when it isn't
/// (`@""` in the blanked branch) — i.e. its JSON type itself flips, not just its value.
private enum CDAJSEnabledValue: Encodable {
    case enabled
    case blank

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enabled: try container.encode(1)
        case .blank: try container.encode("")
        }
    }
}

/// Mirrors old SDK's `CDTrackingRequest.getParams()` exactly, including which fields are
/// formatted as `String` vs left as raw JSON numbers, and the `"locationdata"` key name.
/// `sdkTrackingEnabled`/`limitedAdvertiserTracking` are always raw numbers (0/1) — old SDK
/// never stringifies these two, unlike the other device-info fields. When tracking isn't
/// both enabled and consented to, the device-identifying fields are blanked and `uid` is
/// zeroed, mirroring old SDK's `dnt` gate exactly.
private struct CDALocationBatchBody: Encodable {
    let sdkTrackingEnabled: Int
    let limitedAdvertiserTracking: Int
    let deviceType: String
    let deviceMake: String
    let deviceModel: String
    let deviceOS: String
    let osVersion: String
    let uidType: String
    let hardwareVersion: String
    let jsenabled: CDAJSEnabledValue
    let h: String
    let w: String
    let pixelRatio: String
    let carrier: String
    let connectionType: String
    let uid: String
    let language: String
    let sdkkey: String
    let sdkversion: String
    let sdkbuildversion: String
    let locationdata: [CDALocationPayload]
}

/// Mirrors old SDK's per-location wire format exactly: a positional JSON array, not a
/// keyed object — `[lat, lon, altitude, speed, horizontalaccuracy, verticalaccuracy,
/// epoctime, timezone, connectiontype, provider, dwelltime, ipaddress]`. No city/region/
/// zip/countryCode — old SDK never sent reverse-geocode enrichment in `/track`.
private struct CDALocationPayload: Encodable {
    let lat: Double
    let lon: Double
    let altitude: Double
    let speed: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let epoctime: Int
    let timezone: String
    let connectiontype: Int
    let provider: Int
    let dwelltime: Double
    let ip: String

    init(_ entry: CDALocationEntry) {
        lat                = entry.geo.latitude
        lon                = entry.geo.longitude
        altitude           = entry.altitude
        speed              = entry.speed
        horizontalAccuracy = entry.geo.horizontalAccuracy ?? 0
        verticalAccuracy   = entry.verticalAccuracy
        epoctime           = entry.epocTime
        timezone           = entry.timezone
        connectiontype     = entry.connectionType
        provider           = entry.geo.sourceType.rawValue
        dwelltime          = entry.dwellTime
        ip                 = entry.geo.ipAddress ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lat)
        try container.encode(lon)
        try container.encode(altitude)
        try container.encode(speed)
        try container.encode(horizontalAccuracy)
        try container.encode(verticalAccuracy)
        try container.encode(epoctime)
        try container.encode(timezone)
        try container.encode(connectiontype)
        try container.encode(provider)
        try container.encode(dwelltime)
        try container.encode(ip)
    }
}

// MARK: - Track response model (carries remote config overrides)

private struct CDTrackResponseBody: Decodable {
    let trackingInterval: Double?
    let distanceFilter: Double?
    let acceptableAccuracy: Double?
    let minBGTime: Double?
    let maxLocationManagerRunningInterval: Double?
    let adLocationExpiryInterval: Double?

    enum CodingKeys: String, CodingKey {
        case trackingInterval = "TrackingInterval"
        case distanceFilter = "DistanceFilter"
        case acceptableAccuracy = "AcceptableAccuracy"
        case minBGTime = "MinBGTime"
        case maxLocationManagerRunningInterval = "MaxLocationManagerRunningInterval"
        case adLocationExpiryInterval = "AdLocationExpiryInterval"
    }
}

private struct CDTrackResponse: Decodable {
    let status: Int?
    let response: CDTrackResponseBody?
}

// MARK: - IP Geo response model

private struct CDIPGeoResponse: Decodable {
    struct Body: Decodable {
        let clientIp: String?
        let latitude: Double?
        let longitude: Double?

        // The real endpoint sends latitude/longitude as JSON strings (e.g. "0.0"), not
        // numbers. JSONDecoder doesn't coerce String -> Double by default, so the strict
        // `let latitude: Double?` synthesized decoder throws on every single response —
        // which silently failed the *entire* decode (clientIp included) every time,
        // regardless of when fetchPublicIP() ran.
        enum CodingKeys: String, CodingKey { case clientIp, latitude, longitude }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            clientIp  = try container.decodeIfPresent(String.self, forKey: .clientIp)
            latitude  = Self.flexibleDouble(container, .latitude)
            longitude = Self.flexibleDouble(container, .longitude)
        }

        private static func flexibleDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
            if let d = try? container.decodeIfPresent(Double.self, forKey: key) ?? nil { return d }
            if let s = try? container.decodeIfPresent(String.self, forKey: key) ?? nil { return Double(s) }
            return nil
        }
    }
    let status: Int?
    let response: Body?
}
