import Foundation
import Testing
@testable import MoonlightDomain

@Suite("Shortcut command execution")
struct ShortcutExecutionTests {
    private func binding(
        inputKind: CommandPresentation.InputKind = .none,
        externalID: String = "external-1"
    ) -> ShortcutCommandBinding {
        ShortcutCommandBinding(
            externalID: externalID,
            cachedName: "Daily Note",
            alias: "daily-note",
            inputKind: inputKind
        )
    }

    @Test("A command without input sends no input and reports an empty result")
    func runsWithoutInput() async throws {
        let recorder = RunRecorder()
        let handler = ShortcutCommandHandler(
            binding: binding(),
            client: ShortcutsRunClient(run: { externalID, input in
                await recorder.record(externalID: externalID, input: input)
                return .empty
            }),
            executionGuard: ShortcutExecutionGuard()
        )

        let output = try await handler.perform(
            request: ActionRequest(actionID: handler.descriptor.id, input: "")
        )

        #expect(await recorder.externalID == "external-1")
        #expect(await recorder.input == nil)
        #expect(output.value == ActionOutputValue.none)
    }

    @Test("A command without input refuses text instead of dropping it")
    func rejectsUnexpectedInput() async {
        let handler = ShortcutCommandHandler(
            binding: binding(),
            client: ShortcutsRunClient(run: { _, _ in .empty }),
            executionGuard: ShortcutExecutionGuard()
        )

        await #expect(throws: ToolActionError.unexpectedInput) {
            try await handler.perform(
                request: ActionRequest(actionID: handler.descriptor.id, input: "text")
            )
        }
    }

    @Test("A text command forwards its input and returns the typed result")
    func runsWithInput() async throws {
        let recorder = RunRecorder()
        let handler = ShortcutCommandHandler(
            binding: binding(inputKind: .text),
            client: ShortcutsRunClient(run: { externalID, input in
                await recorder.record(externalID: externalID, input: input)
                return .text("done")
            }),
            executionGuard: ShortcutExecutionGuard()
        )

        let output = try await handler.perform(
            request: ActionRequest(actionID: handler.descriptor.id, input: "Moonlight")
        )

        #expect(await recorder.input == "Moonlight")
        #expect(output.value == .text("done"))
        #expect(output.detail == "done")
    }

    @Test("An unreadable return value is reported, never stringified")
    func reportsUnsupportedOutput() async {
        let handler = ShortcutCommandHandler(
            binding: binding(),
            client: ShortcutsRunClient(run: { _, _ in
                .unsupportedOutput(typeDescription: "NSImage")
            }),
            executionGuard: ShortcutExecutionGuard()
        )

        await #expect(throws: ShortcutsClientError.unsupportedOutput("NSImage")) {
            try await handler.perform(
                request: ActionRequest(actionID: handler.descriptor.id, input: "")
            )
        }
    }

    @Test("The same shortcut is not started twice at once")
    func refusesReentrantRun() async throws {
        let gate = RunGate()
        let handler = ShortcutCommandHandler(
            binding: binding(),
            client: ShortcutsRunClient(run: { _, _ in
                await gate.signalStartAndWait()
                return .empty
            }),
            executionGuard: ShortcutExecutionGuard()
        )
        let request = ActionRequest(actionID: handler.descriptor.id, input: "")

        async let first = handler.perform(request: request)
        await gate.waitUntilStarted()

        await #expect(throws: ShortcutsClientError.alreadyRunning) {
            try await handler.perform(request: request)
        }

        await gate.release()
        _ = try await first
    }

    @Test("A registered shortcut is executable through the shared runner")
    func runsThroughActionRunner() async throws {
        let stored = binding()
        let cache = ShortcutBindingsCache()
        cache.replaceBindings([stored])
        let registry = ActionRegistry(
            handlers: ActionRegistry.standardHandlers,
            resolvers: [
                ShortcutCommandHandlerResolver(
                    cache: cache,
                    client: ShortcutsRunClient(run: { _, _ in .text("done") })
                ),
            ]
        )
        let store = InMemoryExecutionStore()
        let runner = ActionRunner(registry: registry, store: store)

        let execution = try await runner.execute(
            ActionRequest(actionID: stored.commandID, input: "")
        )

        #expect(execution.status == .succeeded)
        #expect(execution.resolvedOutput.value == .text("done"))
        #expect(registry.handler(id: "shortcut:missing") == nil)
    }

    @Test("Without Apple Events a personal command fails with a stated reason")
    func failsWhenRunnerIsUnavailable() async throws {
        let stored = binding()
        let cache = ShortcutBindingsCache()
        cache.replaceBindings([stored])
        let registry = ActionRegistry(
            handlers: ActionRegistry.standardHandlers,
            resolvers: [
                ShortcutCommandHandlerResolver(cache: cache, client: .unavailable()),
            ]
        )
        let runner = ActionRunner(registry: registry, store: InMemoryExecutionStore())

        let execution = try await runner.execute(
            ActionRequest(actionID: stored.commandID, input: "")
        )

        #expect(execution.status == .failed)
        #expect(execution.resolvedFailure?.code == "shortcuts-unavailable")
    }
}

private actor RunRecorder {
    private(set) var externalID: String?
    private(set) var input: String?

    func record(externalID: String, input: String?) {
        self.externalID = externalID
        self.input = input
    }
}

private actor RunGate {
    private var hasStarted = false
    private var isReleased = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func signalStartAndWait() async {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        guard !isReleased else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
