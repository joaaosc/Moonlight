import MoonlightDomain
import SwiftUI

/// Creates and removes terminal commands.
public struct TerminalCommandsView: View {
    @State private var model: MoonlightTerminalModel

    public init(model: MoonlightTerminalModel = MoonlightTerminalModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Form {
            Section("Terminal Commands") {
                if model.commands.isEmpty {
                    Text("No terminal command yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.commands) { command in
                        row(command)
                    }
                }
            }

            Section {
                TextField("Name", text: $model.draftTitle)
                TextEditor(text: $model.draftLines)
                    .font(.body.monospaced())
                    .frame(minHeight: 88)
                    .accessibilityLabel("Command lines")
                TextField("Alias (optional)", text: $model.draftAlias)

                Button("Add Terminal Command", systemImage: "plus") {
                    Task { await model.addDraft() }
                }
                .disabled(!model.canAddDraft)

                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("New Terminal Command")
            } footer: {
                Text("One command per line, run top to bottom in Terminal. Use \(TerminalCommand.queryPlaceholder) where the text you type should go.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.load() }
    }

    private func row(_ command: TerminalCommand) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Label(command.title, systemImage: command.symbolName)
                    .font(.body.weight(.medium))
                Text(command.script)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\\\(command.alias)\(command.acceptsQuery ? " · takes text" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove", systemImage: "minus.circle") {
                Task { await model.remove(command) }
            }
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 2)
    }
}
