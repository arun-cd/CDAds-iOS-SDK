import Foundation

/// Requests a native ad from the server.
///
/// ```swift
/// let request = CDANativeAdRequest(adUnitId: "YOUR_PLACEMENT_ID")
/// request.delegate = self
/// request.load()
/// ```
@MainActor
public final class CDANativeAdRequest {

    // MARK: - Public

    public let adUnitId: String
    public weak var delegate: CDANativeAdDelegate?

    // MARK: - Init

    public init(adUnitId: String) {
        self.adUnitId = adUnitId
    }

    // MARK: - Public API

    public func load(request: CDAdsAdRequest? = nil) {
        guard CDAds._instance != nil else {
            delegate?.nativeAdDidFailToLoad(self, error: CDAdsError(.sdkNotInitialized, "Call CDAds.initialize(with:) first."))
            return
        }
        let req = request ?? CDAdsAdRequest(adUnitId: adUnitId)
        Task { await fetch(request: req) }
    }

    // MARK: - Private

    private func fetch(request: CDAdsAdRequest) async {
        guard let config = CDAds._instance?.configuration else { return }

        // The ad server won't return a fill without a country — if we're relying on the
        // SDK's automatic location (no manual geoInfo supplied) wait briefly for reverse
        // geocoding / IP fallback to resolve it first rather than wasting the request.
        if request.geoInfo == nil {
            _ = await CDAds.shared.location.waitForGeoReady()
        }

        do {
            let serverRequest = CDAAdServerRequest(config: config, request: request, format: .native)
            let url      = try serverRequest.makeURL()
            let bodyData = try serverRequest.makeBodyData()
            let response = try await CDANetworkSession.shared.post(url, bodyData: bodyData, as: CDABidResponse.self)
            guard let adm = response.firstAdMarkup, !adm.isEmpty,
                  let admData = adm.data(using: .utf8),
                  let nativeResponse = try? JSONDecoder().decode(CDANativeAdResponse.self, from: admData) else {
                throw CDAdsError(.noFill, "No native ad available")
            }
            let data = nativeResponse.toNativeAdData(adUnitId: adUnitId)
            CDALogger.info("Native ad loaded — \(adUnitId)")
            delegate?.nativeAdDidLoad(self, data: data)
        } catch let error as CDAdsError {
            delegate?.nativeAdDidFailToLoad(self, error: error)
        } catch {
            delegate?.nativeAdDidFailToLoad(self, error: CDAdsError(.networkError, error.localizedDescription))
        }
    }
}

// MARK: - Manager (Flutter bridge)

@MainActor
public final class CDANativeAdManager {

    private let config: CDAdsConfiguration
    private var requests: [String: CDANativeAdRequest] = [:]

    // Stores loaded data so impression/click trackers can be fired later.
    private var loadedAds: [String: CDANativeAdData] = [:]

    init(config: CDAdsConfiguration) {
        self.config = config
    }

    public func load(request: CDAdsAdRequest, delegate: CDANativeAdDelegate) {
        let nativeRequest = CDANativeAdRequest(adUnitId: request.adUnitId)
        nativeRequest.delegate = delegate
        requests[request.adUnitId] = nativeRequest
        nativeRequest.load(request: request)
    }

    public func storeLoadedAd(_ data: CDANativeAdData) {
        loadedAds[data.adId] = data
    }

    public func trackImpression(adId: String) {
        guard let ad = loadedAds[adId] else { return }
        let impressions = ad.impressionTrackers; Task { for url in impressions { await CDANetworkSession.shared.beacon(url) } }
        CDALogger.debug("Native ad impression fired — \(adId)")
    }

    public func trackClick(adId: String) {
        guard let ad = loadedAds[adId] else { return }
        let clicks = ad.clickTrackers; Task { for url in clicks { await CDANetworkSession.shared.beacon(url) } }
        CDALogger.debug("Native ad click fired — \(adId)")
    }

    public func destroy(adUnitId: String) {
        requests.removeValue(forKey: adUnitId)
        loadedAds = loadedAds.filter { $0.value.adUnitId != adUnitId }
    }
}

// MARK: - Internal response model

struct CDANativeAdResponse: Decodable {
    let adId: String
    let title: String?
    let body: String?
    let callToAction: String?
    let advertiser: String?
    let sponsoredLabel: String?
    let mainImageUrl: String?
    let iconImageUrl: String?
    let starRating: Double?
    let price: String?
    let clickUrl: String?
    let vastTagUrl: String?
    let impressionTrackers: [String]
    let clickTrackers: [String]
    let extras: [String: String]?

    func toNativeAdData(adUnitId: String) -> CDANativeAdData {
        CDANativeAdData(
            adId:               adId,
            adUnitId:           adUnitId,
            title:              title,
            body:               body,
            callToAction:       callToAction,
            advertiser:         advertiser,
            sponsoredLabel:     sponsoredLabel,
            mainImageURL:       mainImageUrl.flatMap(URL.init),
            iconImageURL:       iconImageUrl.flatMap(URL.init),
            starRating:         starRating,
            price:              price,
            clickURL:           clickUrl.flatMap(URL.init),
            vastTagURL:         vastTagUrl.flatMap(URL.init),
            impressionTrackers: impressionTrackers.compactMap(URL.init),
            clickTrackers:      clickTrackers.compactMap(URL.init),
            extras:             extras ?? [:]
        )
    }
}
