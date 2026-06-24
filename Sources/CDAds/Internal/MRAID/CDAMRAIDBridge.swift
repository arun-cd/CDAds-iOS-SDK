import UIKit
import WebKit

/// Injects the MRAID JS library into a WKWebViewConfiguration and bridges
/// both the new-style (`window.mraid._nativeReady`) and the legacy
/// (`window.mraidbridge.fireReadyEvent`) MRAID bridge formats.
///
/// Server-side MRAID creatives built against the old ObjC SDK expect the legacy
/// `window.mraidbridge` + `mraid://` URL-scheme protocol. This bridge speaks both.
@MainActor
final class CDAMRAIDBridge: NSObject {

    // MARK: - Callbacks (set by the owning view/VC)

    var onExpand:     ((URL?) -> Void)?
    var onClose:      (() -> Void)?
    var onResize:     ((CGSize, CGPoint) -> Void)?
    var onOpen:       ((URL) -> Void)?
    var onPlayVideo:  ((URL) -> Void)?

    // MARK: - Inject

    /// Injects the MRAID user script into `configuration` before the WebView is created.
    func inject(into configuration: WKWebViewConfiguration) {
        guard let js = Self.mraidJS else {
            CDALogger.error("mraid.js not found in bundle")
            return
        }
        let script = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)
        configuration.userContentController.add(LeakAvoider(delegate: self), name: "mraid")
    }

    // MARK: - Native → JS signals

    /// Called after the ad HTML finishes loading.
    /// Fires both the new-style `mraid._nativeReady` and the legacy `mraidbridge.fireReadyEvent`.
    func notifyReady(placementType: String, webView: WKWebView, containerView: UIView) {
        let frame  = containerView.convert(containerView.bounds, to: nil)
        let screen = UIScreen.main.bounds
        let x = frame.minX, y = frame.minY, w = frame.width, h = frame.height
        let sw = screen.width, sh = screen.height

        let js = """
        (function() {
            var pos = { x:\(x), y:\(y), width:\(w), height:\(h),
                        maxWidth:\(sw), maxHeight:\(sh),
                        screenWidth:\(sw), screenHeight:\(sh) };

            // New-style bridge (our injected mraid.js):
            // Pre-set isViewable=true so mraid.isViewable() returns true inside the 'ready' handler.
            if (window.mraid) {
                if (typeof window.mraid._nativeViewableChange === 'function')
                    window.mraid._nativeViewableChange(true);
                if (typeof window.mraid._nativeReady === 'function')
                    window.mraid._nativeReady('\(placementType)', pos);
            }

            // Legacy bridge (old ObjC SDK mraid.js — window.location='mraid://...' style)
            if (window.mraidbridge) {
                if (window.mraidbridge.setIsViewable)      window.mraidbridge.setIsViewable(true);
                if (window.mraidbridge.setPlacementType)   window.mraidbridge.setPlacementType('\(placementType)');
                if (window.mraidbridge.setState)           window.mraidbridge.setState('default');
                if (window.mraidbridge.setMaxSize)         window.mraidbridge.setMaxSize(\(sw), \(sh));
                if (window.mraidbridge.setScreenSize)      window.mraidbridge.setScreenSize(\(sw), \(sh));
                if (window.mraidbridge.setDefaultPosition) window.mraidbridge.setDefaultPosition(\(x),\(y),\(w),\(h));
                if (window.mraidbridge.setCurrentPosition) window.mraidbridge.setCurrentPosition(\(x),\(y),\(w),\(h));
                if (window.mraidbridge.fireReadyEvent)     window.mraidbridge.fireReadyEvent();
            }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    func notifyViewableChange(viewable: Bool, webView: WKWebView) {
        let v = viewable ? "true" : "false"
        webView.evaluateJavaScript("""
        (function() {
            if (window.mraid && typeof window.mraid._nativeViewableChange === 'function')
                window.mraid._nativeViewableChange(\(v));
            if (window.mraidbridge) {
                if (window.mraidbridge.setIsViewable) window.mraidbridge.setIsViewable(\(v));
                if (window.mraidbridge.notifyViewableChangeEvent) window.mraidbridge.notifyViewableChangeEvent();
            }
        })();
        """)
    }

    func notifyStateChange(state: String, webView: WKWebView) {
        webView.evaluateJavaScript("""
        (function() {
            if (window.mraid && typeof window.mraid._nativeStateChange === 'function')
                window.mraid._nativeStateChange('\(state)');
            if (window.mraidbridge) {
                if (window.mraidbridge.setState) window.mraidbridge.setState('\(state)');
                if (window.mraidbridge.notifyStateChangeEvent) window.mraidbridge.notifyStateChangeEvent();
            }
        })();
        """)
    }

    // MARK: - Legacy mraid:// URL scheme

    /// Handles `window.location = 'mraid://command?params'` navigations from legacy MRAID JS.
    /// Call this from `WKNavigationDelegate.decidePolicyFor` when `url.scheme == "mraid"`.
    func handleLegacyURL(_ url: URL) {
        guard let command = url.host?.lowercased() else { return }
        var params: [String: String] = [:]
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.forEach { if let v = $0.value { params[$0.name] = v } }

        CDALogger.debug("MRAID legacy: \(command) \(params)")

        switch command {
        case "expand":
            let expandURL = (params["url"] ?? params["URL"]).flatMap { URL(string: $0) }
            onExpand?(expandURL)
        case "close":
            onClose?()
        case "open":
            if let urlStr = params["url"] ?? params["URL"], let target = URL(string: urlStr) {
                onOpen?(target)
            }
        case "playvideo":
            if let urlStr = params["uri"] ?? params["url"], let videoURL = URL(string: urlStr) {
                onPlayVideo?(videoURL)
            }
        case "resize":
            let w = CGFloat(params["width"].flatMap(Double.init) ?? 0)
            let h = CGFloat(params["height"].flatMap(Double.init) ?? 0)
            let x = CGFloat(params["offsetX"].flatMap(Double.init) ?? 0)
            let y = CGFloat(params["offsetY"].flatMap(Double.init) ?? 0)
            onResize?(CGSize(width: w, height: h), CGPoint(x: x, y: y))
        case "usecustomclose", "setorientationproperties", "createcalendarevent",
             "storepicture", "nativecallcomplete":
            break // no native action needed for these in a banner context
        default:
            CDALogger.debug("MRAID legacy command unhandled: \(command)")
        }
    }

    // MARK: - MRAID JS source

    static let mraidJS: String? = {
        if let url = Bundle.cdads("CDAds_MRAID").url(forResource: "mraid", withExtension: "js"),
           let src = try? String(contentsOf: url) {
            return src
        }
        return nil
    }()
}

// MARK: - WKScriptMessageHandler (new-style webkit.messageHandlers bridge)

extension CDAMRAIDBridge: WKScriptMessageHandler {

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        Task { @MainActor in self.handle(action: action, params: body) }
    }

    @MainActor
    private func handle(action: String, params: [String: Any]) {
        switch action {
        case "expand":
            let url = (params["url"] as? String).flatMap { URL(string: $0) }
            onExpand?(url)
        case "close":
            onClose?()
        case "open":
            if let urlStr = params["url"] as? String, let url = URL(string: urlStr) {
                onOpen?(url)
            }
        case "resize":
            let w = params["width"]   as? CGFloat ?? 0
            let h = params["height"]  as? CGFloat ?? 0
            let x = params["offsetX"] as? CGFloat ?? 0
            let y = params["offsetY"] as? CGFloat ?? 0
            onResize?(CGSize(width: w, height: h), CGPoint(x: x, y: y))
        case "playVideo":
            if let urlStr = params["url"] as? String, let url = URL(string: urlStr) {
                onPlayVideo?(url)
            }
        default:
            CDALogger.debug("MRAID action unhandled: \(action)")
        }
    }
}

// MARK: - Leak avoider (breaks WKUserContentController retain cycle)

private final class LeakAvoider: NSObject, WKScriptMessageHandler {
    weak var delegate: (NSObject & WKScriptMessageHandler)?
    init(delegate: NSObject & WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ ucc: WKUserContentController, didReceive msg: WKScriptMessage) {
        delegate?.userContentController(ucc, didReceive: msg)
    }
}
