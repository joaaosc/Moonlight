import SwiftUI
import MoonlightDomain

public struct MoonlightToolPaletteView: View {
    @Bindable private var model: MoonlightToolPaletteModel
    @State private var selectedID: String?
    @FocusState private var searchIsFocused: Bool

    public init(model: MoonlightToolPaletteModel) {
        self.model = model
        _selectedID = State(initialValue: model.preferredActionID)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "command.square")
                Text("Tools")
                    .font(.headline)
                Spacer()
                if model.isWorking {
                    ProgressView().controlSize(.small)
                }
            }

            TextField("Search tools", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search tools")
                .focused($searchIsFocused)

            List(selection: $selectedID) {
                ForEach(model.filteredDescriptors) { descriptor in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(descriptor.title)
                        Text(descriptor.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .tag(descriptor.id)
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 150)

            if let selectedDescriptor {
                if selectedDescriptor.id == MoonlightActionID.base64Text {
                    Picker("Operation", selection: $model.base64Operation) {
                        ForEach(Base64TextOperation.allCases, id: \.self) { operation in
                            Text(operation.rawValue.capitalized).tag(operation)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if model.acceptsInput(selectedDescriptor) {
                    TextEditor(text: $model.input)
                        .font(.body.monospaced())
                        .frame(minHeight: 76, maxHeight: 150)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .accessibilityLabel("Tool input")
                }

                Button("Run \(selectedDescriptor.title)") {
                    Task { await model.execute(selectedDescriptor) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking)
            }

            if let result = model.result {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.summary).font(.subheadline.weight(.semibold))
                    ScrollView {
                        Text(result.detail).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(8)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(width: 420, height: 560)
        .onAppear {
            selectFirstVisibleTool()
            searchIsFocused = true
        }
        .onChange(of: model.query) {
            selectFirstVisibleTool()
        }
    }

    private var selectedDescriptor: ActionDescriptor? {
        guard let selectedID else { return model.filteredDescriptors.first }
        return model.descriptors.first { $0.id == selectedID }
    }

    private func selectFirstVisibleTool() {
        guard !model.filteredDescriptors.contains(where: { $0.id == selectedID }) else {
            return
        }
        selectedID = model.filteredDescriptors.first?.id
    }
}
