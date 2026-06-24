import Foundation

/// Targeting parameters attached to every individual ad load call.
public struct CDAdsAdRequest {

    public let adUnitId: String

    /// Comma-separated key-value pairs, e.g. `"age:30,interests:travel"`.
    public var keywords: String?

    public var targetingYearOfBirth: String?
    public var targetingGender: String?
    public var targetingIncome: String?
    public var targetingEducation: String?
    public var targetingLanguage: String?

    /// When `true` the SDK appends the latest known device location to the request.
    public var locationAutoUpdateEnabled: Bool = false

    /// Manual geo override. Takes precedence over device location when set.
    public var geoInfo: CDAdsGeoInfo?

    /// Manual IP address override. Takes precedence over the SDK's auto-fetched public IP when set.
    public var ipAddress: String?

    public init(adUnitId: String) {
        self.adUnitId = adUnitId
    }
}
