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

    static func execution(id: UUID) async throws -> Execution? {
        let environment = try MoonlightProcess.requireEnvironment()
        return try await environment.client.execution(id)
    }
}
