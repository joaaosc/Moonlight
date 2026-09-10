import MoonlightDomain
import MoonlightInfrastructure
import SwiftUI

/// Shows where Moonlight's data lives and how much of it there is.
public struct DiagnosticsView: View {
    @State private var diagnostics: MoonlightDiagnostics?
    @State private var capabilities: [MoonlightCapability] = []
    @State private var isLoading = false

    private let environment: Result<MoonlightEnvironment, MoonlightRuntimeError>

    public init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        self.environment = environment
    }

    public var body: some View {
        Form {
            Section("Installation") {
                if let installation = diagnostics?.installation {
                    LabeledContent(
                        "Version",
                        value: "\(installation.version) (\(installation.build))"
                    )
                    Text(installation.bundlePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if !installation.isCanonical {
                        Label(
                            "Running outside \(MoonlightDiagnostics.Installation.canonicalDirectory). System features registered from here stop working if this copy moves.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }

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

            Section("Optional capabilities") {
                ForEach(capabilities) { capability in
                    VStack(alignment: .leading, spacing: 2) {
                        LabeledContent(capability.name, value: capability.status.summary)
                        Text(capability.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                Button("Refresh Report", systemImage: "arrow.clockwise") {
                    Task { await load() }
                }
                .disabled(isLoading)
            } footer: {
                Text("Reading this report never creates, repairs or deletes a document, and never asks for a permission.")
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

        let resolvedEnvironment = try? environment.get()
        diagnostics = await MoonlightDiagnostics.current(environment: resolvedEnvironment)

        // `false` keeps the query silent: no consent prompt from a report.
        let automation = await resolvedEnvironment?.shortcuts.authorizationStatus(false)
        capabilities = [
            .appleEvents(status: automation ?? .unavailable),
            .accessibility(),
        ]
    }
}
