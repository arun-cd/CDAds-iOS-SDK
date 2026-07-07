import UIKit
import WebKit

// UIBarButtonItem can size its customView via intrinsicContentSize, systemLayoutSizeFitting,
// or the raw frame depending on the iOS version and Auto Layout state — none of the indirect
// approaches (frame-only, width/height constraints on a plain UIView) are reliable across all
// versions. Overriding intrinsicContentSize in a dedicated subclass is the only approach that
// covers every code path UIBarButtonItem uses internally.
private final class _CircleButtonView: UIView {
    private let side: CGFloat

    init(side: CGFloat, backgroundColor: UIColor, icon: UIImage?, tint: UIColor, target: Any?, action: Selector) {
        self.side = side
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        self.backgroundColor = backgroundColor
        layer.cornerRadius = side / 2
        clipsToBounds = true

        let btn = UIButton(type: .custom)
        btn.frame = bounds
        btn.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        btn.setImage(icon, for: .normal)
        btn.tintColor = tint
        btn.addTarget(target, action: action, for: .touchUpInside)
        addSubview(btn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { CGSize(width: side, height: side) }
}

/// In-app browser presented when `CDABannerView.landingPageBehaviour == .inAppBrowser`.
/// Provides a WKWebView with back/forward/refresh navigation and an "Open in Safari" option.
@MainActor
final class CDABrowserViewController: UIViewController {

    private let initialURL: URL
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObserver: NSKeyValueObservation?

    private lazy var backButton    = UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                                                     style: .plain, target: self,
                                                     action: #selector(goBack))
    private lazy var forwardButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"),
                                                     style: .plain, target: self,
                                                     action: #selector(goForward))
    private lazy var refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                                     action: #selector(refresh))
    private lazy var safariButton  = UIBarButtonItem(image: UIImage(systemName: "safari"),
                                                     style: .plain, target: self,
                                                     action: #selector(openInSafari))

    private lazy var closeBarButton: UIBarButtonItem = {
        let icon = UIImage(systemName: "xmark",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        let view = _CircleButtonView(
            side: 28,
            backgroundColor: .systemFill,   // adaptive: subtle in light, stronger in dark
            icon: icon,
            tint: .secondaryLabel,           // adaptive: dark grey in light, light grey in dark
            target: self,
            action: #selector(dismiss_)
        )
        return UIBarButtonItem(customView: view)
    }()

    init(url: URL) {
        self.initialURL = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = view.tintColor
        progressView.trackTintColor = .clear
        progressView.isHidden = true
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            DispatchQueue.main.async {
                let progress = Float(webView.estimatedProgress)
                self?.progressView.setProgress(progress, animated: true)
                self?.progressView.isHidden = progress >= 1.0
            }
        }

        navigationItem.rightBarButtonItem = closeBarButton

        let flex  = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixed = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixed.width = 16
        toolbarItems = [backButton, fixed, forwardButton, flex, refreshButton, flex, safariButton]
        navigationController?.setToolbarHidden(false, animated: false)

        webView.load(URLRequest(url: initialURL))
        updateNavButtons()
    }

    deinit {
        progressObserver?.invalidate()
    }

    // MARK: - Actions

    @objc private func goBack()    { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func refresh()   { webView.reload() }

    @objc private func openInSafari() {
        guard let url = webView.url ?? Optional(initialURL) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func dismiss_() { dismiss(animated: true) }

    // MARK: - Helpers

    private func updateNavButtons() {
        backButton.isEnabled    = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    private func updateTitle() {
        title = webView.url?.host ?? initialURL.host
    }
}

// MARK: - WKNavigationDelegate

extension CDABrowserViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        progressView.isHidden = false
        progressView.setProgress(0.1, animated: false)
        updateNavButtons()
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        progressView.setProgress(1.0, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.progressView.isHidden = true
            self?.progressView.setProgress(0, animated: false)
        }
        updateNavButtons()
        updateTitle()
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        progressView.isHidden = true
        progressView.setProgress(0, animated: false)
        updateNavButtons()
    }
}

// MARK: - Convenience

extension CDABrowserViewController {
    func wrappedInNavController() -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.setToolbarHidden(false, animated: false)
        return nav
    }
}
