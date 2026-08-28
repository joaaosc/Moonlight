import MoonlightDomain
import SwiftUI

struct ExecutionRowView: View {
    let execution: Execution

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(previewText)
                    .font(.body)
                    .lineLimit(2)

                Text(execution.actionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(execution.createdAt, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(execution.summary). \(previewText). \(execution.actionTitle). \(execution.createdAt.formatted())."
        )
    }

    private var previewText: String {
        let compact = ExecutionTextFormatter.preview(execution.detail)
        return compact.isEmpty ? execution.summary : compact
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
