import Foundation

public enum ExecutionIntentError: Error, LocalizedError, Sendable {
    case executionNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case let .executionNotFound(identifier):
            "Execution \(identifier.uuidString) was not found."
        }
    }
}
