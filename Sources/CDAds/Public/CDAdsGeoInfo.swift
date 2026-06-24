import Foundation

/// Geo-location data used for ad targeting and location tracking.
public struct CDAdsGeoInfo: Codable {

    /// Location source: 1 = GPS, 2 = IP lookup, 3 = user-provided.
    public enum SourceType: Int, Codable {
        case gps          = 1
        case ipLookup     = 2
        case userProvided = 3
    }

    public var latitude: Double
    public var longitude: Double
    public var sourceType: SourceType = .gps

    public var countryCode: String?
    public var region: String?
    public var city: String?
    public var zip: String?
    public var streetAddress: String?

    /// Horizontal accuracy of the location fix in metres.
    public var horizontalAccuracy: Double?

    /// Public IP address of the device at the time the location was captured.
    public var ipAddress: String?

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
