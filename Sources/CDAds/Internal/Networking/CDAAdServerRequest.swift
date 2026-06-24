import Foundation
import UIKit
import Network
import CoreTelephony
import AppTrackingTransparency
import AdSupport

/// Builds the OpenRTB POST request URL and body for ad server requests.
///
/// URL: SERVER_URL + SERVER_PATH + ?sspid=<partnerKey>
/// e.g. https://e-app.cmcd1.com/cmsdk?sspid=chalkboard
@MainActor
struct CDAAdServerRequest {

    private let config: CDAdsConfiguration
    private let request: CDAdsAdRequest
    private let adFormat: AdFormat

    enum AdFormat: String {
        case banner       = "banner"
        case interstitial = "interstitial"
        case rewarded     = "rewarded"
        case native       = "native"
    }

    init(config: CDAdsConfiguration, request: CDAdsAdRequest, format: AdFormat) {
        self.config   = config
        self.request  = request
        self.adFormat = format
    }

    // MARK: - URL

    func makeURL() throws -> URL {
        let plist = CDAPlistParams.shared
        let partnerKey = config.effectivePartnerKey

        let baseURLString: String
        if let serverURL = plist.serverURL {
            baseURLString = Self.applyingJPRegionSubdomain(to: serverURL, country: resolvedGeo()?.countryCode)
                + (plist.serverPath ?? "")
        } else {
            let host = config.effectiveHost
            guard !host.isEmpty else {
                throw CDAdsError(.invalidRequest, "No host configured. Set SERVER_URL in CDAdsParams (Info.plist) or CDAdsConfiguration.host.")
            }
            baseURLString = host + "/cmsdk"
        }

        guard var components = URLComponents(string: baseURLString) else {
            throw CDAdsError(.invalidRequest, "Invalid ad server URL: \(baseURLString)")
        }
        components.queryItems = [URLQueryItem(name: "sspid", value: partnerKey)]
        guard let url = components.url else {
            throw CDAdsError(.invalidRequest, "Could not build request URL")
        }
        return url
    }

    /// Mirrors `CDAdServerURLBuilder.m`'s `URLWithParams:testing:` exactly: routes
    /// requests to a Japan-specific ad-server subdomain (e.g. `e-app.cmcd1.com` →
    /// `e-app-jp.cmcd1.com`) either via an explicit `chalk_sdk_region` UserDefaults
    /// override, or — when that's unset/"AUTO" — by auto-detecting the resolved geo's
    /// alpha-3 country code being "JPN". Old SDK never actually writes the override key
    /// anywhere in its own code (it's presumably set by some external tool/config), so in
    /// practice this auto-detection branch is the one that fires; the override is kept
    /// for byte-for-byte parity in case something else relies on it.
    private static func applyingJPRegionSubdomain(to serverURLString: String, country: String?) -> String {
        guard let serverURL = URL(string: serverURLString), let host = serverURL.host,
              let scheme = serverURL.scheme,
              let subDomain = host.components(separatedBy: ".").first
        else { return serverURLString }

        let region = UserDefaults.standard.string(forKey: "chalk_sdk_region")
        let forceJP = region == "JPN"
        let autoJP  = (region == nil || region == "AUTO") && country == "JPN"
        guard forceJP || autoJP else { return serverURLString }

        let domain = host.replacingOccurrences(of: subDomain, with: "")
        return "\(scheme)://\(subDomain)-jp\(domain)"
    }

    private func resolvedGeo() -> CDAdsGeoInfo? {
        if let manual = request.geoInfo {
            return manual
        } else if request.locationAutoUpdateEnabled {
            return CDAds._instance?.location.lastKnownLocation
        }
        return nil
    }

    // MARK: - OpenRTB Body

    /// Builds the OpenRTB JSON POST body.
    /// - Parameter adSize: Banner dimensions; nil uses full screen bounds (for interstitial/rewarded).
    func makeBodyData(adSize: CGSize? = nil) throws -> Data {
        let plist = CDAPlistParams.shared
        let partnerKey  = config.effectivePartnerKey
        let sdkKey      = plist.partnerKey ?? ""
        let iabCategory = config.effectiveIABCategory
        let appName     = config.effectiveAppName
        let bundleID    = Bundle.main.bundleIdentifier ?? ""
        let isTest      = config.environment == .test

        let impSize = adSize ?? UIScreen.main.bounds.size
        var imp: [String: Any] = [
            "id":                 "1",
            "tagid":              request.adUnitId,
            "displaymanagerver":  CDAds.sdkVersion,
            "displaymanager":     "Chalk Digital",
            "instl":              (adFormat == .interstitial || adFormat == .rewarded) ? 1 : 0,
            "secure":             1,
        ]
        let formatDict: [String: Any] = ["h": Int(impSize.height), "w": Int(impSize.width)]
        switch adFormat {
        case .banner, .interstitial:
            imp["banner"] = ["format": [formatDict], "api": [3, 5]]
        case .rewarded:
            imp["video"] = [
                "mimes":       ["video/mp4", "video/3gpp"],
                "protocols":   [1, 2],
                "minduration": 5,
                "maxduration": 300,
                "h":           Int(impSize.height),
                "w":           Int(impSize.width),
                "api":         [1, 2],
            ]
        case .native:
            imp["native"] = ["ver": "1.2", "context": 1, "plcmttype": 1, "privacy": 0]
        }

        var geoDict: [String: Any] = [:]
        if let g = resolvedGeo() {
            geoDict["lat"]  = g.latitude
            geoDict["lon"]  = g.longitude
            geoDict["type"] = g.sourceType.rawValue
            if let city    = g.city        { geoDict["city"]    = city }
            if let region  = g.region      { geoDict["region"]  = region }
            if let zip     = g.zip         { geoDict["zip"]     = zip }
            if let country = g.countryCode { geoDict["country"] = country }
            if let acc = g.horizontalAccuracy { geoDict["accuracy"] = Int(acc) }
        }

        let screenBounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let ip  = request.ipAddress ?? UserDefaults.standard.string(forKey: "CDPublicIPKey") ?? ""
        let uid = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        var deviceDict: [String: Any] = [
            "ua":             buildUserAgent(),
            "dnt":            Int(limitedAdTracking()) ?? 0,
            "ip":             ip,
            "devicetype":     deviceType(),
            "make":           "apple",
            "model":          UIDevice.current.model,
            "os":             "iOS",
            "osv":            UIDevice.current.systemVersion,
            "hwv":            hardwareVersion(),
            "language":       Bundle.main.preferredLocalizations.first ?? Locale.current.identifier,
            "h":              Int(screenBounds.height),
            "w":              Int(screenBounds.width),
            "carrier":        resolveCarrier() ?? "",
            "connectiontype": currentConnectionType(),
            "ifa":            uid,
            "js":             "1",
            "pxratio":        String(format: "%.1f", scale),
        ]
        if !geoDict.isEmpty { deviceDict["geo"] = geoDict }

        var appDict: [String: Any] = [
            "name":     appName,
            "bundle":   plist.bundleID ?? bundleID,
            "domain":   "",
            "storeurl": "",
            "cat":      iabCategory.isEmpty ? [] : [iabCategory],
        ]
        if let bundleStr = plist.bundleIDString, !bundleStr.isEmpty {
            appDict["bundle"] = bundleStr
        }

        var userDict: [String: Any] = [
            "id":  "",
            "ext": ["consent": config.hasConsent ? 1 : 0],
        ]
        if let kw  = request.keywords           { userDict["keyword"]   = kw }
        if let age = request.targetingYearOfBirth       { userDict["yob"]       = age }
        if let gen = request.targetingGender    { userDict["gender"]    = gen }
        if let edu = request.targetingEducation { userDict["education"] = edu }
        if let inc = request.targetingIncome    { userDict["income"]    = Int(inc) ?? 0 }

        var body: [String: Any] = [
            "id":        UUID().uuidString,
            "publisher": partnerKey,
            "key":       sdkKey,
            "ver":       "1.0.0",
            "test":      isTest ? 1 : 0,
            "regs":      ["ext": ["gdpr": config.gdprApplies ? 1 : 0]],
            "imp":       [imp],
            "app":       appDict,
            "device":    deviceDict,
            "user":      userDict,
        ]
        if let lang = request.targetingLanguage { body["wlang"] = [lang] }

        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - Helpers

    private func limitedAdTracking() -> String {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized ? "0" : "1"
        } else {
            return ASIdentifierManager.shared().isAdvertisingTrackingEnabled ? "0" : "1"
        }
    }

    private func currentConnectionType() -> Int {
        guard let path = CDAds._instance?.location.networkMonitorPath,
              path.status == .satisfied else { return 0 }
        if path.usesInterfaceType(.wifi) { return 2 }
        if path.usesInterfaceType(.cellular) {
            if #available(iOS 12, *) {
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
            return 3
        }
        return 0
    }

    private func buildUserAgent() -> String {
        let name    = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                   ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                   ?? "App"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let osVer   = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "\(name)/\(version) (iPhone; CPU iPhone OS \(osVer) like Mac OS X)"
    }

    private func resolveCarrier() -> String? {
        let info = CTTelephonyNetworkInfo()
        return info.serviceSubscriberCellularProviders?.values
            .first(where: { $0.carrierName != nil })?.carrierName
    }

    private func deviceType() -> Int {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:   return 4
        case .pad:     return 5
        case .tv:      return 3
        case .carPlay: return 6
        default:       return 4
        }
    }

    private func hardwareVersion() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { ptr in
            String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
        }
    }
}

// MARK: - OpenRTB bid response

struct CDABidResponse: Decodable {
    struct SeatBid: Decodable {
        struct Bid: Decodable {
            let adm: String?
            let nurl: String?
            let w: Int?
            let h: Int?
            let ext: BidExt?

            struct BidExt: Decodable {
                let currencyType: String?
                let currencyAmount: Int?
                let expirySeconds: TimeInterval?
            }
        }
        let bid: [Bid]
    }
    let seatbid: [SeatBid]?

    var firstBid: SeatBid.Bid? { seatbid?.first?.bid.first }
    var firstAdMarkup: String? { firstBid?.adm }
}
