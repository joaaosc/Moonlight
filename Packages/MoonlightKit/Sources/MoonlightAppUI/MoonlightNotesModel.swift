import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

/// Reads and edits the durable notes.
///
/// Notes are loaded from their own store, so clearing execution history has no
/// effect here.
@MainActor
@Observable
public final class MoonlightNotesModel {
    public private(set) var notes: [MoonlightNote] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let store: (any NoteStore)?

    public init(store: (any NoteStore)?) {
        self.store = store
        if store == nil {
            errorMessage = "Moonlight cannot reach its shared container, so notes are unavailable."
        }
    }

    public convenience init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        switch environment {
        case let .success(environment):
            self.init(store: environment.noteStore)
        case let .failure(error):
            self.init(store: nil)
            errorMessage = error.localizedDescription
        }
    }

    public func load(limit: Int = 200) async {
        guard let store else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            notes = try await store.notes(limit: limit)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func delete(_ note: MoonlightNote) async {
        guard let store else { return }
        do {
            try await store.delete(id: note.id)
            notes.removeAll { $0.id == note.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
