import Foundation

public enum ExecutionIntentError: Error, LocalizedError, Sendable {
    case invalidExecutionIdentifier(String)
    case executionNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case let .invalidExecutionIdentifier(identifier):
            "Execution identifier \(identifier) is invalid."
        case let .executionNotFound(identifier):
            "Execution \(identifier.uuidString) was not found."
        }
    }
}
