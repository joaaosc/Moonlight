import MoonlightDomain
import SwiftUI

struct ExecutionDetailView: View {
    let execution: Execution

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(execution.summary, systemImage: statusSymbol)
                    .font(.title2.bold())
                    .foregroundStyle(statusColor)

                Text(execution.detail)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                LabeledContent("Action", value: execution.actionTitle)
                LabeledContent("Created") {
                    Text(execution.createdAt, format: .dateTime)
                }
                LabeledContent("Status", value: statusText)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("execution-detail")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusText: String {
        switch execution.status {
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        }
    }

    private var statusSymbol: String {
        switch execution.status {
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch execution.status {
        case .succeeded: .green
        case .failed: .red
        }
    }
}
