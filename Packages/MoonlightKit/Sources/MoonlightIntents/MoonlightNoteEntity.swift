import AppIntents
import Foundation
import GeoToolbox
import MoonlightDomain
import MoonlightInfrastructure

/// A Moonlight note described with the system's journal entry schema.
///
/// Adopting the schema lets Shortcuts work with notes as structured content
/// instead of loose text. It describes what a note already is; no field is
/// invented to satisfy the shape.
@AppEntity(schema: .journal.entry)
public struct MoonlightNoteEntity {
    public static let defaultQuery = MoonlightNoteEntityQuery()

    public let id: UUID

    public var title: String?
    public var message: AttributedString?
    public var mediaItems: [IntentFile]
    public var entryDate: Date?
    /// Moonlight notes carry no location. The schema asks for the property;
    /// leaving it empty is honest, inventing a place would not be.
    public var location: PlaceDescriptor?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title ?? "Untitled note")",
            subtitle: entryDate.map { "\($0.formatted(date: .abbreviated, time: .shortened))" }
        )
    }

    public init(note: MoonlightNote) {
        id = note.id
        title = note.title.isEmpty ? nil : note.title
        message = AttributedString(note.text)
        mediaItems = []
        entryDate = note.createdAt
        location = nil
    }

    public struct MoonlightNoteEntityQuery: EntityStringQuery {
        public init() {}

        public func entities(for identifiers: [MoonlightNoteEntity.ID]) async throws -> [MoonlightNoteEntity] {
            let wanted = Set(identifiers)
            return try await notes().filter { wanted.contains($0.id) }.map(MoonlightNoteEntity.init(note:))
        }

        public func entities(matching string: String) async throws -> [MoonlightNoteEntity] {
            let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = try await notes()
            guard !query.isEmpty else { return notes.map(MoonlightNoteEntity.init(note:)) }
            return notes
                .filter { $0.text.localizedStandardContains(query) }
                .map(MoonlightNoteEntity.init(note:))
        }

        public func suggestedEntities() async throws -> [MoonlightNoteEntity] {
            try await notes().prefix(10).map(MoonlightNoteEntity.init(note:))
        }

        private func notes(limit: Int = 200) async throws -> [MoonlightNote] {
            let environment = try MoonlightProcess.requireEnvironment()
            guard let store = environment.noteStore else { return [] }
            return try await store.notes(limit: limit)
        }
    }
}
