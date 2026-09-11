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
            case .intents: "sparkles.rectangle.stack.fill"
            case .history: "clock.arrow.circlepath"
            case .notes: "note.text"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var model: MoonlightModel
    @State private var notesModel: MoonlightNotesModel
    @State private var section: Section = .intents
    @State private var isSidebarVisible = true
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
        ZStack {
            // Atmospheric Scenic Backdrop (Mount Fuji, sakura blossoms, and dawn sky)
            MoonlightAtmosphericBackground()
                .ignoresSafeArea()

            // Main Content Layout
            HStack(spacing: 16) {
                // Floating Liquid Glass Sidebar
                if isSidebarVisible {
                    MoonlightGlassSidebar(
                        selection: $section,
                        items: [
                            MoonlightGlassSidebar.Item(
                                id: .intents,
                                title: "Intents",
                                symbolName: "sparkles.rectangle.stack.fill"
                            ),
                            MoonlightGlassSidebar.Item(
                                id: .history,
                                title: "History",
                                symbolName: "clock.arrow.circlepath",
                                badgeCount: model.executions.count
                            ),
                            MoonlightGlassSidebar.Item(
                                id: .notes,
                                title: "Notes",
                                symbolName: "note.text",
                                badgeCount: notesModel.notes.count
                            )
                        ]
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isSidebarVisible.toggle()
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Detail Area
                VStack(spacing: 0) {
                    if !isSidebarVisible {
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    isSidebarVisible = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sidebar.left")
                                    Text("Show Sidebar")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .padding(.leading, 16)

                            Spacer()
                        }
                    }

                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
        }
        .frame(minWidth: 860, minHeight: 560)
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
            glassSplitContent {
                HStack(spacing: 0) {
                    ExecutionHistoryView(
                        executions: model.executions,
                        isLoading: model.isLoading,
                        selection: $selectedExecutionID
                    )
                    .frame(width: 320)

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
            }
        case .notes:
            glassSplitContent {
                HStack(spacing: 0) {
                    NotesListView(
                        notes: visibleNotes,
                        isLoading: notesModel.isLoading,
                        selection: $selectedNoteID
                    )
                    .searchable(text: $noteSearchText, prompt: "Search notes")
                    .frame(width: 320)

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
            }
        }
    }

    private func glassSplitContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RadialGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 400
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.40 : 0.65),
                                .white.opacity(colorScheme == .dark ? 0.10 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 16, y: 6)
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
