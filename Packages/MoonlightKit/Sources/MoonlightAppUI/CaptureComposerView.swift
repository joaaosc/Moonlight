import MoonlightDomain
import Observation
import SwiftUI

struct CaptureComposerView: View {
    @Bindable var model: MoonlightModel
    let onCapture: () -> Void

    @FocusState private var isTextFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Capture Note", systemImage: "square.and.pencil")
                .font(.title2.bold())

            Text("Save a note here or run a ‘note …’ command with Moonlight in Spotlight.")
                .foregroundStyle(.secondary)

            TextField("Enter a note", text: $model.text, axis: .vertical)
                .lineLimit(3...6)
                .focused($isTextFocused)
                .accessibilityHint("Press Command Return to capture the note.")

            HStack(spacing: 10) {
                Text(characterCountLabel)
                    .font(.caption)
                    .foregroundStyle(
                        model.inputValidationMessage == nil ? Color.secondary : Color.red
                    )

                Spacer()

                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Capturing note")
                }

                Button("Capture", systemImage: "arrow.down.doc", action: onCapture)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canCapture)
                    .help("Capture note (Command-Return)")
            }

            if let validationMessage = model.inputValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Input error: \(validationMessage)")
            } else if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(24)
        .onAppear {
            isTextFocused = true
        }
    }

    private var characterCountLabel: String {
        "\(model.inputCharacterCount.formatted()) of \(CaptureNoteAction.maximumCharacterCount.formatted()) characters"
    }
}
