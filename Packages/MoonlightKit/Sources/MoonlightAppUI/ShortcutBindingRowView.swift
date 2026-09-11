import MoonlightDomain
import SwiftUI

/// One registered shortcut command, with the three things about it that are
/// editable in place.
///
/// The editable values are local state rather than bindings written straight
/// back into the model: every write is an async persist, and a setter that
/// starts a task is not something a `Binding` can express honestly.
struct ShortcutBindingRowView: View {
    let binding: ShortcutCommandBinding
    let model: MoonlightShortcutsModel

    @State private var alias: String
    @State private var isSpotlightExposed: Bool
    @State private var inputKind: CommandPresentation.InputKind

    init(binding: ShortcutCommandBinding, model: MoonlightShortcutsModel) {
        self.binding = binding
        self.model = model
        _alias = State(initialValue: binding.alias)
        _isSpotlightExposed = State(initialValue: binding.isSpotlightExposed)
        _inputKind = State(initialValue: binding.inputKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(binding.cachedName, systemImage: binding.symbolName)
                    .font(.body.weight(.medium))

                if model.isUnavailable(binding) {
                    Label("Unavailable", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    // The shortcut behind this command is gone. Relinking keeps
                    // the command, its alias and its history.
                    Menu("Relink") {
                        ForEach(model.unregisteredLibrary) { summary in
                            Button(summary.name) {
                                relink(to: summary)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(model.unregisteredLibrary.isEmpty)
                }

                Spacer()

                Button("Remove", systemImage: "minus.circle", action: remove)
                    .labelStyle(.iconOnly)
                    .help("Remove this command. The shortcut stays in Shortcuts.")
            }

            HStack(spacing: 12) {
                TextField("Alias", text: $alias)
                    .frame(maxWidth: 180)
                    .onSubmit(submitAlias)

                Toggle("Show in Spotlight", isOn: $isSpotlightExposed)
                    .toggleStyle(.checkbox)
                    .help("Shortcuts already indexes your library; publish only what you want in Spotlight.")

                Picker("Input", selection: $inputKind) {
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
        // Both directions are guarded against the stored value: without the
        // guard, re-seeding from a reload would immediately persist it again.
        .onChange(of: isSpotlightExposed) { _, newValue in
            guard newValue != binding.isSpotlightExposed else { return }
            Task { await model.setSpotlightExposure(newValue, for: binding) }
        }
        .onChange(of: inputKind) { _, newValue in
            guard newValue != binding.inputKind else { return }
            Task { await model.updateInputKind(newValue, for: binding) }
        }
        .onChange(of: binding) { _, newValue in
            alias = newValue.alias
            isSpotlightExposed = newValue.isSpotlightExposed
            inputKind = newValue.inputKind
        }
    }

    private func submitAlias() {
        Task { await model.updateAlias(alias, for: binding) }
    }

    private func relink(to summary: ShortcutSummary) {
        Task { await model.relink(binding, to: summary) }
    }

    private func remove() {
        Task { await model.remove(binding) }
    }
}
