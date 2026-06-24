import Foundation

/// Reads the optional `CDAdsParams` dictionary from the host app's Info.plist.
///
/// Every key is optional — missing entries fall back to the values set on
/// `CDAdsConfiguration`. This lets apps supply all SDK config in the plist
/// with no required parameters in code.
///
/// ```xml
/// <key>CDAdsParams</key>
/// <dict>
///     <key>SERVER_URL</key>             <string>https://e-app.cmcd1.com</string>
///     <key>SERVER_PATH</key>            <string>/cmsdk</string>
///     <key>CDADS_PARTNER_KEY</key>       <string>YOUR_PARTNER_KEY</string>
///     <key>CDADS_PARTNER_ID</key>       <string>chalkboard</string>
///     <key>CDADS_APP_NAME</key>         <string>MyApp</string>
///     <key>CDADS_CAT</key>              <string>IAB1-6</string>
///     <key>CDADS_BUNDLE_ID</key>        <string>1210482071</string>
///     <key>CDADS_BUNDLE_ID_STRING</key> <string>com.example.app</string>
///     <key>CDADS_DEBUG_URL</key>        <string>https://nep.example.com/xp</string>
/// </dict>
/// ```
struct CDAPlistParams {

    static let shared = CDAPlistParams()

    // MARK: - Properties

    /// Base server URL — overrides `CDAdsConfiguration.host`.
    let serverURL: String?

    /// Path appended to `serverURL` when building ad-request URLs.
    let serverPath: String?

    /// SDK authentication key — sent as the `key` query parameter in every ad request.
    /// Equivalent to `CDInitialisationParams.partnerKey` in the old Objective-C SDK.
    let partnerKey: String?

    /// Partner / publisher ID — sent as the `pub` query parameter in ad requests.
    let partnerID: String?

    /// App name — overrides `CDAdsConfiguration.appName` when that is empty.
    let appName: String?

    /// IAB category — overrides `CDAdsConfiguration.applicationIABCategory` when that is empty.
    let iabCategory: String?

    /// Numeric App Store bundle ID sent as the `bundle` query parameter.
    let bundleID: String?

    /// Bundle identifier override used in test-environment ad requests.
    let bundleIDString: String?

    /// Optional debug/crash reporting endpoint.
    let debugURL: String?

    /// CMS API base URL for IP geolocation. Plist key: CDADS_CMS_URL.
    /// Defaults to https://cms-api.chalkdigital.com when not set.
    let cmsApiURL: String?

    // MARK: - Init

    private init() {
        let dict = (Bundle.main.infoDictionary?["CDAdsParams"] as? [String: String]) ?? [:]
        func val(_ key: String) -> String? { dict[key].flatMap { $0.isEmpty ? nil : $0 } }

        serverURL      = val("SERVER_URL")
        serverPath     = val("SERVER_PATH")
        partnerKey     = val("CDADS_PARTNER_KEY")
        partnerID      = val("CDADS_PARTNER_ID")
        appName        = val("CDADS_APP_NAME")
        iabCategory    = val("CDADS_CAT")
        bundleID       = val("CDADS_BUNDLE_ID")
        bundleIDString = val("CDADS_BUNDLE_ID_STRING")
        debugURL       = val("CDADS_DEBUG_URL")
        cmsApiURL      = val("CDADS_CMS_URL")
    }

    func effectiveCmsApiURL() -> String {
        cmsApiURL ?? "https://cms-api.chalkdigital.com"
    }

    // MARK: - Resolution helpers
    // Config value wins when non-empty; plist value is the fallback.

    func effectiveHost(fallback config: String) -> String {
        nonEmpty(config) ?? serverURL ?? ""
    }

    func effectivePartnerKey(fallback config: String) -> String {
        nonEmpty(config) ?? partnerID ?? ""
    }

    func effectiveAppName(fallback config: String) -> String {
        nonEmpty(config) ?? appName ?? ""
    }

    func effectiveIABCategory(fallback config: String) -> String {
        nonEmpty(config) ?? iabCategory ?? ""
    }

    // MARK: - Private

    private func nonEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }
}
