import Combine
import Foundation
import MoonlightDomain
import SwiftUI

public struct MoonlightRootView: View {
    /// The two things the control panel shows. Executions are a log that can be
    /// cleared; notes are content the user keeps.
    private enum Section: String, CaseIterable, Identifiable {
        case history
        case notes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .history: "History"
            case .notes: "Notes"
            }
        }

        var symbolName: String {
            switch self {
            case .history: "clock"
            case .notes: "note.text"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    @State private var model: MoonlightModel
    @State private var notesModel: MoonlightNotesModel
    @State private var section: Section = .history
    @State private var selectedNoteID: MoonlightNote.ID?
    @State private var selectedExecutionID: Execution.ID?
    @State private var historyRevision: String?
    @State private var isShowingComposer = false

    private let historyTimer = Timer.publish(
        every: 0.25,
        on: .main,
        in: .common
    ).autoconnect()

    public init(
        model: MoonlightModel = MoonlightModel(),
        notesModel: MoonlightNotesModel = MoonlightNotesModel()
    ) {
        _model = State(initialValue: model)
        _notesModel = State(initialValue: notesModel)
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { section in
                        Label(section.title, systemImage: section.symbolName)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding([.horizontal, .top], 8)

                switch section {
                case .history:
                    ExecutionHistoryView(
                        executions: model.executions,
                        isLoading: model.isLoading,
                        selection: $selectedExecutionID
                    )
                case .notes:
                    NotesListView(
                        notes: notesModel.notes,
                        isLoading: notesModel.isLoading,
                        selection: $selectedNoteID
                    )
                }
            }
        } detail: {
            Group {
                switch section {
                case .history:
                    if let selectedExecution {
                        ExecutionDetailView(execution: selectedExecution)
                            .id(selectedExecution.id)
                    } else {
                        ExecutionPlaceholderView(hasExecutions: !model.executions.isEmpty)
                    }
                case .notes:
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
            }
            .navigationTitle("Moonlight")
            .navigationSubtitle(
                section == .history
                    ? "Control Panel · Execution History"
                    : "Control Panel · Notes"
            )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 480)
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
    }

    private var selectedNote: MoonlightNote? {
        guard let selectedNoteID else { return nil }
        return notesModel.notes.first { $0.id == selectedNoteID }
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
                // The capture also wrote a durable note; show it right away.
                await notesModel.load()
                selectedNoteID = notesModel.notes.first?.id
            }
        }
    }
}

#if DEBUG
#Preview("Empty history") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model(executions: []))
        .frame(width: 900, height: 600)
}

#Preview("History") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 900, height: 600)
}

#Preview("Dark, wide") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 1_200, height: 700)
        .environment(\.colorScheme, .dark)
}

#Preview("Minimum size") {
    MoonlightRootView(model: MoonlightPreviewFixtures.model())
        .frame(width: 760, height: 480)
}

#Preview("History error") {
    MoonlightRootView(model: MoonlightPreviewFixtures.errorModel)
        .frame(width: 900, height: 600)
}
#endif
