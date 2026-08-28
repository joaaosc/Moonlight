import MoonlightDomain
import SwiftUI

struct ExecutionHistoryView: View {
    let executions: [Execution]
    let isLoading: Bool
    @Binding var selection: Execution.ID?

    var body: some View {
        List(executions, selection: $selection) { execution in
            ExecutionRowView(execution: execution)
                .tag(execution.id)
                .accessibilityIdentifier(
                    execution.id == executions.first?.id
                        ? "latest-execution"
                        : "execution-\(execution.id.uuidString)"
                )
        }
        .listStyle(.sidebar)
        .navigationTitle("History")
        .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 380)
        .overlay {
            if isLoading && executions.isEmpty {
                ProgressView("Loading history")
                    .controlSize(.small)
            } else if executions.isEmpty {
                ContentUnavailableView(
                    "No Executions",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Captured notes will appear here.")
                )
            }
        }
    }
}
