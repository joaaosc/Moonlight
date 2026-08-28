import Foundation
import MoonlightDomain
import Testing

@Suite("Action runner")
struct ActionRunnerTests {
    private let instant = Date(timeIntervalSince1970: 1_800_000_000)
    private let identifier = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    @Test("Captures normalized Unicode with injected identity and time")
    func capturesUnicode() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: "  Cafe\u{301} ☾  \n")
        )

        #expect(execution.id == identifier)
        #expect(execution.createdAt == instant)
        #expect(execution.status == .succeeded)
        #expect(execution.detail == "Café ☾")
        #expect(await store.execution(id: identifier) == execution)
    }

    @Test("Accepts exactly ten thousand characters")
    func acceptsMaximumLength() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)
        let input = String(repeating: "a", count: CaptureNoteAction.maximumCharacterCount)

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: input)
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail.count == CaptureNoteAction.maximumCharacterCount)
    }

    @Test("Persists over-limit input as a failed execution")
    func rejectsOverLimit() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)
        let input = String(repeating: "a", count: CaptureNoteAction.maximumCharacterCount + 1)

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: input)
        )

        #expect(execution.status == .failed)
        #expect(execution.detail.contains("10000"))
        #expect(await store.execution(id: identifier) == execution)
    }

    @Test("Persists blank input as a failed execution")
    func rejectsBlankInput() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: " \n\t ")
        )

        #expect(execution.status == .failed)
        #expect(execution.detail == ActionError.emptyInput.localizedDescription)
        #expect(await store.execution(id: identifier) == execution)
    }

    @Test("Persists an unknown action as a failed execution")
    func rejectsUnknownAction() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)

        let execution = try await runner.execute(
            ActionRequest(actionID: "missing-action", input: "value")
        )

        #expect(execution.status == .failed)
        #expect(execution.actionID == "missing-action")
        #expect(await store.execution(id: identifier) == execution)
    }

    @Test("Propagates storage failures")
    func propagatesStorageFailure() async {
        let store = FirstWriteFailsExecutionStore()
        let runner = makeRunner(store: store)

        await #expect(throws: StoreFailure.writeFailed) {
            try await runner.execute(
                ActionRequest(actionID: MoonlightActionID.captureNote, input: "value")
            )
        }
        #expect(await store.attemptCount == 1)
    }

    private func makeRunner(store: any ExecutionStore) -> ActionRunner {
        ActionRunner(
            registry: .standard,
            store: store,
            clock: { instant },
            identifierGenerator: { identifier }
        )
    }
}

private enum StoreFailure: Error {
    case writeFailed
}

private actor FirstWriteFailsExecutionStore: ExecutionStore {
    private(set) var attemptCount = 0

    func upsert(_ execution: Execution) throws {
        attemptCount += 1
        if attemptCount == 1 {
            throw StoreFailure.writeFailed
        }
    }

    func execution(id: UUID) -> Execution? { nil }
    func recent(limit: Int) -> [Execution] { [] }
}
