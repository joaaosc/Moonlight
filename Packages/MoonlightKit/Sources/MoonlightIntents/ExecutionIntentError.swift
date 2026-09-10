import Foundation

public enum ExecutionIntentError: Error, LocalizedError, Sendable {
    case invalidExecutionIdentifier(String)
    case executionNotFound(UUID)
    /// The runtime recorded a failed execution. A call that did not throw is
    /// not a success: a domain failure must never be reported as one.
    case executionFailed(String)
    /// The stored result has nothing to copy or save.
    case resultHasNoValue(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidExecutionIdentifier(identifier):
            "Execution identifier \(identifier) is invalid."
        case let .executionNotFound(identifier):
            "Execution \(identifier.uuidString) was not found."
        case let .executionFailed(detail):
            detail
        case let .resultHasNoValue(actionTitle):
            "\(actionTitle) produced no value to copy or save."
        }
    }
}
