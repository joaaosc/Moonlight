import MoonlightDomain
import SwiftUI

/// Creates and removes quicklinks.
public struct QuicklinksView: View {
    @State private var model: MoonlightQuicklinksModel

    public init(model: MoonlightQuicklinksModel = MoonlightQuicklinksModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Form {
            Section("Quicklinks") {
                if model.quicklinks.isEmpty {
                    Text("No quicklink yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.quicklinks) { quicklink in
                        row(quicklink)
                    }
                }
            }

            Section {
                TextField("Name", text: $model.draftTitle)
                TextField("Address", text: $model.draftURLTemplate)
                    .font(.body.monospaced())
                TextField("Alias (optional)", text: $model.draftAlias)

                Button("Add Quicklink", systemImage: "plus") {
                    Task { await model.addDraft() }
                }
                .disabled(!model.canAddDraft)

                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("New Quicklink")
            } footer: {
                Text("Use \(QuicklinkCommand.queryPlaceholder) where the text you type should go, for example https://example.com/search?q=\(QuicklinkCommand.queryPlaceholder). Without it the link takes no input.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.load() }
    }

    private func row(_ quicklink: QuicklinkCommand) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Label(quicklink.title, systemImage: quicklink.symbolName)
                    .font(.body.weight(.medium))
                Text(quicklink.urlTemplate)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\\\(quicklink.alias)\(quicklink.acceptsQuery ? " · takes text" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove", systemImage: "minus.circle") {
                Task { await model.remove(quicklink) }
            }
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 2)
    }
}
