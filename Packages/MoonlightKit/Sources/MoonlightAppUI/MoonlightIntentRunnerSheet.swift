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

            ScrollView {
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

                    Button("Run \(item.title)", systemImage: "play.fill", action: run)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(isRunning || !hasRunnableInput)

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
            }
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 420, idealHeight: 520)
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

            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
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
