import Foundation
import os.log

/// Internal SDK logger.
///
/// `logLevel` (from `CDAdsConfiguration`) controls *only* the unified logging
/// system (Console.app/Xcode) mirror — it's a development-debugging knob.
/// In-app file/buffer capture (`CDADebugLogStore`, surfaced via the `*##*`
/// debug viewer) is a completely separate, persisted on/off switch that every
/// line is offered to regardless of `logLevel` — see `CDADebugLogStore.isEnabled`.
/// This split matters in production: a shipped app might run with `logLevel =
/// .off` (no Console noise) while a support rep still needs to flip on file
/// logging in the field via the secret code, with no rebuild required.
enum CDALogger {

    private static var level: CDAdsConfiguration.LogLevel = .off
    private static let logger = Logger(subsystem: "com.chalkdigital.cdads", category: "SDK")

    static let logsUpdatedNotification = Notification.Name("CDAdsLogsUpdatedNotification")

    static func configure(level: CDAdsConfiguration.LogLevel) {
        self.level = level
    }

    /// Most verbose level — full network request/response payloads.
    /// Active when log level is `.all` or `.trace`.
    static func trace(_ message: String, file: String = #fileID) {
        capture(message, file: file)
        guard level.rawValue <= CDAdsConfiguration.LogLevel.trace.rawValue else { return }
        logger.debug("[\(shortFile(file))] \(message)")
    }

    static func debug(_ message: String, file: String = #fileID) {
        capture(message, file: file)
        guard level.rawValue <= CDAdsConfiguration.LogLevel.debug.rawValue else { return }
        logger.debug("[\(shortFile(file))] \(message)")
    }

    static func info(_ message: String, file: String = #fileID) {
        capture(message, file: file)
        guard level.rawValue <= CDAdsConfiguration.LogLevel.info.rawValue else { return }
        logger.info("[\(shortFile(file))] \(message)")
    }

    static func warn(_ message: String, file: String = #fileID) {
        capture(message, file: file)
        guard level.rawValue <= CDAdsConfiguration.LogLevel.warn.rawValue else { return }
        logger.warning("[\(shortFile(file))] \(message)")
    }

    static func error(_ message: String, file: String = #fileID) {
        capture(message, file: file)
        guard level.rawValue <= CDAdsConfiguration.LogLevel.error.rawValue else { return }
        logger.error("[\(shortFile(file))] \(message)")
    }

    /// Offers the line to the file/buffer store — no-ops internally unless
    /// `CDADebugLogStore.isEnabled`. Deliberately not gated by `level`.
    private static func capture(_ message: String, file: String) {
        CDADebugLogStore.shared.append(message, file: shortFile(file))
    }

    private static func shortFile(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
