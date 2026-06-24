import Foundation
import CDAds

/// Persists test location/IP overrides in UserDefaults.
/// Values are applied via `CDAdsAdRequest.geoInfo` and `CDAdsAdRequest.ipAddress` —
/// the SDK's own supported override properties. Nothing is written to SDK-internal keys.
struct LocationOverrideSettings {

    private static let ud = UserDefaults.standard

    // MARK: - Keys (all prefixed cdtest_ — no overlap with SDK internals)

    private static let enabledKey  = "cdtest_enabled"
    private static let latKey      = "cdtest_lat"
    private static let lonKey      = "cdtest_lon"
    private static let cityKey     = "cdtest_city"
    private static let regionKey   = "cdtest_region"
    private static let zipKey      = "cdtest_zip"
    private static let countryKey  = "cdtest_country"
    private static let ipKey       = "cdtest_ip"

    // MARK: - Properties

    static var isEnabled: Bool {
        get { ud.bool(forKey: enabledKey) }
        set { ud.set(newValue, forKey: enabledKey) }
    }

    static var latitude: Double? {
        get { ud.object(forKey: latKey) as? Double }
        set {
            if let v = newValue { ud.set(v, forKey: latKey) }
            else                { ud.removeObject(forKey: latKey) }
        }
    }

    static var longitude: Double? {
        get { ud.object(forKey: lonKey) as? Double }
        set {
            if let v = newValue { ud.set(v, forKey: lonKey) }
            else                { ud.removeObject(forKey: lonKey) }
        }
    }

    static var city: String? {
        get { nonEmpty(ud.string(forKey: cityKey)) }
        set { ud.set(newValue ?? "", forKey: cityKey) }
    }

    static var region: String? {
        get { nonEmpty(ud.string(forKey: regionKey)) }
        set { ud.set(newValue ?? "", forKey: regionKey) }
    }

    static var zip: String? {
        get { nonEmpty(ud.string(forKey: zipKey)) }
        set { ud.set(newValue ?? "", forKey: zipKey) }
    }

    static var countryCode: String? {
        get { nonEmpty(ud.string(forKey: countryKey)) }
        set { ud.set(newValue ?? "", forKey: countryKey) }
    }

    static var ipAddress: String? {
        get { nonEmpty(ud.string(forKey: ipKey)) }
        set {
            if let ip = newValue, !ip.isEmpty { ud.set(ip, forKey: ipKey) }
            else                              { ud.removeObject(forKey: ipKey) }
        }
    }

    // MARK: - Helpers

    /// Returns a `CDAdsGeoInfo` for use as `CDAdsAdRequest.geoInfo`, or `nil` if
    /// the override is disabled or coordinates are not set.
    static func makeGeoInfo() -> CDAdsGeoInfo? {
        guard isEnabled, let lat = latitude, let lon = longitude else { return nil }
        var geo = CDAdsGeoInfo(latitude: lat, longitude: lon)
        geo.sourceType  = .userProvided
        geo.city        = city
        geo.region      = region
        geo.zip         = zip
        geo.countryCode = countryCode
        return geo
    }

    /// Returns the IP string for use as `CDAdsAdRequest.ipAddress`, or `nil` if
    /// the override is disabled or no IP is saved.
    static func makeIPAddress() -> String? {
        guard isEnabled else { return nil }
        return ipAddress
    }

    /// Removes all override keys. Does not touch any SDK-internal state.
    static func clear() {
        for key in [enabledKey, latKey, lonKey, cityKey, regionKey, zipKey, countryKey, ipKey] {
            ud.removeObject(forKey: key)
        }
    }

    private static func nonEmpty(_ s: String?) -> String? {
        s.flatMap { $0.isEmpty ? nil : $0 }
    }
}
