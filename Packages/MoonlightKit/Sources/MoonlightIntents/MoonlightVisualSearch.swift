import AppIntents
import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import VisualIntelligence

/// Answers visual search with notes whose text matches what the system saw.
///
/// Moonlight performs no vision of its own: it uses the labels the system
/// provides and nothing else. When there are no labels, or nothing matches, the
/// result is empty — never a plausible-looking guess.
struct MoonlightNoteVisualQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [MoonlightNoteEntity] {
        let labels = input.labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !labels.isEmpty else { return [] }

        let environment = try MoonlightProcess.requireEnvironment()
        guard let store = environment.noteStore else { return [] }

        let notes = try await store.notes(limit: 500)
        let matches = notes.filter { note in
            labels.contains { note.text.localizedCaseInsensitiveContains($0) }
        }

        // A short list keeps the search view fast; the full list is one tap
        // away through the semantic content search intent below.
        return matches.prefix(20).map(MoonlightNoteEntity.init(note:))
    }
}

/// Opens a note found by visual search.
public struct OpenMoonlightNoteIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Moonlight Note"
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Note", requestValueDialog: "Which note?")
    public var target: MoonlightNoteEntity

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public init() {}

    public init(target: MoonlightNoteEntity) {
        self.target = target
    }

    public func perform() async throws -> some IntentResult {
        await foregroundClient.presentNotes(noteID: target.id)
        return .result()
    }
}

/// Shows the full list of notes matching a visual search inside Moonlight.
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct SearchMoonlightNotesIntent {
    var semanticContent: SemanticContentDescriptor

    @Dependency private var foregroundClient: MoonlightForegroundClient

    func perform() async throws -> some IntentResult {
        let searchText = semanticContent.labels
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        await foregroundClient.presentNotes(searchText: searchText)
        return .result()
    }
}
