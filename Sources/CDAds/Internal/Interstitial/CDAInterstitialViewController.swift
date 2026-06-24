import UIKit
import WebKit

/// Fullscreen view controller that renders an interstitial HTML creative.
/// Internal — not exposed to the host app directly.
final class CDAInterstitialViewController: UIViewController {

    var onDismiss: (() -> Void)?
    var onTap: ((URL?) -> Void)?

    private let html: String
    private let baseURL: URL?
    private var webView: WKWebView!
    private var closeButton: UIButton!
    private let mraidBridge = CDAMRAIDBridge()

    init(html: String, baseURL: URL?) {
        self.html    = html
        self.baseURL = baseURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupCloseButton()
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Private

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        mraidBridge.inject(into: config)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask  = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque          = true
        webView.backgroundColor   = .black
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        view.addSubview(webView)

        mraidBridge.onClose = { [weak self] in self?.closeTapped() }
        mraidBridge.onOpen  = { url in UIApplication.shared.open(url) }
    }

    private func setupCloseButton() {
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        view.bringSubviewToFront(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - WKNavigationDelegate

extension CDAInterstitialViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        mraidBridge.notifyReady(placementType: "interstitial", webView: webView, containerView: view)
        mraidBridge.notifyViewableChange(viewable: true, webView: webView)
    }

    func webView(
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
        decisionHandler(.cancel)
        onTap?(url)
    }
}
