import Combine
import Foundation
import MoonlightDomain
import SwiftUI

public struct MoonlightRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: MoonlightModel
    @State private var selectedExecutionID: Execution.ID?
    @State private var historyRevision: String?
    @State private var isShowingComposer = false

    private let historyTimer = Timer.publish(
        every: 0.25,
        on: .main,
        in: .common
    ).autoconnect()

    public init(model: MoonlightModel = MoonlightModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationSplitView {
            ExecutionHistoryView(
                executions: model.executions,
                isLoading: model.isLoading,
                selection: $selectedExecutionID
            )
        } detail: {
            Group {
                if let selectedExecution {
                    ExecutionDetailView(execution: selectedExecution)
                        .id(selectedExecution.id)
                } else {
                    ExecutionPlaceholderView(hasExecutions: !model.executions.isEmpty)
                }
            }
            .navigationTitle("Moonlight")
            .navigationSubtitle("Control Panel · Execution History")
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

    private var selectedExecution: Execution? {
        guard let selectedExecutionID else { return nil }
        return model.executions.first { $0.id == selectedExecutionID }
    }

    private func load() async {
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
