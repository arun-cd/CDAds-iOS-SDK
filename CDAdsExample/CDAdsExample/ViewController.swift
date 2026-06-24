import UIKit
import CDAds

class ViewController: UIViewController {

    // MARK: - IBOutlets (layout defined in Main.storyboard)

    @IBOutlet private weak var banner300Container: UIView!   // 300x250 MREC — centred
    @IBOutlet private weak var banner320Container: UIView!   // 320x50  banner — bottom
    @IBOutlet private weak var locationLabel: UILabel!

    // MARK: - Ad views (embedded into the containers above)

    private var banner300: CDABannerView?
    private var banner320: CDABannerView?

    // MARK: - Ad rotation

    private enum ActiveBanner { case small, medium }
    private var activeBanner: ActiveBanner = .small
    private var refreshTimer: Timer?
    private let adRefreshInterval: TimeInterval = 30
    private var isViewVisible = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CDAds Example"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Settings",
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        setupBanners()
        setupLocationCallback()
        setupForegroundObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Foreground-only ad requests
    // The app — not the SDK — decides when it's appropriate to request ads.
    // Pause rotation while backgrounded and only resume/request once active again.

    private func setupForegroundObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        guard isViewVisible else { return }
        startAdRotation()
    }

    @objc private func appWillResignActive() {
        stopAdRotation()
    }

    private func isAppInForeground() -> Bool {
        UIApplication.shared.applicationState == .active
    }

    @objc private func openSettings() {
        let vc = SettingsViewController(style: .insetGrouped)
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewVisible = true
        startAdRotation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewVisible = false
        stopAdRotation()
    }

    // MARK: - Banner setup
    // CDABannerView requires init(size:) so it cannot be placed directly in IB.
    // We embed it into the plain UIView containers that define the layout.
    // A placeholder is added first (lower z-order); the transparent WKWebView sits on top
    // and shows the placeholder until the ad renders, at which point it is covered.

    private func setupBanners() {
        banner300Container.addSubview(makePlaceholder(for: banner300Container))
        let mrec = CDABannerView(size: .banner300x250)
        mrec.delegate = self
        mrec.showCloseButton = true
        mrec.frame = banner300Container.bounds
        mrec.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        banner300Container.addSubview(mrec)
        banner300 = mrec

        banner320Container.addSubview(makePlaceholder(for: banner320Container))
        let leaderboard = CDABannerView(size: .banner320x50)
        leaderboard.delegate = self
        leaderboard.showCloseButton = true
        leaderboard.frame = banner320Container.bounds
        leaderboard.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        banner320Container.addSubview(leaderboard)
        banner320 = leaderboard
    }

    private func makePlaceholder(for container: UIView) -> UIView {
        let view = UIView(frame: container.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = UIColor.gray
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 4

        let label = UILabel()
        label.text = "Advertisement"
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .systemGray3
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    // MARK: - Location callback

    private func setupLocationCallback() {
        CDAds.shared.location.onLocationUpdated = { [weak self] geo in
            DispatchQueue.main.async {
                self?.locationLabel.text = String(
                    format: "Tracking: lat %.4f  lon %.4f",
                    geo.latitude, geo.longitude
                )
            }
        }
    }

    // MARK: - Ad rotation

    private func startAdRotation() {
        banner300?.isAutoRefreshEnabled = false
        banner320?.isAutoRefreshEnabled = false
        // Show the active slot immediately so the placeholder is visible while the first ad loads.
        showBanner(activeBanner)
        loadBanner(.small)
        loadBanner(.medium)
        scheduleRotationTimer()
    }

    private func stopAdRotation() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func scheduleRotationTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: adRefreshInterval, repeats: false) { [weak self] _ in
            self?.rotateBanner()
        }
    }

    private func rotateBanner() {
        let next: ActiveBanner = (activeBanner == .small) ? .medium : .small
        activeBanner = next
        // Show the already-loaded incoming banner immediately (no blank gap).
        showBanner(next)
        scheduleRotationTimer()
        // Reload the outgoing banner after the full interval so the next swap has a fresh ad,
        // without sending a second request to the server right at the moment of rotation.
        let outgoing: ActiveBanner = (next == .small) ? .medium : .small
        DispatchQueue.main.asyncAfter(deadline: .now() + adRefreshInterval) { [weak self] in
            self?.loadBanner(outgoing)
        }
    }

    private func makeRequest() -> CDAdsAdRequest {
        var request = CDAdsAdRequest(adUnitId: "1")
        request.geoInfo   = LocationOverrideSettings.makeGeoInfo()
        request.ipAddress = LocationOverrideSettings.makeIPAddress()
//        request.targetingYearOfBirth = "30"
//        request.targetingIncome = "100000";
//        request.targetingGender = "MALE"
//        request.targetingEducation = "BACHELOR"
//        request.targetingLanguage = "EN"
//        request.keywords = "keyword1, keyword2"
        if request.geoInfo == nil {
            request.locationAutoUpdateEnabled = true
        }
        return request
    }

    private func loadBanner(_ which: ActiveBanner) {
        // Only request ads while the app is in the foreground.
        guard isAppInForeground() else { return }
        switch which {
        case .small:  banner320?.load(request: makeRequest())
        case .medium: banner300?.load(request: makeRequest())
        }
    }

    private func showBanner(_ which: ActiveBanner) {
        switch which {
        case .small:
            banner320Container.isHidden = false
            banner300Container.isHidden = true
        case .medium:
            banner300Container.isHidden = false
            banner320Container.isHidden = true
        }
    }
}

// MARK: - CDABannerDelegate

extension ViewController: CDABannerDelegate {

    func bannerDidLoad(_ banner: CDABannerView) {
        // Reveal the banner only when it matches the currently active slot.
        if banner === banner320, activeBanner == .small {
            showBanner(.small)
        } else if banner === banner300, activeBanner == .medium {
            showBanner(.medium)
        }
    }

    func bannerDidFailToLoad(_ banner: CDABannerView, error: CDAdsError) {
        let which: ActiveBanner = (banner === banner320) ? .small : .medium
        print("[CDAds] Banner \(which == .small ? "320x50" : "300x250") failed: \(error)")
        // Retry after the same interval as a normal refresh — avoids hammering the server on no-fill.
        DispatchQueue.main.asyncAfter(deadline: .now() + adRefreshInterval) { [weak self] in
            self?.loadBanner(which)
        }
    }

    func bannerDidReceiveTap(_ banner: CDABannerView) {
        print("[CDAds] Banner tapped")
    }
}
