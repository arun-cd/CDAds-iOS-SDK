import Foundation

/// Structured assets for a native ad.
/// Passed to `CDANativeAdDelegate.nativeAdDidLoad` — the host app renders
/// the widget from these fields.
public struct CDANativeAdData {

    /// Unique ID for this ad instance. Required for impression/click tracking.
    public let adId: String
    public let adUnitId: String

    public let title: String?
    public let body: String?
    public let callToAction: String?
    public let advertiser: String?
    public let sponsoredLabel: String?
    public let mainImageURL: URL?
    public let iconImageURL: URL?
    public let starRating: Double?
    public let price: String?
    public let clickURL: URL?

    /// Present only for native video ads.
    public let vastTagURL: URL?

    /// Impression pixel URLs — fire all of these once when the ad is visible.
    public let impressionTrackers: [URL]

    /// Click pixel URLs — fire all of these when the user taps the ad.
    public let clickTrackers: [URL]

    /// Any extra key-value assets from the ad server not covered above.
    public let extras: [String: String]
}
