import UIKit

/// Monitors a `UIView` for MRC-compliant viewability:
/// the view must have ≥ 50% of its area visible for ≥ 1 continuous second.
///
/// Usage:
/// ```swift
/// let tracker = CDAViewabilityTracker(view: bannerView)
/// tracker.onBecameViewable = { [weak self] in self?.fireImpression() }
/// tracker.start()
/// ```
@MainActor
public final class CDAViewabilityTracker {

    // MARK: - Configuration

    /// Fraction of the ad view that must be visible (default 0.5 — MRC standard).
    public var visibleFraction: CGFloat = 0.5

    /// How long (seconds) the view must remain above `visibleFraction` (default 1 s — MRC standard).
    public var durationThreshold: TimeInterval = 1.0

    // MARK: - Callbacks

    /// Fired once when the viewability threshold is first met. Not re-fired.
    public var onBecameViewable: (() -> Void)?

    /// Fired every time the viewable state changes.
    public var onViewableChanged: ((Bool) -> Void)?

    // MARK: - Init

    public init(view: UIView) {
        self.trackedView = view
    }

    // MARK: - Public

    public private(set) var isViewable = false

    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 2   // check twice per second (saves battery)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        visibleSince = nil
    }

    // MARK: - Private

    private weak var trackedView: UIView?
    private var displayLink: CADisplayLink?
    private var visibleSince: Date?
    private var hasFiredOnce = false

    @objc private func tick() {
        guard let view = trackedView else { stop(); return }
        let currentlyVisible = checkVisibility(of: view)

        if currentlyVisible != isViewable {
            isViewable = currentlyVisible
            onViewableChanged?(isViewable)
        }

        if currentlyVisible {
            if visibleSince == nil { visibleSince = Date() }
            let elapsed = Date().timeIntervalSince(visibleSince!)
            if !hasFiredOnce && elapsed >= durationThreshold {
                hasFiredOnce = true
                onBecameViewable?()
            }
        } else {
            visibleSince = nil
        }
    }

    private func checkVisibility(of view: UIView) -> Bool {
        guard !view.isHidden,
              view.alpha > 0.01,
              view.window != nil else { return false }

        // Convert the view's bounds into the window coordinate space
        guard let window = view.window else { return false }
        let viewFrame = view.convert(view.bounds, to: window)
        let intersection = viewFrame.intersection(window.bounds)

        guard !intersection.isNull, !intersection.isEmpty else { return false }

        let viewArea        = viewFrame.width * viewFrame.height
        let visibleArea     = intersection.width * intersection.height
        guard viewArea > 0 else { return false }

        return (visibleArea / viewArea) >= visibleFraction
    }
}
