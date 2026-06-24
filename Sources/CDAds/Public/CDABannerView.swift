import UIKit
import WebKit

/// A `UIView` subclass that loads and displays a banner or MREC ad.
///
/// Add this view to your layout, set the `delegate`, then call `load(request:)`.
///
/// ```swift
/// let banner = CDABannerView(size: .banner320x50)
/// banner.delegate = self
/// view.addSubview(banner)
/// banner.load(request: CDAdsAdRequest(adUnitId: "YOUR_PLACEMENT_ID"))
/// ```
@MainActor
public final class CDABannerView: UIView {

    // MARK: - Public

    public weak var delegate: CDABannerDelegate?

    public let adSize: CDABannerSize

    /// Returns `true` once an ad has loaded successfully.
    public private(set) var isAdLoaded = false {
        didSet { updateCloseButtonVisibility() }
    }

    /// Interval (seconds) between automatic ad refreshes. Default 30 s (matches old SDK CDADfetchInterval).
    public var refreshInterval: TimeInterval = 30

    /// When `true` the banner automatically refreshes on `refreshInterval`. Default `true`.
    public var isAutoRefreshEnabled: Bool = true

    /// When `true` a close (×) button is displayed in the top-right corner of the banner,
    /// once an ad has actually loaded — never shown over an empty/no-fill banner.
    public var showCloseButton: Bool = false {
        didSet { updateCloseButtonVisibility() }
    }

    // MARK: - Init

    public init(size: CDABannerSize) {
        self.adSize = size
        super.init(frame: CGRect(origin: .zero, size: size.cgSize))
        backgroundColor = .clear
        setupWebView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(size:)") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Matches the production Obj-C SDK's CDADBannerView close button placement:
        // a 50x50 hit region centered exactly on the top-left corner point, i.e.
        // straddling the banner's top and left edges rather than inset from them.
        let btnSize: CGFloat = 50
        closeButton.frame = CGRect(x: -btnSize / 2, y: -btnSize / 2, width: btnSize, height: btnSize)
    }

    // UIView's default hitTest only forwards touches to subviews whose point lies within
    // `self.bounds` — so the half of the close button that overhangs outside our own frame
    // (by design, to straddle the corner) would never receive touches at all, even though
    // it's visible there. Matches CDADBannerView.m's hitTest override exactly: bypass the
    // bounds check and forward to every subview directly.
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !clipsToBounds, !isHidden, alpha > 0 else { return nil }
        for subview in subviews.reversed() {
            let subPoint = subview.convert(point, from: self)
            if let result = subview.hitTest(subPoint, with: event) {
                return result
            }
        }
        return nil
    }

    // MARK: - Public API

    public func load(request: CDAdsAdRequest) {
        guard CDAds._instance != nil else {
            let error = CDAdsError(.sdkNotInitialized, "Call CDAds.initialize(with:) first.")
            delegate?.bannerDidFailToLoad(self, error: error)
            return
        }
        self.currentRequest = request
        Task { await fetchAndRender(request: request) }
    }

    public func destroy() {
        stopAutomaticallyRefreshingContents()
        viewabilityTracker?.stop()
        viewabilityTracker = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        isAdLoaded = false
        currentRequest = nil
        CDALogger.debug("Banner destroyed — \(adSize.identifier)")
    }

    /// Starts automatic ad refresh on `refreshInterval`. Called automatically after the first load.
    public func startAutomaticallyRefreshingContents() {
        stopAutomaticallyRefreshingContents()
        guard isAutoRefreshEnabled, let req = currentRequest else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self, let req = self.currentRequest else { return }
            Task { @MainActor [weak self] in
                await self?.fetchAndRender(request: req)
            }
        }
        CDALogger.debug("Banner auto-refresh started — interval:\(refreshInterval)s")
    }

    /// Stops automatic ad refresh (e.g. when the banner scrolls off-screen).
    public func stopAutomaticallyRefreshingContents() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func closeButtonTapped() {
        // Matches CDADBannerView.m's closeButtonClicked exactly: the tap itself removes
        // the ad content and hides the button — this isn't left for the host app to do
        // via the delegate, which previously meant tapping had no visible effect at all.
        stopAutomaticallyRefreshingContents()
        webView.removeFromSuperview()
        closeButton.isHidden = true
        delegate?.bannerDidClose(self)
    }

    private func updateCloseButtonVisibility() {
        closeButton.isHidden = !(showCloseButton && isAdLoaded)
    }

    // MARK: - Private

    private var webView: WKWebView!
    private var currentRequest: CDAdsAdRequest?
    private let mraidBridge = CDAMRAIDBridge()
    private var refreshTimer: Timer?
    private var viewabilityTracker: CDAViewabilityTracker?

    private lazy var closeButton: UIButton = {
        let btn = UIButton(type: .custom)
        // The production SDK's CDCloseButtonX asset (dark circle + X, rendered as-is —
        // no tint) bundled verbatim. An SF Symbol tinted white was the previous attempt
        // here, but white-on-white/light creatives made it disappear; this asset is
        // designed to stay visible against arbitrary ad backgrounds without any tinting.
        // .module only exists under SPM — Bundle.cdads(_:) resolves the same resource
        // under CocoaPods source builds and XCFramework binaries too (see CDABundle.swift).
        btn.setImage(UIImage(named: "CDCloseButtonX", in: .cdads("CDAds_Resources"), compatibleWith: nil), for: .normal)
        btn.imageView?.contentMode = .scaleAspectFit
        // 50x50 hit region, glyph inset 10pt each side (matches CDADBannerView's
        // imageEdgeInsets) so the visible × stays a sensible size within the larger
        // hit region needed to straddle the corner.
        btn.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btn.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        btn.isHidden = true
        btn.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return btn
    }()

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        mraidBridge.inject(into: config)

        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask  = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque          = false
        webView.backgroundColor   = .clear
        webView.navigationDelegate = self
        addSubview(webView)
        addSubview(closeButton)

        mraidBridge.onExpand = { [weak self] _ in
            guard let self else { return }
            self.delegate?.bannerDidExpand(self)
        }
        mraidBridge.onClose = { [weak self] in
            guard let self else { return }
            self.delegate?.bannerDidCollapse(self)
        }
        mraidBridge.onOpen = { url in
            UIApplication.shared.open(url)
        }
    }

    private func fetchAndRender(request: CDAdsAdRequest) async {
        guard let config = CDAds._instance?.configuration else { return }

        // The ad server won't return a fill without a country — if we're relying on the
        // SDK's automatic location (no manual geoInfo supplied) wait briefly for reverse
        // geocoding / IP fallback to resolve it first rather than wasting the request.
        if request.geoInfo == nil {
            _ = await CDAds.shared.location.waitForGeoReady()
        }

        do {
            let serverRequest = CDAAdServerRequest(config: config, request: request, format: .banner)
            let url      = try serverRequest.makeURL()
            let bodyData = try serverRequest.makeBodyData(adSize: adSize.cgSize)
            let response = try await CDANetworkSession.shared.post(url, bodyData: bodyData, as: CDABidResponse.self)
            guard let html = response.firstAdMarkup, !html.isEmpty else {
                throw CDAdsError(.noFill, "No ad available")
            }
            render(html: html)
        } catch let error as CDAdsError {
            CDALogger.error("Banner load failed: \(error.message)")
            delegate?.bannerDidFailToLoad(self, error: error)
        } catch {
            let wrapped = CDAdsError(.networkError, error.localizedDescription)
            delegate?.bannerDidFailToLoad(self, error: wrapped)
        }
    }

    private func render(html: String) {
        let baseURL = URL(string: CDAds.shared.configuration.effectiveHost)
        webView.loadHTMLString(wrapped(adMarkup: html), baseURL: baseURL)
    }

    /// `adm` from the ad server is a bare markup snippet, not a full document. Without
    /// a viewport meta tag, WKWebView falls back to its desktop-style ~980pt default
    /// viewport and scales the whole page down to fit our (much narrower) frame — a
    /// 320pt-wide banner renders at roughly 320/980 ≈ 1/3 of its intended size. This
    /// is the exact prefix/suffix the production Objective-C SDK wraps banner `adm`
    /// in (CDConstants.h: CDResponseBodyPrefix / CDResponseBodySuffix), kept verbatim
    /// — including the non-standard body-inside-head nesting — for parity with known
    /// working behavior in the field (e.g. the Tempo app).
    private static let adMarkupPrefix = "<html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=0,viewport-fit=contain\"><body style=\"margin:0;padding:0;\">"
    private static let adMarkupSuffix = "</body>\n</head></html>"

    private func wrapped(adMarkup: String) -> String {
        Self.adMarkupPrefix + adMarkup + Self.adMarkupSuffix
    }
}

// MARK: - WKNavigationDelegate

extension CDABannerView: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isAdLoaded = true
        CDALogger.debug("Banner loaded — \(adSize.identifier)")
        mraidBridge.notifyReady(placementType: "inline", webView: webView, containerView: self)
        // Signal viewable=true immediately after ready so MRAID creatives that gate
        // on isViewable() render without waiting. The tracker corrects this if the
        // banner is actually off-screen when the ad loads.
        mraidBridge.notifyViewableChange(viewable: true, webView: webView)
        delegate?.bannerDidLoad(self)
        startAutomaticallyRefreshingContents()
        // Wire viewability tracker on first load
        if viewabilityTracker == nil {
            let tracker = CDAViewabilityTracker(view: self)
            tracker.onBecameViewable = {
                CDALogger.debug("Banner became viewable — MRC impression threshold met")
            }
            // Keep MRAID isViewable() in sync as the banner scrolls in/out of view
            tracker.onViewableChanged = { [weak self] isViewable in
                guard let self else { return }
                self.mraidBridge.notifyViewableChange(viewable: isViewable, webView: self.webView)
            }
            viewabilityTracker = tracker
        }
        viewabilityTracker?.start()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let wrapped = CDAdsError(.networkError, error.localizedDescription)
        delegate?.bannerDidFailToLoad(self, error: wrapped)
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = action.request.url else {
            decisionHandler(.allow)
            return
        }
        // Legacy MRAID: window.location = 'mraid://command?params'
        if url.scheme?.lowercased() == "mraid" {
            decisionHandler(.cancel)
            mraidBridge.handleLegacyURL(url)
            return
        }
        // Prevent server mraid.js from overwriting our injected WKUserScript version
        if url.lastPathComponent.lowercased() == "mraid.js" {
            decisionHandler(.cancel)
            return
        }
        guard action.navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }
        // External navigation = user tapped the ad
        decisionHandler(.cancel)
        delegate?.bannerDidReceiveTap(self)
        if UIApplication.shared.canOpenURL(url) {
            delegate?.bannerWillLeaveApplication(self)
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Banner size

public extension CDABannerView {

    enum CDABannerSize {
        case banner320x50
        case banner300x50
        case banner300x250
        case banner320x100
        case banner728x90
        case banner728x250
        case banner300x600
        case banner970x250
        case banner480x320
        case banner320x480
        case banner768x1024
        case banner1086x1086
        case custom(width: CGFloat, height: CGFloat)

        var cgSize: CGSize {
            switch self {
            case .banner320x50:    return CGSize(width: 320, height: 50)
            case .banner300x50:    return CGSize(width: 300, height: 50)
            case .banner300x250:   return CGSize(width: 300, height: 250)
            case .banner320x100:   return CGSize(width: 320, height: 100)
            case .banner728x90:    return CGSize(width: 728, height: 90)
            case .banner728x250:   return CGSize(width: 728, height: 250)
            case .banner300x600:   return CGSize(width: 300, height: 600)
            case .banner970x250:   return CGSize(width: 970, height: 250)
            case .banner480x320:   return CGSize(width: 480, height: 320)
            case .banner320x480:   return CGSize(width: 320, height: 480)
            case .banner768x1024:  return CGSize(width: 768, height: 1024)
            case .banner1086x1086: return CGSize(width: 1086, height: 1086)
            case .custom(let w, let h): return CGSize(width: w, height: h)
            }
        }

        var identifier: String {
            switch self {
            case .banner320x50:    return "320x50"
            case .banner300x50:    return "300x50"
            case .banner300x250:   return "300x250"
            case .banner320x100:   return "320x100"
            case .banner728x90:    return "728x90"
            case .banner728x250:   return "728x250"
            case .banner300x600:   return "300x600"
            case .banner970x250:   return "970x250"
            case .banner480x320:   return "480x320"
            case .banner320x480:   return "320x480"
            case .banner768x1024:  return "768x1024"
            case .banner1086x1086: return "1086x1086"
            case .custom(let w, let h): return "\(Int(w))x\(Int(h))"
            }
        }
    }
}

