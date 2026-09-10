import MoonlightDomain
import SwiftUI

/// Registers shortcuts as Moonlight commands.
///
/// The library is read only when the user asks for it, and adding a shortcut
/// stores a link — it never runs the workflow.
public struct ShortcutBindingsView: View {
    @State private var model: MoonlightShortcutsModel
    @State private var editedAliases: [UUID: String] = [:]

    public init(model: MoonlightShortcutsModel = MoonlightShortcutsModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Form {
            if let message = model.storageMessage {
                messageLabel(message, symbolName: "externaldrive.badge.exclamationmark")
            }

            Section("Commands") {
                if model.bindings.isEmpty {
                    Text("No shortcut is registered as a command yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.bindings) { binding in
                        bindingRow(binding)
                    }
                }
            }

            Section {
                if model.library.isEmpty {
                    Text(model.hasLoadedLibrary
                        ? "Shortcuts reported an empty library."
                        : "Moonlight has not read your Shortcuts library.")
                        .foregroundStyle(.secondary)
                } else if model.unregisteredLibrary.isEmpty {
                    Text("Every shortcut in the library is already registered.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.unregisteredLibrary) { summary in
                        libraryRow(summary)
                    }
                }

                if let message = model.errorMessage {
                    messageLabel(message, symbolName: "exclamationmark.triangle")
                }
            } header: {
                HStack {
                    Text("Shortcuts Library")
                    Spacer()
                    Button("Load Shortcuts", systemImage: "magnifyingglass") {
                        Task { await model.loadLibrary() }
                    }
                    .disabled(model.isLoadingLibrary)
                    if model.isLoadingLibrary {
                        ProgressView().controlSize(.small)
                    }
                }
            } footer: {
                Text("Reading the library asks Shortcuts for permission. Adding a shortcut saves a link and does not run it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.loadBindings() }
    }

    private func bindingRow(_ binding: ShortcutCommandBinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(binding.cachedName, systemImage: binding.symbolName)
                    .font(.body.weight(.medium))
                if model.isUnavailable(binding) {
                    Label("Unavailable", systemImage: "exclamationmark.triangle")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    // The shortcut behind this command is gone. Relinking keeps
                    // the command, its alias and its history.
                    Menu("Relink") {
                        ForEach(model.unregisteredLibrary) { summary in
                            Button(summary.name) {
                                Task { await model.relink(binding, to: summary) }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(model.unregisteredLibrary.isEmpty)
                }
                Spacer()
                Button("Remove", systemImage: "minus.circle") {
                    Task { await model.remove(binding) }
                }
                .labelStyle(.iconOnly)
                .help("Remove this command. The shortcut stays in Shortcuts.")
            }

            HStack(spacing: 12) {
                TextField(
                    "Alias",
                    text: Binding(
                        get: { editedAliases[binding.id] ?? binding.alias },
                        set: { editedAliases[binding.id] = $0 }
                    )
                )
                .frame(maxWidth: 180)
                .onSubmit {
                    let alias = editedAliases[binding.id] ?? binding.alias
                    Task {
                        await model.updateAlias(alias, for: binding)
                        editedAliases[binding.id] = nil
                    }
                }

                Picker("Input", selection: Binding(
                    get: { binding.inputKind },
                    set: { newValue in
                        Task { await model.updateInputKind(newValue, for: binding) }
                    }
                )) {
                    Text("No input").tag(CommandPresentation.InputKind.none)
                    Text("Text").tag(CommandPresentation.InputKind.text)
                }
                .frame(maxWidth: 200)
            }

            if !binding.cachedSubtitle.isEmpty {
                Text(binding.cachedSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func libraryRow(_ summary: ShortcutSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                // Two shortcuts can share a name; the subtitle and the action
                // count are what keep the rows distinguishable.
                Text(summary.subtitle.isEmpty
                    ? "\(summary.actionCount) actions"
                    : summary.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if summary.acceptsInput {
                Text("Accepts input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Add", systemImage: "plus") {
                Task { await model.add(summary) }
            }
            .labelStyle(.iconOnly)
            .help("Register ‘\(summary.name)’ as a Moonlight command")
        }
    }

    private func messageLabel(_ message: String, symbolName: String) -> some View {
        Label(message, systemImage: symbolName)
            .font(.callout)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Shortcut commands") {
    ShortcutBindingsView(
        model: MoonlightShortcutsModel(
            shortcuts: .stub([
                ShortcutSummary(
                    externalID: "A",
                    name: "Daily Note",
                    subtitle: "Notes",
                    acceptsInput: true,
                    actionCount: 4
                ),
                ShortcutSummary(externalID: "B", name: "Daily Note", actionCount: 2),
            ]),
            store: nil,
            cache: ShortcutBindingsCache()
        )
    )
    .frame(width: 560, height: 460)
}
#endif
