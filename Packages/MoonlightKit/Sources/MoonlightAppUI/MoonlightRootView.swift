import Foundation
import MoonlightDomain
import SwiftUI

public struct MoonlightRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: MoonlightModel
    @State private var selectedExecutionID: Execution.ID?

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
            VStack(spacing: 0) {
                CaptureComposerView(model: model, onCapture: capture)

                Divider()

                if let selectedExecution {
                    ExecutionDetailView(execution: selectedExecution)
                        .id(selectedExecution.id)
                } else {
                    ExecutionPlaceholderView(hasExecutions: !model.executions.isEmpty)
                }
            }
            .navigationTitle("Moonlight")
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 480)
        .task {
            await load()
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
        if !model.executions.contains(where: { $0.id == selectedExecutionID }) {
            selectedExecutionID = model.executions.first?.id
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
