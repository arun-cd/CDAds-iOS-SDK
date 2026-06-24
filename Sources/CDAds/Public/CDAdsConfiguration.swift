import Foundation
import CoreLocation

/// Configuration for the CDAds SDK.
///
/// All required values can be supplied either in code or through the
/// `CDAdsParams` dictionary in the host app's `Info.plist`. Plist values
/// are used as fallbacks when the corresponding property is left empty.
///
/// **Minimal AppDelegate usage (all config in Info.plist):**
/// ```swift
/// var config = CDAdsConfiguration()
/// config.environment = .test
/// config.logLevel    = .debug
/// config.enableLocationTracking = true
/// CDAds.initialize(with: config)
/// ```
public struct CDAdsConfiguration {

    // MARK: - Identity (resolved from CDAdsParams plist when empty)

    public var partnerKey: String = ""
    public var host: String = ""
    public var appName: String = ""
    public var applicationIABCategory: String = ""

    // MARK: - Environment

    public var environment: Environment = .production

    // MARK: - Privacy & Consent

    public var gdprApplies: Bool = false
    public var hasConsent: Bool = false

    /// Set to `true` after the user grants App Tracking Transparency permission.
    public var clientHasUserTrackingPermission: Bool = false

    /// Master switch for all event and location tracking.
    public var enableTracking: Bool = false

    // MARK: - Location

    /// When `true` the SDK starts its background location manager and batches
    /// location updates to the server. Requires `NSLocationAlwaysAndWhenInUseUsageDescription`
    /// in the host app's Info.plist and the Always permission to be granted.
    public var enableLocationTracking: Bool = false

    /// Minimum distance (metres) the device must move before a new location
    /// update is triggered. Default is 100 m.
    public var locationDistanceFilter: CLLocationDistance = 100

    /// Interval (seconds) between periodic location batch uploads. Default 900 s (15 min).
    public var locationUpdateInterval: TimeInterval = 900

    /// How long (seconds) a cached location is considered fresh for ad targeting.
    /// Default 5 minutes.
    public var locationExpiryInterval: TimeInterval = 300

    // MARK: - Diagnostics

    public var logLevel: LogLevel = .off

    // MARK: - Init

    /// Creates a configuration with all identity values defaulting to empty.
    /// Values are resolved from `CDAdsParams` in Info.plist at runtime.
    public init() {}

    /// Creates a configuration with explicit values. Any non-empty value takes
    /// precedence over the corresponding `CDAdsParams` plist entry.
    public init(
        partnerKey: String = "",
        host: String = "",
        appName: String = "",
        applicationIABCategory: String = ""
    ) {
        self.partnerKey = partnerKey
        self.host = host
        self.appName = appName
        self.applicationIABCategory = applicationIABCategory
    }
}

// MARK: - Nested types

public extension CDAdsConfiguration {

    enum Environment {
        case production
        case test
    }

    enum LogLevel: Int {
        case all   = 0
        case trace = 10
        case debug = 20
        case info  = 30
        case warn  = 40
        case error = 50
        case fatal = 60
        case off   = 70
    }
}

// MARK: - Plist-resolved accessors (internal use only)

internal extension CDAdsConfiguration {

    /// Host URL resolved from plist `SERVER_URL` when `host` is empty.
    var effectiveHost: String {
        CDAPlistParams.shared.effectiveHost(fallback: host)
    }

    /// Partner key resolved from plist `CDADS_PARTNER_ID` when `partnerKey` is empty.
    var effectivePartnerKey: String {
        CDAPlistParams.shared.effectivePartnerKey(fallback: partnerKey)
    }

    /// IAB category resolved from plist `CDADS_CAT` when `applicationIABCategory` is empty.
    var effectiveIABCategory: String {
        CDAPlistParams.shared.effectiveIABCategory(fallback: applicationIABCategory)
    }

    /// App name resolved from plist `CDADS_APP_NAME` when `appName` is empty.
    var effectiveAppName: String {
        CDAPlistParams.shared.effectiveAppName(fallback: appName)
    }
}
