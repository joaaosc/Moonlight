import MoonlightDomain
import MoonlightInfrastructure

enum MoonlightIntentExecutor {
    static func execute(actionID: String, input: String) async throws -> ExecutionEntity {
        let client = try MoonlightRuntime.client()
        let execution = try await client.execute(
            ActionRequest(actionID: actionID, input: input)
        )
        return ExecutionEntity(execution: execution)
    }
}
