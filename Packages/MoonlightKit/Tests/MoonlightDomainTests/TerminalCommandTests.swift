import Foundation
import Testing
@testable import MoonlightDomain

@Suite("Terminal commands")
struct TerminalCommandTests {
    private func command(
        lines: [String] = ["echo hello"],
        title: String = "Greet",
        alias: String = "greet"
    ) -> TerminalCommand {
        TerminalCommand(title: title, lines: lines, alias: alias)
    }

    @Test("A script with a placeholder takes text; one without does not")
    func derivesInputKind() {
        let querying = command(lines: ["ssh {query}", "uptime"])
        let direct = command(lines: ["uptime"])

        #expect(querying.acceptsQuery)
        #expect(querying.definition().presentation.inputKind == .text)
        #expect(!direct.acceptsQuery)
        #expect(direct.definition().presentation.inputKind == .none)
        #expect(direct.definition().presentation.destination == .terminalScript)
    }

    @Test("Typed text is substituted raw into the script")
    func substitutesQuery() throws {
        let command = command(lines: ["ssh {query}", "uptime"])

        let script = try command.resolvedScript(query: "deploy-1")

        #expect(script == "ssh deploy-1\nuptime")
    }

    @Test("A script without a placeholder refuses text instead of dropping it")
    func refusesUnexpectedText() {
        let command = command(lines: ["uptime"])

        #expect(throws: ToolActionError.unexpectedInput) {
            _ = try command.resolvedScript(query: "moonlight")
        }
    }

    @Test("A command runs through the shared runner and records its script")
    func runsThroughActionRunner() async throws {
        let command = command(lines: ["echo {query}"])
        let cache = TerminalCache(commands: [command])
        let registry = ActionRegistry(
            handlers: ActionRegistry.standardHandlers,
            resolvers: [TerminalCommandHandlerResolver(cache: cache)]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: command.commandID, input: "hello")
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail == "echo hello")
        #expect(try TerminalCommandProvider(cache: cache).snapshot().count == 1)
    }

    @Test("An empty query fails instead of running an incomplete script")
    func refusesEmptyQuery() async throws {
        let command = command(lines: ["echo {query}"])
        let registry = ActionRegistry(
            handlers: [],
            resolvers: [TerminalCommandHandlerResolver(cache: TerminalCache(commands: [command]))]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: command.commandID, input: "   ")
        )

        #expect(execution.status == .failed)
        #expect(execution.resolvedFailure?.code == "empty-input")
    }

    @Test("A command with no runnable line fails with a stable code")
    func refusesBlankScript() async throws {
        let command = command(lines: ["   "])
        let registry = ActionRegistry(
            handlers: [],
            resolvers: [TerminalCommandHandlerResolver(cache: TerminalCache(commands: [command]))]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: command.commandID, input: "")
        )

        #expect(execution.status == .failed)
        #expect(execution.resolvedFailure?.code == "empty-terminal-script")
    }
}
