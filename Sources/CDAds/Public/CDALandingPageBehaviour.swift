/// Controls how tapped ad landing pages are presented.
public enum CDALandingPageBehaviour {
    /// Open the landing page inside the app using an in-app browser (default).
    case inAppBrowser

    /// Hand off to the device's default browser (Safari), leaving the app.
    case deviceBrowser
}
