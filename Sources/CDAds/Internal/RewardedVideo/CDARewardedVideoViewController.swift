import UIKit
import AVFoundation
import AVKit

/// Fullscreen view controller for rewarded video ads.
/// Accepts a pre-parsed `CDAVASTAd`; plays via AVPlayer.
/// Reward is only granted on full playback completion.
final class CDARewardedVideoViewController: UIViewController {

    var onCompleted: (() -> Void)?
    var onDismiss:   (() -> Void)?
    var onTap:       ((URL?) -> Void)?
    var onFailed:    ((CDAdsError) -> Void)?

    private let vast: CDAVASTAd
    private var playerVC: AVPlayerViewController?
    private var playerObserver: Any?
    private var timeObserver: Any?
    private var didComplete = false
    private var player: AVPlayer?

    // Quartile tracking (fire each at 25 / 50 / 75 / 100 %)
    private var trackedQuartiles: Set<String> = []

    init(vast: CDAVASTAd) {
        self.vast = vast
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        fireTrackers(event: "start")
        setupPlayer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanup()
        onDismiss?()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Private

    private func setupPlayer() {
        let player = AVPlayer(url: vast.mediaFileURL)
        self.player = player
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false

        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
        playerVC = vc

        // Impression trackers
        vast.impressionURLs.forEach { beacon($0) }

        // End-of-playback notification
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackComplete()
        }

        // Quartile time observer
        if vast.duration > 0 {
            let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval, queue: .main
            ) { [weak self] time in
                self?.checkQuartile(currentTime: time.seconds)
            }
        }

        player.play()
    }

    private func checkQuartile(currentTime: TimeInterval) {
        guard vast.duration > 0 else { return }
        let pct = currentTime / vast.duration
        let milestones: [(Double, String)] = [
            (0.01, "start"),
            (0.25, "firstQuartile"),
            (0.50, "midpoint"),
            (0.75, "thirdQuartile"),
        ]
        for (threshold, event) in milestones where pct >= threshold && !trackedQuartiles.contains(event) {
            trackedQuartiles.insert(event)
            fireTrackers(event: event)
        }
    }

    private func handlePlaybackComplete() {
        guard !didComplete else { return }
        didComplete = true
        fireTrackers(event: "complete")
        onCompleted?()
        dismiss(animated: true)
    }

    private func fireTrackers(event: String) {
        vast.trackingEvents[event]?.forEach { beacon($0) }
    }

    private func beacon(_ url: URL) {
        URLSession.shared.dataTask(with: url).resume()
    }

    private func cleanup() {
        if let obs = playerObserver {
            NotificationCenter.default.removeObserver(obs)
            playerObserver = nil
        }
        if let obs = timeObserver, let player {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
        playerVC?.player?.pause()
    }
}
