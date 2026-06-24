import Foundation

/// Parsed representation of a VAST 2.0 / 3.0 response.
struct CDAVASTAd {
    let id: String?

    // MediaFile with highest bitrate / best match
    let mediaFileURL: URL

    /// All impression tracking pixels
    let impressionURLs: [URL]

    // Tracking events keyed by event name (start, firstQuartile, midpoint, thirdQuartile, complete, etc.)
    let trackingEvents: [String: [URL]]

    // Click-through URL
    let clickThroughURL: URL?

    // Click-tracking pixels
    let clickTrackingURLs: [URL]

    // Optional companion banner HTML / resources
    let companionAds: [CDAVASTCompanionAd]

    // Ad duration in seconds (from <Duration> element)
    let duration: TimeInterval

    // Ad title / description
    let adTitle: String?
}

struct CDAVASTCompanionAd {
    let width: Int
    let height: Int
    let resourceURL: URL?
    let htmlResource: String?
    let clickThroughURL: URL?
}
