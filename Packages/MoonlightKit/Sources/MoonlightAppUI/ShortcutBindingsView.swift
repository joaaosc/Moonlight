import MoonlightDomain
import SwiftUI

/// Registers shortcuts as Moonlight commands.
///
/// The library is read only when the user asks for it, and adding a shortcut
/// stores a link — it never runs the workflow.
public struct ShortcutBindingsView: View {
    @State private var model: MoonlightShortcutsModel

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
                        ShortcutBindingRowView(binding: binding, model: model)
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
