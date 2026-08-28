import AppIntents
import MoonlightInfrastructure

public struct ExecutionQuery: EntityQuery {
    private let injectedClient: MoonlightRuntimeClient?

    public init() {
        injectedClient = nil
    }

    public init(client: MoonlightRuntimeClient) {
        injectedClient = client
    }

    public func entities(for identifiers: [ExecutionEntity.ID]) async throws -> [ExecutionEntity] {
        let client = try resolvedClient()
        var entities: [ExecutionEntity] = []
        for identifier in identifiers {
            if let execution = try await client.execution(identifier) {
                entities.append(ExecutionEntity(execution: execution))
            }
        }
        return entities
    }

    public func suggestedEntities() async throws -> [ExecutionEntity] {
        let client = try resolvedClient()
        return try await client.recent(20).map(ExecutionEntity.init(execution:))
    }

    private func resolvedClient() throws -> MoonlightRuntimeClient {
        if let injectedClient {
            injectedClient
        } else {
            try MoonlightRuntime.client()
        }
    }
}
