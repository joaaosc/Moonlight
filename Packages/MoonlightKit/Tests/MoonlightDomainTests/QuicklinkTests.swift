import Foundation
import Testing
@testable import MoonlightDomain

@Suite("Quicklink commands")
struct QuicklinkTests {
    private func quicklink(
        template: String,
        title: String = "Search",
        alias: String = "search"
    ) -> QuicklinkCommand {
        QuicklinkCommand(title: title, urlTemplate: template, alias: alias)
    }

    @Test("A template with a placeholder takes text; one without does not")
    func derivesInputKind() {
        let searching = quicklink(template: "https://example.com/s?q={query}")
        let direct = quicklink(template: "https://example.com")

        #expect(searching.acceptsQuery)
        #expect(searching.definition().presentation.inputKind == .text)
        #expect(!direct.acceptsQuery)
        #expect(direct.definition().presentation.inputKind == .none)
        #expect(direct.definition().presentation.destination == .externalURL)
    }

    @Test("Typed text is encoded so it cannot change the query structure")
    func encodesQueryValue() throws {
        let link = quicklink(template: "https://example.com/s?q={query}&safe=1")

        let url = try link.resolvedURL(query: "moon & stars=2")

        #expect(url.absoluteString == "https://example.com/s?q=moon%20%26%20stars%3D2&safe=1")
    }

    @Test("A link without a placeholder refuses text instead of dropping it")
    func refusesUnexpectedText() {
        let link = quicklink(template: "https://example.com")

        #expect(throws: ToolActionError.unexpectedInput) {
            _ = try link.resolvedURL(query: "moonlight")
        }
    }

    @Test("An address without a scheme is refused")
    func refusesInvalidTemplate() {
        let link = quicklink(template: "example.com/{query}")

        #expect(throws: QuicklinkError.invalidTemplate("example.com/{query}")) {
            _ = try link.resolvedURL(query: "moonlight")
        }
    }

    @Test("A quicklink runs through the shared runner and records its URL")
    func runsThroughActionRunner() async throws {
        let link = quicklink(template: "https://example.com/s?q={query}")
        let cache = QuicklinkCache(quicklinks: [link])
        let registry = ActionRegistry(
            handlers: ActionRegistry.standardHandlers,
            resolvers: [QuicklinkCommandHandlerResolver(cache: cache)]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: link.commandID, input: "moonlight")
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail == "https://example.com/s?q=moonlight")
        #expect(try QuicklinkCommandProvider(cache: cache).snapshot().count == 1)
    }

    @Test("An empty query fails instead of opening an incomplete address")
    func refusesEmptyQuery() async throws {
        let link = quicklink(template: "https://example.com/s?q={query}")
        let registry = ActionRegistry(
            handlers: [],
            resolvers: [QuicklinkCommandHandlerResolver(cache: QuicklinkCache(quicklinks: [link]))]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: link.commandID, input: "   ")
        )

        #expect(execution.status == .failed)
        #expect(execution.resolvedFailure?.code == "empty-input")
    }
}
