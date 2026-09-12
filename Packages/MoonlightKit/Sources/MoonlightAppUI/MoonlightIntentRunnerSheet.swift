import AppKit
import MoonlightDomain
import SwiftUI

/// Configures, runs and shows the result of a single intent.
///
/// Content-layer chrome only: system materials, system typography and standard
/// controls. The gallery already said which tool this is with an accent and a
/// symbol, so the sheet repeats neither as a gradient nor as a coloured slab.
public struct MoonlightIntentRunnerSheet: View {
    public let item: MoonlightIntentItem
    @Bindable public var model: MoonlightModel
    public var notesModel: MoonlightNotesModel?
    public let onDismiss: () -> Void

    @State private var inputText: String
    @State private var selectedParameterValue: String
    @State private var outputText: String?
    @State private var outputStatus: ExecutionStatus?
    @State private var isRunning = false
    @State private var isCopied = false
    @State private var isSavedToNotes = false
    @State private var errorMessage: String?

    public init(
        item: MoonlightIntentItem,
        model: MoonlightModel,
        notesModel: MoonlightNotesModel? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.model = model
        self.notesModel = notesModel
        self.onDismiss = onDismiss
        _selectedParameterValue = State(initialValue: item.defaultParameterValue ?? "")
        _inputText = State(initialValue: item.sampleInput)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(20)

            Divider()

            // No scroll view here on purpose: the input is line-limited and the
            // result area caps its own height, so the sheet can size itself to
            // the tool instead of reserving a fixed rectangle every tool has to
            // fill.
            if hasConfigurableBody {
                VStack(alignment: .leading, spacing: 16) {
                    if let parameterKey = item.parameterKey, !item.parameterOptions.isEmpty {
                        Picker(parameterKey.capitalized, selection: $selectedParameterValue) {
                            ForEach(item.parameterOptions, id: \.value) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }

                    if item.requiresInput {
                        inputSection
                    }

                    // The timer is the one tool whose result is a behaviour,
                    // not a string: the countdown lives here, next to the
                    // duration it parses, while Run records the start below.
                    if item.id == MoonlightActionID.startTimer {
                        timerSection
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let outputText, let outputStatus {
                        IntentRunnerOutputView(
                            text: outputText,
                            status: outputStatus,
                            canSaveToNotes: notesModel != nil,
                            isCopied: isCopied,
                            isSaved: isSavedToNotes,
                            onCopy: copyOutput,
                            onSaveToNotes: saveToNotes
                        )
                    }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            }

            // The primary action sits at the trailing edge of a bottom bar, the
            // place macOS puts it in every sheet the system draws itself.
            HStack {
                Spacer()
                Button("Close", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Button("Run", systemImage: "play.fill", action: run)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRunning || !hasRunnableInput)
            }
            .padding(20)
        }
        .frame(minWidth: 460, idealWidth: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.title2)
                .foregroundStyle(item.accentColor)
                .frame(width: 40, height: 40)
                .background(item.accentColor.opacity(0.12), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isRunning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Running \(item.title)")
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Input")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Paste", action: pasteInput)
                if !item.sampleInput.isEmpty {
                    Button("Sample", action: useSampleInput)
                }
                if !inputText.isEmpty {
                    Button("Clear", action: clearInput)
                }
            }
            .buttonStyle(.borderless)
            .font(.subheadline)

            TextField("Enter text", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .lineLimit(5...12)
                .padding(10)
                .background(.quinary, in: .rect(cornerRadius: 10))
                .accessibilityLabel("Input for \(item.title)")
        }
    }

    /// Whether there is anything between the header and the action bar. A tool
    /// that takes no input and has not run yet has nothing to show, and an empty
    /// padded strip between two dividers is worse than no strip at all.
    private var hasConfigurableBody: Bool {
        item.requiresInput
            || item.parameterKey != nil
            || outputText != nil
            || errorMessage != nil
    }

    private var hasRunnableInput: Bool {
        guard item.requiresInput else { return true }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pasteInput() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        inputText = string
    }

    private func useSampleInput() {
        inputText = item.sampleInput
    }

    private var timerSection: some View {
        Group {
            if let seconds = try? StartTimerAction.parseDuration(inputText) {
                MinimalTimerView(totalSeconds: seconds, accent: item.accentColor) {
                    Task { await recordTimerStart() }
                }
            } else {
                Text("Enter a duration like 25m, 90s or 1:30.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    /// Records a timer start kicked off from the countdown itself, so it
    /// lands in history exactly like a Run press. A failed record surfaces as
    /// the sheet's error; a resumed countdown records nothing.
    private func recordTimerStart() async {
        let execution = await model.execute(
            actionID: MoonlightActionID.startTimer,
            input: inputText
        )
        if let execution {
            outputStatus = execution.status
            if execution.status == .succeeded {
                outputText = execution.detail
            } else {
                errorMessage = execution.detail
                outputText = nil
            }
        } else if let modelError = model.errorMessage {
            errorMessage = modelError
            outputStatus = .failed
        }
    }

    private func clearInput() {
        inputText = ""
    }

    private func run() {
        Task { await runIntent() }
    }

    private func runIntent() async {
        isRunning = true
        errorMessage = nil
        isCopied = false
        isSavedToNotes = false
        defer { isRunning = false }

        // Cartões sem ActionRegistry próprio: não passam por model.execute,
        // que registraria um `unknownAction` no histórico.
        if item.id == MoonlightIntentCatalog.openMoonlightID {
            outputText = "You are already in Moonlight's main window. Press ⌘⇧M for the floating palette or ⌘⇧L for the launcher."
            outputStatus = .succeeded
            return
        }
        if item.id == MoonlightIntentCatalog.runUserShortcutID {
            errorMessage = "Pick a registered shortcut in Settings → Shortcuts, then run it from Spotlight (Run Moonlight Command) or the Shortcuts app. This card cannot choose a shortcut by itself."
            outputText = nil
            outputStatus = .failed
            return
        }
        if item.id == MoonlightIntentCatalog.runCommandID {
            await runSlashCommandCard()
            return
        }

        // The colour picker is a panel, not a command: it has no runtime result
        // to record, so it never goes through the execution path.
        if item.id == MoonlightActionID.openColorPicker {
            MoonlightColorPanelPresenter.shared.present(isolatingFromMainWindow: false)
            outputText = "System Color Picker opened."
            outputStatus = .succeeded
            return
        }

        var parameters = ActionParameters.empty
        if let key = item.parameterKey, !selectedParameterValue.isEmpty {
            parameters = ActionParameters(values: [key: selectedParameterValue])
        }

        let execution = await model.execute(
            actionID: item.id,
            input: item.requiresInput ? inputText : "",
            parameters: parameters
        )

        if let execution {
            outputStatus = execution.status
            if execution.status == .succeeded {
                outputText = execution.detail
            } else {
                errorMessage = execution.detail
                outputText = nil
            }
        } else if let modelError = model.errorMessage {
            errorMessage = modelError
            outputStatus = .failed
        }
    }

    private func copyOutput() {
        guard let outputText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        Task { await confirm { isCopied = $0 } }
    }

    /// Resolve `inputText` (ex. `/note Buy milk`) contra os aliases nativos e
    /// executa o actionID real. Nome desconhecido vira mensagem, nunca um
    /// `unknownAction` gravado no histórico.
    private func runSlashCommandCard() async {
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases: [String: String] = [
            "note": MoonlightActionID.captureNote,
            "clean": MoonlightActionID.cleanText,
            "json": MoonlightActionID.formatJSON,
            "uuid": MoonlightActionID.generateUUID,
            "base64": MoonlightActionID.base64Text,
            "hash": MoonlightActionID.hashText,
            "url": MoonlightActionID.urlText,
            "date": MoonlightActionID.convertTimestamp,
            "summarize": MoonlightActionID.summarizeText,
            "timer": MoonlightActionID.startTimer,
            "color": MoonlightActionID.openColorPicker,
        ]
        do {
            let command = try SlashCommandParser().parse(raw.isEmpty ? item.sampleInput : raw)
            guard let actionID = aliases[command.name] else {
                errorMessage = "Moonlight has no /\(command.name) command yet."
                outputText = nil
                outputStatus = .failed
                return
            }
            if actionID == MoonlightActionID.openColorPicker {
                MoonlightColorPanelPresenter.shared.present(isolatingFromMainWindow: false)
                outputText = "System Color Picker opened."
                outputStatus = .succeeded
                return
            }
            var parameters = ActionParameters.empty
            if let key = item.parameterKey, !selectedParameterValue.isEmpty {
                parameters = ActionParameters(values: [key: selectedParameterValue])
            }
            // `color` não tem parâmetro; base64/hash/url reutilizam o Picker
            // do cartão quando a chave coincide, senão usam o default do domínio.
            let execution = await model.execute(
                actionID: actionID,
                input: command.arguments,
                parameters: parameters.values.isEmpty ? .empty : parameters
            )
            if let execution {
                outputStatus = execution.status
                if execution.status == .succeeded {
                    outputText = execution.detail
                } else {
                    errorMessage = execution.detail
                    outputText = nil
                }
            } else if let modelError = model.errorMessage {
                errorMessage = modelError
                outputStatus = .failed
            }
        } catch {
            errorMessage = error.localizedDescription
            outputText = nil
            outputStatus = .failed
        }
    }

    private func saveToNotes() {
        guard let outputText else { return }
        Task {
            model.text = outputText
            _ = await model.capture()
            await notesModel?.load()
            await confirm { isSavedToNotes = $0 }
        }
    }

    /// Flips a confirmation flag on, then back off, so a button can say what it
    /// just did without leaving a permanent "Copied" label behind.
    private func confirm(_ apply: @MainActor (Bool) -> Void) async {
        withAnimation { apply(true) }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { apply(false) }
    }
}

#if DEBUG
#Preview("With options") {
    MoonlightIntentRunnerSheet(
        item: MoonlightIntentCatalog.allIntents.first { $0.parameterKey != nil }
            ?? MoonlightIntentCatalog.allIntents[0],
        model: MoonlightPreviewFixtures.model(),
        onDismiss: {}
    )
}

#Preview("Without input") {
    MoonlightIntentRunnerSheet(
        item: MoonlightIntentCatalog.allIntents.first { !$0.requiresInput }
            ?? MoonlightIntentCatalog.allIntents[0],
        model: MoonlightPreviewFixtures.model(),
        onDismiss: {}
    )
}
#endif
