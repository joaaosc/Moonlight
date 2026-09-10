import MoonlightInfrastructure
import SwiftUI

/// Shows where Moonlight's data lives and how much of it there is.
public struct DiagnosticsView: View {
    @State private var diagnostics: MoonlightDiagnostics?
    @State private var isLoading = false

    private let environment: Result<MoonlightEnvironment, MoonlightRuntimeError>

    public init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        self.environment = environment
    }

    public var body: some View {
        Form {
            Section("Storage") {
                if let diagnostics {
                    LabeledContent("App Group", value: diagnostics.appGroupIdentifier)
                    ForEach(diagnostics.documents) { document in
                        documentRow(document)
                    }
                } else {
                    Text(isLoading ? "Reading…" : "No report yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Refresh Report", systemImage: "arrow.clockwise") {
                    Task { await load() }
                }
                .disabled(isLoading)
            } footer: {
                Text("Reading this report never creates, repairs or deletes a document.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await load() }
    }

    private func documentRow(_ document: MoonlightDiagnostics.Document) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    document.name,
                    systemImage: document.exists ? "doc.text" : "doc.badge.gearshape"
                )
                .font(.body.weight(.medium))
                Spacer()
                if let itemCount = document.itemCount {
                    Text("\(itemCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(document.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)

            if let errorMessage = document.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let byteCount = document.byteCount {
                Text(byteCount.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        diagnostics = await MoonlightDiagnostics.current(
            environment: try? environment.get()
        )
    }
}
