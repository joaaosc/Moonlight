import AppIntents
import Foundation
import GeoToolbox
import MoonlightDomain
import MoonlightInfrastructure

/// Creates a durable note using the system's journal schema.
///
/// The note goes to Moonlight's own note store, so it outlives the execution
/// history exactly like a note captured from the palette.
@AppIntent(schema: .journal.createEntry)
struct CreateMoonlightNoteIntent {
    var message: AttributedString
    var title: String?
    var location: PlaceDescriptor?
    var mediaItems: [IntentFile]
    var entryDate: Date?

    func perform() async throws -> some ReturnsValue<MoonlightNoteEntity> {
        let text = String(message.characters)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExecutionIntentError.executionFailed("Enter text before saving a note.")
        }

        let environment = try MoonlightProcess.requireEnvironment()
        guard let store = environment.noteStore else {
            throw ExecutionIntentError.executionFailed(
                "Moonlight cannot reach its shared container, so notes are unavailable."
            )
        }

        // Media and location are part of the schema but not of a Moonlight
        // note; dropping them is stated here rather than silently ignored.
        let composed = title.map { "\($0)\n\(trimmed)" } ?? trimmed
        let note = MoonlightNote(text: composed, createdAt: entryDate ?? Date())
        try await store.save(note)

        return .result(value: MoonlightNoteEntity(note: note))
    }
}

/// Deletes notes through the same schema Shortcuts uses for journal entries.
@AppIntent(schema: .journal.deleteEntry)
struct DeleteMoonlightNotesIntent {
    var entities: [MoonlightNoteEntity]

    func perform() async throws -> some IntentResult {
        let environment = try MoonlightProcess.requireEnvironment()
        guard let store = environment.noteStore else {
            throw ExecutionIntentError.executionFailed(
                "Moonlight cannot reach its shared container, so notes are unavailable."
            )
        }

        for entity in entities {
            try await store.delete(id: entity.id)
        }
        return .result()
    }
}
