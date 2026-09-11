import MoonlightDomain
import SwiftUI

/// What a run produced, plus the two things anyone does with it next.
struct IntentRunnerOutputView: View {
    let text: String
    let status: ExecutionStatus
    let canSaveToNotes: Bool
    let isCopied: Bool
    let isSaved: Bool
    let onCopy: () -> Void
    let onSaveToNotes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(statusTitle, systemImage: statusSymbol)
                    .font(.subheadline)
                    .foregroundStyle(status == .succeeded ? Color.green : Color.red)

                Spacer()

                Button(
                    isCopied ? "Copied" : "Copy",
                    systemImage: isCopied ? "checkmark" : "doc.on.doc",
                    action: onCopy
                )

                if canSaveToNotes {
                    Button(
                        isSaved ? "Saved" : "Save Note",
                        systemImage: isSaved ? "checkmark" : "note.text.badge.plus",
                        action: onSaveToNotes
                    )
                }
            }
            .buttonStyle(.borderless)

            ScrollView {
                Text(text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 80, maxHeight: 200)
            .background(.quinary, in: .rect(cornerRadius: 10))
        }
    }

    private var statusTitle: String {
        status == .succeeded ? "Result" : "Execution failed"
    }

    private var statusSymbol: String {
        status == .succeeded ? "checkmark.circle" : "xmark.circle"
    }
}
