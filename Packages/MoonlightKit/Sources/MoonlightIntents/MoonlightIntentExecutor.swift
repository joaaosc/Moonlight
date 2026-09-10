import Foundation
import MoonlightDomain
import MoonlightInfrastructure

enum MoonlightIntentExecutor {
    /// The extension process composes its own environment; only the history
    /// document in the App Group is shared with the app.
    static func execute(actionID: String, input: String) async throws -> Execution {
        let environment = try MoonlightProcess.requireEnvironment()
        return try await environment.client.execute(
            ActionRequest(actionID: actionID, input: input)
        )
    }

    /// Runs a command and refuses to hand back a failed record as a result.
    /// One invocation produces exactly one execution.
    static func succeeded(
        actionID: String,
        input: String,
        parameters: ActionParameters = .empty
    ) async throws -> Execution {
        let environment = try MoonlightProcess.requireEnvironment()
        let execution = try await environment.client.execute(
            ActionRequest(actionID: actionID, input: input, parameters: parameters)
        )
        guard execution.status == .succeeded else {
            throw ExecutionIntentError.executionFailed(execution.detail)
        }
        return execution
    }

    /// Resolves a stored execution from a raw identifier, keeping the two
    /// failure modes apart: a malformed identifier and a record that is gone.
    static func storedExecution(rawIdentifier: String) async throws -> Execution {
        guard let identifier = UUID(uuidString: rawIdentifier) else {
            throw ExecutionIntentError.invalidExecutionIdentifier(rawIdentifier)
        }
        guard let execution = try await execution(id: identifier) else {
            throw ExecutionIntentError.executionNotFound(identifier)
        }
        return execution
    }

    static func execution(id: UUID) async throws -> Execution? {
        let environment = try MoonlightProcess.requireEnvironment()
        return try await environment.client.execution(id)
    }
}
