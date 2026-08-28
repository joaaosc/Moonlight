import MoonlightDomain
import MoonlightInfrastructure

enum MoonlightIntentExecutor {
    static func execute(actionID: String, input: String) async throws -> Execution {
        let client = try MoonlightRuntime.client()
        return try await client.execute(
            ActionRequest(actionID: actionID, input: input)
        )
    }
}
