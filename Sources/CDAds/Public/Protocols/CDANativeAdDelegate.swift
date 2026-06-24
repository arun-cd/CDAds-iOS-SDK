import Foundation

public protocol CDANativeAdDelegate: AnyObject {
    func nativeAdDidLoad(_ request: CDANativeAdRequest, data: CDANativeAdData)
    func nativeAdDidFailToLoad(_ request: CDANativeAdRequest, error: CDAdsError)
    func nativeAdDidExpire(_ request: CDANativeAdRequest)
}

public extension CDANativeAdDelegate {
    func nativeAdDidFailToLoad(_ request: CDANativeAdRequest, error: CDAdsError) {}
    func nativeAdDidExpire(_ request: CDANativeAdRequest) {}
}
