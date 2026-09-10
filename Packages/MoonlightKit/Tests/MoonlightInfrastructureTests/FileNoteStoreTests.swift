import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightInfrastructure

@Suite("Durable notes")
struct FileNoteStoreTests {
    private func makeStore() throws -> (store: FileNoteStore, fileURL: URL, directory: URL) {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightNoteTests")
            .appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "notes-v1.json")
        return (try FileNoteStore(fileURL: fileURL), fileURL, directory)
    }

    @Test("A note survives a new store over the same document")
    func persistsNotes() async throws {
        let (store, fileURL, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.save(MoonlightNote(text: "Buy milk"))
        let reopened = try FileNoteStore(fileURL: fileURL)
        let notes = try await reopened.notes(limit: 10)

        #expect(notes.map(\.text) == ["Buy milk"])
        #expect(notes.first?.title == "Buy milk")
    }

    @Test("Notes live outside the execution history")
    func keepsNotesWhenHistoryIsSeparate() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executionStore = InMemoryExecutionStore()
        let runner = ActionRunner(
            registry: ActionRegistry(
                handlers: [CaptureNoteAction(recorder: store.recorder())]
            ),
            store: executionStore
        )

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.captureNote, input: "Buy milk")
        )
        // Clearing history is modelled here by dropping the execution store.
        let notesAfterHistoryIsGone = try await store.notes(limit: 10)

        #expect(execution.status == .succeeded)
        #expect(notesAfterHistoryIsGone.map(\.text) == ["Buy milk"])
    }

    @Test("Deleting a note removes only that note")
    func deletesOneNote() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = MoonlightNote(text: "Buy milk")
        let second = MoonlightNote(text: "Call Ana")
        try await store.save(first)
        try await store.save(second)

        try await store.delete(id: first.id)

        #expect(try await store.notes(limit: 10).map(\.id) == [second.id])
    }

    @Test("A document from an unsupported version is refused, not discarded")
    func refusesUnsupportedVersion() throws {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightNoteTests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "notes-v1.json")
        try Data(#"{"version":99,"notes":[]}"#.utf8).write(to: fileURL)

        #expect(throws: FileNoteStoreError.unsupportedVersion(99)) {
            _ = try FileNoteStore(fileURL: fileURL)
        }
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
