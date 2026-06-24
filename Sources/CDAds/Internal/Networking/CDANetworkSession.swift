import Foundation

/// Thin `URLSession` wrapper used by all SDK network calls.
/// Centralises timeout config, error mapping, response validation, and logging.
///
/// Set `CDAdsConfiguration.logLevel = .all` (or `.trace`) to print full
/// request URLs, POST bodies, HTTP status codes, and response payloads.
actor CDANetworkSession {

    static let shared = CDANetworkSession()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 60
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = [
            "Accept":       "application/json",
            "Content-Type": "application/json",
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - GET

    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        CDALogger.trace("→ GET \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)
        try validate(response, data: data)

        CDALogger.trace("← \(httpStatus(response)) \(prettyJSON(data) ?? rawString(data))")
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST

    /// POST with pre-encoded body data (used for OpenRTB JSON built via JSONSerialization).
    func post<Response: Decodable>(_ url: URL, bodyData: Data, as responseType: Response.Type) async throws -> Response {
        CDALogger.trace("→ POST \(url.absoluteString)")
        CDALogger.trace("  Body: \(prettyJSON(bodyData) ?? rawString(bodyData))")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody   = bodyData

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)

        CDALogger.trace("← \(httpStatus(response)) \(prettyJSON(data) ?? rawString(data))")
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ url: URL,
        body: Body,
        as responseType: Response.Type
    ) async throws -> Response {
        let bodyData = try JSONEncoder().encode(body)

        CDALogger.trace("→ POST \(url.absoluteString)")
        CDALogger.trace("  Body: \(prettyJSON(bodyData) ?? rawString(bodyData))")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody   = bodyData

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)

        CDALogger.trace("← \(httpStatus(response)) \(prettyJSON(data) ?? rawString(data))")
        return try JSONDecoder().decode(Response.self, from: data)
    }

    // MARK: - Beacon

    /// Fire-and-forget beacon — used for impression and click tracking pixels.
    nonisolated func beacon(_ url: URL) {
        CDALogger.trace("→ BEACON \(url.absoluteString)")
        Task {
            _ = try? await session.data(from: url)
        }
    }

    // MARK: - Private

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CDAdsError(.networkError, "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Always log the error body regardless of log level so failures are diagnosable.
            CDALogger.error("HTTP \(http.statusCode) \(response.url?.absoluteString ?? "") — \(rawString(data))")
            throw CDAdsError(.networkError, "HTTP \(http.statusCode)")
        }
    }

    private func httpStatus(_ response: URLResponse) -> String {
        guard let http = response as? HTTPURLResponse else { return "???" }
        return "\(http.statusCode)"
    }

    private func prettyJSON(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        else { return nil }
        return String(data: pretty, encoding: .utf8)
    }

    private func rawString(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }
}
