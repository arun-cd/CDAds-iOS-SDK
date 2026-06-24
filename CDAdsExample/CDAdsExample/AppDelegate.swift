import UIKit
import AppTrackingTransparency
import CDAds

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Identity values (host, partnerKey, etc.) come from CDAdsParams in Info.plist.
        // Only behavioural options are set here.
        var config = CDAdsConfiguration()
        config.environment            = .production
        config.logLevel               = .all
        config.enableTracking         = true
        // Tells the SDK the app's own consent/permission flow already covers tracking —
        // without this, /track requests blank out all device-identifying fields.
        config.clientHasUserTrackingPermission = true
        config.enableLocationTracking = true
        config.locationUpdateInterval = 150
        config.locationExpiryInterval = 300
        config.locationDistanceFilter = 5

        CDAds.initialize(with: config)

        // Request ATT after a short delay so the app UI is visible first.
        // The SDK reads ATTrackingManager.trackingAuthorizationStatus at each
        // ad request, so no manual update is needed after this callback.
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
