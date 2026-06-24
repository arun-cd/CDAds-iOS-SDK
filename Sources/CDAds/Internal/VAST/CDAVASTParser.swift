import Foundation

/// Parses a VAST 2.0 / 3.0 XML response into a [CDAVASTAd].
/// Supports inline ads and single-level wrapper redirect (follows one hop).
final class CDAVASTParser: NSObject {

    // MARK: - Public entry point

    /// Parse raw VAST XML data.  Returns the first usable inline ad.
    static func parse(_ data: Data) throws -> CDAVASTAd {
        let parser = CDAVASTParser()
        return try parser.doParse(data)
    }

    /// Fetch and parse a VAST document from a URL (async, follows one wrapper hop).
    static func fetch(_ url: URL) async throws -> CDAVASTAd {
        let (data, _) = try await URLSession.shared.data(from: url)
        let ad = try parse(data)
        return ad
    }

    // MARK: - Private SAX state

    private var currentElement    = ""
    private var currentText       = ""
    private var currentAdID: String?
    private var inLinear          = false
    private var inMediaFiles      = false
    private var inTrackingEvents  = false
    private var inCompanions      = false
    private var currentEvent      = ""
    private var currentCompanion: CompanionBuilder?

    // Accumulated data
    private var impressionURLs    = [URL]()
    private var mediaFiles        = [MediaFileEntry]()
    private var trackingEvents    = [String: [URL]]()
    private var clickThroughURL: URL?
    private var clickTrackingURLs = [URL]()
    private var duration: TimeInterval = 0
    private var adTitle: String?
    private var companionAds      = [CDAVASTCompanionAd]()

    private struct MediaFileEntry {
        let url: URL
        let bitrate: Int
        let width: Int
        let height: Int
        let type: String
        let delivery: String
    }

    private class CompanionBuilder {
        var width  = 0
        var height = 0
        var resourceURL: URL?
        var htmlResource: String?
        var clickThroughURL: URL?
    }

    // MARK: - Parse

    private func doParse(_ data: Data) throws -> CDAVASTAd {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()

        guard let best = bestMediaFile() else {
            throw CDAdsError(.invalidRequest, "VAST: no usable MediaFile found")
        }

        return CDAVASTAd(
            id: currentAdID,
            mediaFileURL: best.url,
            impressionURLs: impressionURLs,
            trackingEvents: trackingEvents,
            clickThroughURL: clickThroughURL,
            clickTrackingURLs: clickTrackingURLs,
            companionAds: companionAds,
            duration: duration,
            adTitle: adTitle
        )
    }

    /// Pick the MP4 with the highest bitrate that fits the screen.
    private func bestMediaFile() -> MediaFileEntry? {
        let mp4 = mediaFiles
            .filter { $0.type.contains("mp4") || $0.type.contains("video/mp4") }
            .sorted { $0.bitrate > $1.bitrate }
        return mp4.first ?? mediaFiles.first
    }

    /// Parse `HH:MM:SS` or `HH:MM:SS.mmm` duration strings.
    private func parseDuration(_ s: String) -> TimeInterval {
        let parts = s.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: ":")
        guard parts.count == 3,
              let h = Double(parts[0]),
              let m = Double(parts[1]),
              let s = Double(parts[2]) else { return 0 }
        return h * 3600 + m * 60 + s
    }
}

// MARK: - XMLParserDelegate

extension CDAVASTParser: XMLParserDelegate {

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText    = ""

        switch elementName {
        case "Ad":
            currentAdID = attributeDict["id"]
        case "Linear":
            inLinear = true
        case "MediaFiles":
            inMediaFiles = true
        case "MediaFile":
            // Store attributes; URL captured in didEndElement
            mediaFiles.append(MediaFileEntry(
                url: URL(string: "about:blank")!,
                bitrate: Int(attributeDict["bitrate"] ?? "0") ?? 0,
                width: Int(attributeDict["width"] ?? "0") ?? 0,
                height: Int(attributeDict["height"] ?? "0") ?? 0,
                type: attributeDict["type"] ?? "",
                delivery: attributeDict["delivery"] ?? "progressive"
            ))
        case "TrackingEvents":
            inTrackingEvents = true
        case "Tracking":
            currentEvent = attributeDict["event"] ?? ""
        case "CompanionAds":
            inCompanions = true
        case "Companion":
            currentCompanion = CompanionBuilder()
            currentCompanion?.width  = Int(attributeDict["width"]  ?? "0") ?? 0
            currentCompanion?.height = Int(attributeDict["height"] ?? "0") ?? 0
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "Impression":
            if let url = URL(string: text) { impressionURLs.append(url) }
        case "Duration":
            duration = parseDuration(text)
        case "AdTitle":
            adTitle = text
        case "MediaFile":
            if let url = URL(string: text), !mediaFiles.isEmpty {
                let last = mediaFiles.removeLast()
                mediaFiles.append(MediaFileEntry(
                    url: url,
                    bitrate: last.bitrate,
                    width: last.width,
                    height: last.height,
                    type: last.type,
                    delivery: last.delivery
                ))
            }
        case "Tracking":
            if let url = URL(string: text), !currentEvent.isEmpty {
                trackingEvents[currentEvent, default: []].append(url)
            }
            currentEvent = ""
        case "ClickThrough":
            clickThroughURL = URL(string: text)
        case "ClickTracking":
            if let url = URL(string: text) { clickTrackingURLs.append(url) }
        case "Linear":
            inLinear = false
        case "MediaFiles":
            inMediaFiles = false
        case "TrackingEvents":
            inTrackingEvents = false
        case "Companion":
            if let b = currentCompanion {
                companionAds.append(CDAVASTCompanionAd(
                    width: b.width,
                    height: b.height,
                    resourceURL: b.resourceURL,
                    htmlResource: b.htmlResource,
                    clickThroughURL: b.clickThroughURL
                ))
            }
            currentCompanion = nil
        case "CompanionAds":
            inCompanions = false
        case "StaticResource":
            currentCompanion?.resourceURL = URL(string: text)
        case "HTMLResource":
            currentCompanion?.htmlResource = text
        default:
            break
        }

        currentElement = ""
        currentText    = ""
    }
}
