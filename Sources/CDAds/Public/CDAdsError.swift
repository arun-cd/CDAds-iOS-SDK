import Foundation

public struct CDAdsError: Error {

    public enum Code: Int {
        case unknown         = 0
        case noFill          = 1
        case networkError    = 2
        case timeout         = 3
        case invalidRequest  = 4
        case adExpired       = 5
        case sdkNotInitialized = 6
    }

    public let code: Code
    public let message: String

    public init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }
}

extension CDAdsError: LocalizedError {
    public var errorDescription: String? { "CDAds[\(code.rawValue)]: \(message)" }
}
