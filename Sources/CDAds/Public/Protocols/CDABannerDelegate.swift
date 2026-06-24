import Foundation

public protocol CDABannerDelegate: AnyObject {
    func bannerDidLoad(_ banner: CDABannerView)
    func bannerDidFailToLoad(_ banner: CDABannerView, error: CDAdsError)
    func bannerDidReceiveTap(_ banner: CDABannerView)
    func bannerWillLeaveApplication(_ banner: CDABannerView)
    /// Called when an MRAID ad expands to fullscreen.
    func bannerDidExpand(_ banner: CDABannerView)
    /// Called when an MRAID expanded ad collapses back to its default state.
    func bannerDidCollapse(_ banner: CDABannerView)
    /// Called when the user taps the close button on the banner.
    func bannerDidClose(_ banner: CDABannerView)
}

// All callbacks are optional by default.
public extension CDABannerDelegate {
    func bannerDidFailToLoad(_ banner: CDABannerView, error: CDAdsError) {}
    func bannerDidReceiveTap(_ banner: CDABannerView) {}
    func bannerWillLeaveApplication(_ banner: CDABannerView) {}
    func bannerDidExpand(_ banner: CDABannerView) {}
    func bannerDidCollapse(_ banner: CDABannerView) {}
    func bannerDidClose(_ banner: CDABannerView) {}
}
