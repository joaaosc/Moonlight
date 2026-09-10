import MoonlightDomain
import SwiftUI

public struct ExecutionSnippetView: View {
    private let execution: Execution

    public init(execution: Execution) {
        self.execution = execution
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(execution.summary, systemImage: statusSymbol)
                .font(.title3.bold())
                .foregroundStyle(statusColor)

            Text(execution.actionTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            // The renderer reads the typed value of a stored result. It never
            // runs a command and never branches on the tool identifier.
            switch output.value {
            case .none:
                EmptyView()
            case let .text(value):
                valueText(value, isMonospaced: false)
            case let .json(value), let .identifier(value):
                valueText(value, isMonospaced: true)
            }

            if let failure = execution.resolvedFailure {
                Text(failure.message)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Text(statusText)
                Spacer()
                Text(execution.createdAt, format: .dateTime)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(execution.summary). \(execution.actionTitle). \(execution.detail). \(execution.createdAt.formatted())."
        )
    }

    private var output: ActionOutput {
        execution.resolvedOutput
    }

    private func valueText(_ value: String, isMonospaced: Bool) -> some View {
        Text(value)
            .font(isMonospaced ? .body.monospaced() : .body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var statusText: String {
        switch execution.status {
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        }
    }
}

#if DEBUG
#Preview("Successful execution") {
    ExecutionSnippetView(
        execution: Execution(
            id: UUID(uuidString: "EB66B471-8C6E-47B2-ACCB-E7E46738112D") ?? UUID(),
            actionID: MoonlightActionID.captureNote,
            actionTitle: "Capture Note",
            input: "Review the native Spotlight result.",
            summary: "Note captured",
            detail: "Review the native Spotlight result.",
            status: .succeeded,
            createdAt: Date(timeIntervalSinceReferenceDate: 808_200_000)
        )
    )
    .frame(width: 420)
}
#endif
