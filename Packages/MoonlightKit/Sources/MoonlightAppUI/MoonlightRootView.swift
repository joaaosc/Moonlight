import Foundation
import MoonlightDomain
import SwiftUI

public struct MoonlightRootView: View {
    @State private var model: MoonlightModel
    @State private var selectedExecutionID: Execution.ID?

    public init(model: MoonlightModel = MoonlightModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationSplitView {
            ExecutionHistoryView(
                executions: model.executions,
                selection: $selectedExecutionID
            )
        } detail: {
            VStack(spacing: 0) {
                CaptureComposerView(model: model, onCapture: capture)

                Divider()

                if let selectedExecution {
                    ExecutionDetailView(execution: selectedExecution)
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
    }

    private var selectedExecution: Execution? {
        guard let selectedExecutionID else { return nil }
        return model.executions.first { $0.id == selectedExecutionID }
    }

    private func load() async {
        await model.load()
        if selectedExecutionID == nil {
            selectedExecutionID = model.executions.first?.id
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
