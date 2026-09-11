import AppKit
import MoonlightDomain
import SwiftUI

/// An interactive modal sheet for configuring, running, and inspecting an App Intent with Liquid Glass styling.
public struct MoonlightIntentRunnerSheet: View {
    public let item: MoonlightIntentItem
    @Bindable public var model: MoonlightModel
    public var notesModel: MoonlightNotesModel?
    public let onDismiss: () -> Void

    @State private var inputText = ""
    @State private var selectedParameterValue: String = ""
    @State private var outputText: String?
    @State private var outputStatus: ExecutionStatus?
    @State private var isRunning = false
    @State private var isCopied = false
    @State private var isSavedToNotes = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

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
        VStack(spacing: 0) {
            // Header Bar
            headerBar
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Parameter picker if applicable
                    if let paramKey = item.parameterKey, !item.parameterOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Option (\(paramKey.capitalized))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $selectedParameterValue) {
                                ForEach(item.parameterOptions, id: \.value) { option in
                                    Text(option.title).tag(option.value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    // Input Text Area
                    if item.requiresInput {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Input")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Paste") {
                                    if let string = NSPasteboard.general.string(forType: .string) {
                                        inputText = string
                                    }
                                }
                                .font(.system(size: 11, weight: .medium))
                                .buttonStyle(.plain)
                                .foregroundStyle(item.accentColor)

                                Text("·")
                                    .foregroundStyle(.tertiary)

                                Button("Sample") {
                                    inputText = item.sampleInput
                                }
                                .font(.system(size: 11, weight: .medium))
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)

                                if !inputText.isEmpty {
                                    Text("·")
                                        .foregroundStyle(.tertiary)

                                    Button("Clear") {
                                        inputText = ""
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }

                            TextEditor(text: $inputText)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 110, maxHeight: 180)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        }
                                }
                        }
                    }

                    // Run Action Button
                    Button {
                        Task { await runIntent() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRunning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text(isRunning ? "Running Intent..." : "Run \(item.title)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: item.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                                }
                        }
                        .shadow(color: item.gradientColors.first!.opacity(0.35), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning || (item.requiresInput && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                    // Error Message
                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        }
                    }

                    // Output Result Area
                    if let outputText {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(outputStatus == .succeeded ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(outputStatus == .succeeded ? "Result" : "Execution Failed")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(outputStatus == .succeeded ? .green : .red)
                                }

                                Spacer()

                                Button {
                                    copyOutput()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                        Text(isCopied ? "Copied!" : "Copy")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isCopied ? .green : .primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)

                                if notesModel != nil {
                                    Button {
                                        saveToNotes()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: isSavedToNotes ? "checkmark" : "note.text.badge.plus")
                                            Text(isSavedToNotes ? "Saved!" : "Save Note")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(isSavedToNotes ? .green : .primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.08), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(outputText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                                        }
                                }
                        }
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 520, height: 500)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    wash
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            // Intent Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }

                Image(systemName: item.symbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text(item.category.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var wash: some View {
        ZStack {
            RadialGradient(
                colors: [item.gradientColors.first!.opacity(colorScheme == .dark ? 0.25 : 0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [item.gradientColors.last!.opacity(colorScheme == .dark ? 0.20 : 0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 400
            )
        }
    }

    private func runIntent() async {
        isRunning = true
        errorMessage = nil
        isCopied = false
        isSavedToNotes = false
        defer { isRunning = false }

        // Special case: Color Picker
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

        let input = item.requiresInput ? inputText : ""
        let execution = await model.execute(
            actionID: item.id,
            input: input,
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
        withAnimation {
            isCopied = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                isCopied = false
            }
        }
    }

    private func saveToNotes() {
        guard let outputText else { return }
        Task {
            model.text = outputText
            _ = await model.capture()
            await notesModel?.load()
            withAnimation {
                isSavedToNotes = true
            }
        }
    }
}
