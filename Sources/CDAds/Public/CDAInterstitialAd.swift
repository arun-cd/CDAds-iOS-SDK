import UIKit

/// Loads and presents a fullscreen interstitial ad.
///
/// ```swift
/// let ad = CDAInterstitialAd(adUnitId: "YOUR_PLACEMENT_ID")
/// ad.delegate = self
/// ad.load()
///
/// // Later, once interstitialDidLoad fires:
/// ad.show(from: self)
/// ```
@MainActor
public final class CDAInterstitialAd {

    // MARK: - Public

    public let adUnitId: String
    public weak var delegate: CDAInterstitialDelegate?

    public var isReady: Bool { state == .ready }

    // MARK: - Init

    public init(adUnitId: String) {
        self.adUnitId = adUnitId
    }

    // MARK: - Public API

    public func load(request: CDAdsAdRequest? = nil) {
        guard ensureInitialized() else { return }
        guard state == .idle || state == .expired else {
            CDALogger.warn("Interstitial already loading or loaded for \(adUnitId)")
            return
        }
        state = .loading
        let req = request ?? CDAdsAdRequest(adUnitId: adUnitId)
        Task { await fetch(request: req) }
    }

    public func show(from viewController: UIViewController) {
        guard state == .ready else {
            CDALogger.warn("Interstitial not ready for \(adUnitId)")
            return
        }
        guard let vc = interstitialVC else { return }
        state = .presenting
        delegate?.interstitialWillAppear(self)
        viewController.present(vc, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.interstitialDidAppear(self)
        }
    }

    public func destroy() {
        state = .idle
        interstitialVC = nil
        expiryTask?.cancel()
        expiryTask = nil
        CDALogger.debug("Interstitial destroyed — \(adUnitId)")
    }

    // MARK: - Private

    private enum State { case idle, loading, ready, presenting, expired }

    private var state: State = .idle
    private var interstitialVC: CDAInterstitialViewController?
    private var expiryTask: Task<Void, Never>?

    private func fetch(request: CDAdsAdRequest) async {
        guard let config = CDAds._instance?.configuration else { return }

        // The ad server won't return a fill without a country — if we're relying on the
        // SDK's automatic location (no manual geoInfo supplied) wait briefly for reverse
        // geocoding / IP fallback to resolve it first rather than wasting the request.
        if request.geoInfo == nil {
            _ = await CDAds.shared.location.waitForGeoReady()
        }

        do {
            let serverRequest = CDAAdServerRequest(config: config, request: request, format: .interstitial)
            let url      = try serverRequest.makeURL()
            let bodyData = try serverRequest.makeBodyData()
            let response = try await CDANetworkSession.shared.post(url, bodyData: bodyData, as: CDABidResponse.self)
            guard let html = response.firstAdMarkup, !html.isEmpty else {
                throw CDAdsError(.noFill, "No ad available")
            }
            prepareViewController(html: html, config: config)
            state = .ready
            scheduleExpiry(after: response.firstBid?.ext?.expirySeconds ?? 3600)
            CDALogger.info("Interstitial loaded — \(adUnitId)")
            delegate?.interstitialDidLoad(self)
        } catch let error as CDAdsError {
            state = .idle
            CDALogger.error("Interstitial load failed: \(error.message)")
            delegate?.interstitialDidFailToLoad(self, error: error)
        } catch {
            state = .idle
            delegate?.interstitialDidFailToLoad(self, error: CDAdsError(.networkError, error.localizedDescription))
        }
    }

    private func prepareViewController(html: String, config: CDAdsConfiguration) {
        let vc = CDAInterstitialViewController(html: html, baseURL: URL(string: config.effectiveHost))
        vc.onDismiss = { [weak self] in self?.handleDismiss() }
        vc.onTap     = { [weak self] url in self?.handleTap(url: url) }
        vc.modalPresentationStyle = .fullScreen
        interstitialVC = vc
    }

    private func handleDismiss() {
        state = .idle
        interstitialVC = nil
        delegate?.interstitialWillDisappear(self)
        delegate?.interstitialDidDisappear(self)
    }

    private func handleTap(url: URL?) {
        delegate?.interstitialDidReceiveTap(self)
        guard let url else { return }
        delegate?.interstitialWillLeaveApplication(self)
        UIApplication.shared.open(url)
    }

    private func scheduleExpiry(after seconds: TimeInterval) {
        expiryTask?.cancel()
        expiryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, state == .ready else { return }
            state = .expired
            interstitialVC = nil
            CDALogger.info("Interstitial expired — \(adUnitId)")
            delegate?.interstitialDidExpire(self)
        }
    }

    @discardableResult
    private func ensureInitialized() -> Bool {
        guard CDAds._instance != nil else {
            let error = CDAdsError(.sdkNotInitialized, "Call CDAds.initialize(with:) first.")
            delegate?.interstitialDidFailToLoad(self, error: error)
            return false
        }
        return true
    }
}

// MARK: - Manager (used by Flutter bridge)

/// Keyed store of interstitial ads — the Flutter bridge works with ad unit IDs,
/// not direct object references, so we need a registry.
@MainActor
public final class CDAInterstitialAdManager {

    private let config: CDAdsConfiguration
    private var ads: [String: CDAInterstitialAd] = [:]

    init(config: CDAdsConfiguration) {
        self.config = config
    }

    public func load(request: CDAdsAdRequest, delegate: CDAInterstitialDelegate) {
        let ad = ads[request.adUnitId] ?? CDAInterstitialAd(adUnitId: request.adUnitId)
        ad.delegate = delegate
        ads[request.adUnitId] = ad
        ad.load(request: request)
    }

    public func isReady(adUnitId: String) -> Bool {
        ads[adUnitId]?.isReady ?? false
    }

    public func show(adUnitId: String, from viewController: UIViewController) {
        ads[adUnitId]?.show(from: viewController)
    }

    public func destroy(adUnitId: String) {
        ads[adUnitId]?.destroy()
        ads.removeValue(forKey: adUnitId)
    }
}

