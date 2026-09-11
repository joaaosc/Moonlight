import Combine
import Foundation
import MoonlightDomain
import SwiftUI

public struct MoonlightRootView: View {
    /// Navigation sections in the Liquid Glass Control Panel.
    public enum Section: String, CaseIterable, Identifiable {
        case intents
        case history
        case notes

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .intents: "Intents"
            case .history: "History"
            case .notes: "Notes"
            }
        }

        public var symbolName: String {
            switch self {
            case .intents: "square.grid.2x2"
            case .history: "clock.arrow.circlepath"
            case .notes: "note.text"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager

    @State private var model: MoonlightModel
    @State private var notesModel: MoonlightNotesModel
    // Optional because that is what a `List` selection binds to; the sidebar
    // always has a row selected in practice.
    @State private var section: Section? = .intents
    @State private var noteSearchText = ""
    @State private var selectedNoteID: MoonlightNote.ID?
    @State private var selectedExecutionID: Execution.ID?
    @State private var historyRevision: String?
    @State private var isShowingComposer = false

    private let historyTimer = Timer.publish(
        every: 0.25,
        on: .main,
        in: .common
    ).autoconnect()

    private let notesFocus: MoonlightNotesFocus?

    public init(
        model: MoonlightModel = MoonlightModel(),
        notesModel: MoonlightNotesModel = MoonlightNotesModel(),
        notesFocus: MoonlightNotesFocus? = nil
    ) {
        _model = State(initialValue: model)
        _notesModel = State(initialValue: notesModel)
        self.notesFocus = notesFocus
    }

    private var visibleNotes: [MoonlightNote] {
        let query = noteSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return notesModel.notes }
        return notesModel.notes.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        // A real split view, so the sidebar gets the system's own Liquid Glass
        // — translucent over the desktop — instead of a hand-built slab. Glass
        // belongs to the navigation layer; the detail side stays content.
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.symbolName)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 260)
        } detail: {
            detailContent
        }
        .frame(minWidth: 820, minHeight: 540)
        .safeAreaInset(edge: .bottom) {
            if !isShowingComposer, let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Note", systemImage: "square.and.pencil") {
                    isShowingComposer = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New note (⌘N)")
            }
            ToolbarItem {
                Button("Refresh History", systemImage: "arrow.clockwise") {
                    Task { await load() }
                }
                .disabled(model.isLoading)
            }
            ToolbarItem {
                SettingsLink()
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            VStack(alignment: .trailing, spacing: 0) {
                CaptureComposerView(model: model, onCapture: capture)
                Button("Close") { isShowingComposer = false }
                    .keyboardShortcut(.cancelAction)
                    .padding([.horizontal, .bottom], 24)
            }
            .frame(minWidth: 480, idealWidth: 560)
        }
        .task {
            await load()
        }
        .onReceive(historyTimer) { _ in
            refreshWhenHistoryChanges()
        }
        .onChange(of: scenePhase) { _, newPhase in
            refreshWhenActive(newPhase)
        }
        .onChange(of: notesFocus?.revision) { _, _ in
            applyNotesFocus()
        }
        .task(id: notesFocus?.revision) {
            applyNotesFocus()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section {
        case .intents:
            MoonlightIntentsGalleryView(
                model: model,
                notesModel: notesModel
            )
        case .history:
            HStack(spacing: 0) {
                ExecutionHistoryView(
                    executions: model.executions,
                    isLoading: model.isLoading,
                    selection: $selectedExecutionID
                )
                .frame(width: 280)

                Divider()

                Group {
                    if let selectedExecution {
                        ExecutionDetailView(execution: selectedExecution)
                            .id(selectedExecution.id)
                    } else {
                        ExecutionPlaceholderView(hasExecutions: !model.executions.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .notes:
            HStack(spacing: 0) {
                NotesListView(
                    notes: visibleNotes,
                    isLoading: notesModel.isLoading,
                    selection: $selectedNoteID
                )
                .searchable(text: $noteSearchText, prompt: "Search notes")
                .frame(width: 280)

                Divider()

                Group {
                    if let selectedNote {
                        NoteDetailView(note: selectedNote) {
                            Task { await deleteSelectedNote(selectedNote) }
                        }
                        .id(selectedNote.id)
                    } else {
                        ContentUnavailableView(
                            "Select a note",
                            systemImage: "note.text",
                            description: Text("Notes are kept separately from execution history.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case nil:
            MoonlightIntentsGalleryView(model: model, notesModel: notesModel)
        }
    }

    private var selectedNote: MoonlightNote? {
        guard let selectedNoteID else { return nil }
        return notesModel.notes.first { $0.id == selectedNoteID }
    }

    private func applyNotesFocus() {
        guard let notesFocus else { return }
        guard !notesFocus.searchText.isEmpty || notesFocus.noteID != nil else { return }

        section = .notes
        noteSearchText = notesFocus.searchText
        if let noteID = notesFocus.noteID {
            selectedNoteID = noteID
        }
    }

    private func deleteSelectedNote(_ note: MoonlightNote) async {
        await notesModel.delete(note, undoManager: undoManager)
        selectedNoteID = notesModel.notes.first?.id
    }

    private var selectedExecution: Execution? {
        guard let selectedExecutionID else { return nil }
        return model.executions.first { $0.id == selectedExecutionID }
    }

    private func load() async {
        await notesModel.load()
        if !notesModel.notes.contains(where: { $0.id == selectedNoteID }) {
            selectedNoteID = notesModel.notes.first?.id
        }
        await model.load()
        historyRevision = model.historyRevision
        if !model.executions.contains(where: { $0.id == selectedExecutionID }) {
            selectedExecutionID = model.executions.first?.id
        }
    }

    private func refreshWhenHistoryChanges() {
        let nextRevision = model.historyRevision
        guard nextRevision != historyRevision, !model.isLoading else { return }
        historyRevision = nextRevision
        Task {
            await load()
        }
    }

    private func refreshWhenActive(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        Task {
            await load()
        }
    }

    private func capture() {
        Task {
            if let execution = await model.capture() {
                selectedExecutionID = execution.id
                isShowingComposer = false
                await notesModel.load()
                selectedNoteID = notesModel.notes.first?.id
            }
        }
    }
}

#if DEBUG
#Preview("Intents Gallery") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 950, height: 650)
}

#Preview("Empty history") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model(executions: []))
        .frame(width: 950, height: 650)
}

#Preview("History") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 950, height: 650)
}

#Preview("Dark, wide") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 1_200, height: 700)
        .environment(\.colorScheme, .dark)
}

#Preview("Minimum size") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 860, height: 560)
}

#Preview("History error") {
    MoonlightRootView(model: MoonlightPreviewFixtures.errorModel)
        .frame(width: 950, height: 650)
}
#endif
