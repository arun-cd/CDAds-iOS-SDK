import Foundation

public protocol CDARewardedVideoDelegate: AnyObject {
    func rewardedVideoDidLoad(_ ad: CDARewardedVideoAd)
    func rewardedVideoDidFailToLoad(_ ad: CDARewardedVideoAd, error: CDAdsError)
    func rewardedVideoDidFailToPlay(_ ad: CDARewardedVideoAd, error: CDAdsError)
    func rewardedVideoDidExpire(_ ad: CDARewardedVideoAd)
    func rewardedVideoWillAppear(_ ad: CDARewardedVideoAd)
    func rewardedVideoDidAppear(_ ad: CDARewardedVideoAd)
    func rewardedVideoWillDisappear(_ ad: CDARewardedVideoAd)
    func rewardedVideoDidDisappear(_ ad: CDARewardedVideoAd)
    func rewardedVideoDidReceiveTap(_ ad: CDARewardedVideoAd)
    func rewardedVideoWillLeaveApplication(_ ad: CDARewardedVideoAd)
    func rewardedVideoShouldRewardUser(_ ad: CDARewardedVideoAd, reward: CDAReward)
}

public extension CDARewardedVideoDelegate {
    func rewardedVideoDidFailToLoad(_ ad: CDARewardedVideoAd, error: CDAdsError) {}
    func rewardedVideoDidFailToPlay(_ ad: CDARewardedVideoAd, error: CDAdsError) {}
    func rewardedVideoDidExpire(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoWillAppear(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoDidAppear(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoWillDisappear(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoDidDisappear(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoDidReceiveTap(_ ad: CDARewardedVideoAd) {}
    func rewardedVideoWillLeaveApplication(_ ad: CDARewardedVideoAd) {}
}
