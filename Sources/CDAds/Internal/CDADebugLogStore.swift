import Foundation

/// Captures SDK log lines for in-app display, independent of the unified
/// logging system *and* independent of `CDAdsConfiguration.logLevel` — that
/// level only controls os_log/Console verbosity for development debugging.
/// File capture is a separate, persisted on/off switch (mirrors the old
/// Tempo SDK's `CDFileLogsEnabled` flag), gated by `isEnabled` below, so a
/// support rep can reveal the `*##*` viewer and turn logging on in the field
/// without the level the app shipped with mattering at all.
///
/// Persists to `Documents/CDAdsLogs.txt` so logs from a background-only launch
/// (e.g. an SLC/geofence wake with no UI) survive until the user next opens the
/// app and views them via `CDADebugLogViewController`.
final class CDADebugLogStore {

    static let shared = CDADebugLogStore()

    private static let enabledDefaultsKey = "CDAdsFileLogsEnabled"

    /// Whether log lines are written to the buffer/file. Defaults to `false` —
    /// matches the old SDK, which never wrote to disk until a user/support rep
    /// explicitly flipped it on via the debug viewer. Independent of `logLevel`.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledDefaultsKey) }
    }

    private let maxLines = 5000
    private let queue = DispatchQueue(label: "com.chalkdigital.cdads.debuglog")
    private var lines: [String] = []
    let fileURL: URL

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        fileURL = (docs ?? FileManager.default.temporaryDirectory).appendingPathComponent("CDAdsLogs.txt")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        if let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) {
            lines = text.split(separator: "\n", omittingEmptySubsequences: true).suffix(maxLines).map(String.init)
        }
    }

    /// Called for every log line regardless of `logLevel` — no-ops unless
    /// `isEnabled` is `true`.
    func append(_ message: String, file: String) {
        guard isEnabled else { return }
        let line = "\(dateFormatter.string(from: Date())) [\(file)] \(message)"
        queue.async { [self] in
            lines.append(line)
            if lines.count > maxLines {
                lines.removeFirst(lines.count - maxLines)
            }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8) ?? Data())
                try? handle.close()
            }
            NotificationCenter.default.post(name: CDALogger.logsUpdatedNotification, object: nil)
        }
    }

    /// Current buffered log text, oldest first. Safe to call from any thread.
    func currentText() -> String {
        queue.sync { lines.joined(separator: "\n") }
    }

    func clear() {
        queue.async { [self] in
            lines.removeAll()
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: CDALogger.logsUpdatedNotification, object: nil)
        }
    }
}
