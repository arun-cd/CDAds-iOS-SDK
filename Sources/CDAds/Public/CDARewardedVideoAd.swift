import UIKit

/// Loads and presents a fullscreen rewarded video ad.
///
/// ```swift
/// let ad = CDARewardedVideoAd(adUnitId: "YOUR_PLACEMENT_ID")
/// ad.delegate = self
/// ad.load()
///
/// // Once rewardedVideoDidLoad fires:
/// ad.show(from: self)
/// ```
@MainActor
public final class CDARewardedVideoAd {

    // MARK: - Public

    public let adUnitId: String
    public weak var delegate: CDARewardedVideoDelegate?

    public var isReady: Bool { state == .ready }
    public private(set) var reward: CDAReward?

    // MARK: - Init

    public init(adUnitId: String) {
        self.adUnitId = adUnitId
    }

    // MARK: - Public API

    public func load(request: CDAdsAdRequest? = nil) {
        guard ensureInitialized() else { return }
        guard state == .idle || state == .expired else { return }
        state = .loading
        let req = request ?? CDAdsAdRequest(adUnitId: adUnitId)
        Task { await fetch(request: req) }
    }

    public func show(from viewController: UIViewController) {
        guard state == .ready, let vc = rewardedVC else {
            CDALogger.warn("Rewarded video not ready for \(adUnitId)")
            return
        }
        state = .presenting
        delegate?.rewardedVideoWillAppear(self)
        viewController.present(vc, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.rewardedVideoDidAppear(self)
        }
    }

    // MARK: - Private

    private enum State { case idle, loading, ready, presenting, expired }

    private var state: State = .idle
    private var rewardedVC: CDARewardedVideoViewController?
    private var expiryTask: Task<Void, Never>?

    private func fetch(request: CDAdsAdRequest) async {
        guard let config = CDAds._instance?.configuration else { return }

        // The ad server won't return a fill without a country — if we're relying on the
        // SDK's automatic location (no manual geoInfo supplied) wait briefly for reverse
        // geocoding / IP fallback to resolve it first rather than wasting the request.
        // nil means geo timed out without a countryCode — abort rather than send a bad request.
        if request.geoInfo == nil {
            guard await CDAds.shared.location.waitForGeoReady() != nil else {
                let error = CDAdsError(.invalidRequest, "Country code unavailable — ad request aborted")
                state = .idle
                delegate?.rewardedVideoDidFailToLoad(self, error: error)
                return
            }
        }

        do {
            let serverRequest = CDAAdServerRequest(config: config, request: request, format: .rewarded)
            let url      = try serverRequest.makeURL()
            let bodyData = try serverRequest.makeBodyData()
            let response = try await CDANetworkSession.shared.post(url, bodyData: bodyData, as: CDABidResponse.self)
            guard let adm = response.firstAdMarkup, !adm.isEmpty else {
                throw CDAdsError(.noFill, "No ad available")
            }
            // adm may be VAST XML or a VAST URL
            let vast: CDAVASTAd
            if adm.hasPrefix("http://") || adm.hasPrefix("https://") {
                guard let vastURL = URL(string: adm) else {
                    throw CDAdsError(.invalidRequest, "Invalid VAST URL in bid response")
                }
                vast = try await CDAVASTParser.fetch(vastURL)
            } else {
                vast = try CDAVASTParser.parse(Data(adm.utf8))
            }
            reward = CDAReward(
                currencyType: response.firstBid?.ext?.currencyType ?? "coins",
                amount: response.firstBid?.ext?.currencyAmount ?? 1
            )
            prepareViewController(vast: vast)
            state = .ready
            scheduleExpiry(after: response.firstBid?.ext?.expirySeconds ?? 3600)
            CDALogger.info("Rewarded video loaded — \(adUnitId)")
            delegate?.rewardedVideoDidLoad(self)
        } catch let error as CDAdsError {
            state = .idle
            delegate?.rewardedVideoDidFailToLoad(self, error: error)
        } catch {
            state = .idle
            delegate?.rewardedVideoDidFailToLoad(self, error: CDAdsError(.networkError, error.localizedDescription))
        }
    }

    private func prepareViewController(vast: CDAVASTAd) {
        let vc = CDARewardedVideoViewController(vast: vast)
        vc.onCompleted = { [weak self] in self?.handleCompleted() }
        vc.onDismiss   = { [weak self] in self?.handleDismiss() }
        vc.onTap       = { [weak self] url in self?.handleTap(url: url) }
        vc.onFailed    = { [weak self] error in self?.handleFailed(error: error) }
        vc.modalPresentationStyle = .fullScreen
        rewardedVC = vc
    }

    private func handleCompleted() {
        guard let reward else { return }
        CDALogger.info("Rewarded video completed — rewarding \(reward.amount) \(reward.currencyType)")
        delegate?.rewardedVideoShouldRewardUser(self, reward: reward)
    }

    private func handleDismiss() {
        state = .idle
        rewardedVC = nil
        delegate?.rewardedVideoWillDisappear(self)
        delegate?.rewardedVideoDidDisappear(self)
    }

    private func handleTap(url: URL?) {
        delegate?.rewardedVideoDidReceiveTap(self)
        guard let url else { return }
        delegate?.rewardedVideoWillLeaveApplication(self)
        UIApplication.shared.open(url)
    }

    private func handleFailed(error: CDAdsError) {
        state = .idle
        delegate?.rewardedVideoDidFailToPlay(self, error: error)
    }

    private func scheduleExpiry(after seconds: TimeInterval) {
        expiryTask?.cancel()
        expiryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, state == .ready else { return }
            state = .expired
            rewardedVC = nil
            delegate?.rewardedVideoDidExpire(self)
        }
    }

    @discardableResult
    private func ensureInitialized() -> Bool {
        guard CDAds._instance != nil else {
            delegate?.rewardedVideoDidFailToLoad(self, error: CDAdsError(.sdkNotInitialized, "Call CDAds.initialize(with:) first."))
            return false
        }
        return true
    }
}

// MARK: - Manager

@MainActor
public final class CDARewardedVideoManager {

    private let config: CDAdsConfiguration
    private var ads: [String: CDARewardedVideoAd] = [:]

    init(config: CDAdsConfiguration) {
        self.config = config
    }

    public func load(request: CDAdsAdRequest, delegate: CDARewardedVideoDelegate) {
        let ad = ads[request.adUnitId] ?? CDARewardedVideoAd(adUnitId: request.adUnitId)
        ad.delegate = delegate
        ads[request.adUnitId] = ad
        ad.load(request: request)
    }

    public func isReady(adUnitId: String) -> Bool { ads[adUnitId]?.isReady ?? false }

    public func show(adUnitId: String, from viewController: UIViewController) {
        ads[adUnitId]?.show(from: viewController)
    }
}

