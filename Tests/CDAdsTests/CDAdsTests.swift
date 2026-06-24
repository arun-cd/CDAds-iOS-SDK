import XCTest
@testable import CDAds

final class CDAdsConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = CDAdsConfiguration(
            appKey: "test_app_key",
            partnerKey: "test_partner_key",
            secretKey: "test_secret",
            host: "https://ads.example.com",
            appName: "TestApp",
            applicationIABCategory: "IAB1"
        )

        XCTAssertEqual(config.appKey, "test_app_key")
        XCTAssertEqual(config.environment, .production)
        XCTAssertEqual(config.logLevel, .off)
        XCTAssertFalse(config.enableTracking)
        XCTAssertFalse(config.enableLocationTracking)
        XCTAssertFalse(config.gdprApplies)
        XCTAssertEqual(config.locationDistanceFilter, 100)
        XCTAssertEqual(config.locationUpdateInterval, 30)
        XCTAssertEqual(config.locationExpiryInterval, 300)
    }

    func testAdRequestDefaults() {
        let request = CDAdsAdRequest(adUnitId: "placement_123")
        XCTAssertEqual(request.adUnitId, "placement_123")
        XCTAssertNil(request.keywords)
        XCTAssertNil(request.geoInfo)
        XCTAssertFalse(request.locationAutoUpdateEnabled)
    }

    func testGeoInfoInit() {
        let geo = CDAdsGeoInfo(latitude: 35.6762, longitude: 139.6503)
        XCTAssertEqual(geo.latitude, 35.6762)
        XCTAssertEqual(geo.longitude, 139.6503)
        XCTAssertEqual(geo.sourceType, .gps)
    }

    func testCDAdsErrorDescription() {
        let error = CDAdsError(.noFill, "No ads available")
        XCTAssertEqual(error.code, .noFill)
        XCTAssertTrue(error.errorDescription?.contains("No ads available") ?? false)
    }

    func testRewardInit() {
        let reward = CDAReward(currencyType: "coins", amount: 10)
        XCTAssertEqual(reward.currencyType, "coins")
        XCTAssertEqual(reward.amount, 10)
    }
}
