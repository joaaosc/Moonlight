import AppIntents
import MoonlightDomain
import MoonlightInfrastructure
import MoonlightIntents
import Testing

@Suite("App Intents adapters")
struct AppIntentsAdapterTests {
    @Test("Action query returns requested known identifiers")
    func actionQueryFiltersIdentifiers() async throws {
        let descriptors = [
            ActionDescriptor(id: "one", title: "One", summary: "First"),
            ActionDescriptor(id: "two", title: "Two", summary: "Second"),
        ]
        let query = ActionQuery(descriptors: descriptors)

        let entities = try await query.entities(for: ["two", "missing"])

        #expect(entities.map(\.id) == ["two"])
        #expect(try await query.suggestedEntities().map(\.id) == ["one", "two"])
    }

    @Test("Execution query resolves persisted entities and omits missing identifiers")
    func executionQueryResolvesStoredExecutions() async throws {
        let client = MoonlightRuntimeClient.inMemory()
        let execution = try await client.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: "From intent test")
        )
        let query = ExecutionQuery(client: client)

        let entities = try await query.entities(for: [UUID(), execution.id])

        #expect(entities.map(\.id) == [execution.id])
        #expect(try await query.suggestedEntities().map(\.id) == [execution.id])
    }

    @Test("Execution presentation is a hidden main-process snippet intent")
    func snippetContract() {
        requireSnippetIntent(ExecutionSnippetIntent.self)
        #expect(!ExecutionSnippetIntent.isDiscoverable)
        #expect(ExecutionSnippetIntent.supportedExecutionTargets.contains(.main))
    }
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
