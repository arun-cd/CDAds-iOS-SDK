import Foundation

public protocol CDAInterstitialDelegate: AnyObject {
    func interstitialDidLoad(_ interstitial: CDAInterstitialAd)
    func interstitialDidFailToLoad(_ interstitial: CDAInterstitialAd, error: CDAdsError)
    func interstitialWillAppear(_ interstitial: CDAInterstitialAd)
    func interstitialDidAppear(_ interstitial: CDAInterstitialAd)
    func interstitialWillDisappear(_ interstitial: CDAInterstitialAd)
    func interstitialDidDisappear(_ interstitial: CDAInterstitialAd)
    func interstitialDidExpire(_ interstitial: CDAInterstitialAd)
    func interstitialDidReceiveTap(_ interstitial: CDAInterstitialAd)
    func interstitialWillLeaveApplication(_ interstitial: CDAInterstitialAd)
}

public extension CDAInterstitialDelegate {
    func interstitialDidFailToLoad(_ interstitial: CDAInterstitialAd, error: CDAdsError) {}
    func interstitialWillAppear(_ interstitial: CDAInterstitialAd) {}
    func interstitialDidAppear(_ interstitial: CDAInterstitialAd) {}
    func interstitialWillDisappear(_ interstitial: CDAInterstitialAd) {}
    func interstitialDidDisappear(_ interstitial: CDAInterstitialAd) {}
    func interstitialDidExpire(_ interstitial: CDAInterstitialAd) {}
    func interstitialDidReceiveTap(_ interstitial: CDAInterstitialAd) {}
    func interstitialWillLeaveApplication(_ interstitial: CDAInterstitialAd) {}
}
