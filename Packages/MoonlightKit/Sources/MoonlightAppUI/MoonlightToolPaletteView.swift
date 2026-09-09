import AppKit
import SwiftUI
import MoonlightDomain

public struct MoonlightToolPaletteView: View {
    @Bindable private var model: MoonlightToolPaletteModel
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onDismiss: () -> Void

    private enum Field: Hashable {
        case search, input
    }

    public init(
        model: MoonlightToolPaletteModel,
        onDismiss: @escaping () -> Void = { MoonlightToolPalettePresenter.shared.dismiss() }
    ) {
        self.model = model
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()

            if model.isEditing, let descriptor = model.selectedDescriptor {
                editor(for: descriptor)
                    .transition(.opacity)
            } else {
                catalogue
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(minWidth: 480, idealWidth: 640, minHeight: 420, idealHeight: 520)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: model.isEditing)
        .onAppear { restoreFocus() }
        .onChange(of: model.isEditing) { restoreFocus() }
        .onChange(of: model.presentationID) { restoreFocus() }
        .onExitCommand { goBack() }
    }

    private var header: some View {
        HStack {
            if model.isEditing {
                Button("Back to tools", systemImage: "chevron.left") { goBack() }
                    .labelStyle(.iconOnly)
                    .help("Back to tools (Escape)")
            } else {
                Image(systemName: "command.square")
                    .accessibilityHidden(true)
            }
            Text(model.isEditing ? (model.selectedDescriptor?.title ?? "Moonlight") : "Moonlight")
                .font(.headline)
            Spacer()
            if model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Running tool")
            }
            Button("Search tools", systemImage: "magnifyingglass") {
                if model.isEditing { _ = model.goBack() }
                focusedField = .search
            }
            .labelStyle(.iconOnly)
            .keyboardShortcut("l", modifiers: .command)
            .help("Search tools (⌘L)")
        }
    }

    private var catalogue: some View {
        VStack(spacing: 12) {
            TextField("Search tools", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search tools")
                .focused($focusedField, equals: .search)
                .onSubmit { activateSelectedTool() }
                .onKeyPress(.tab, phases: .down) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    return model.completeSelection() ? .handled : .ignored
                }
                .onKeyPress(.downArrow, phases: [.down, .repeat]) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    model.moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow, phases: [.down, .repeat]) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    model.moveSelection(by: -1)
                    return .handled
                }

            if model.filteredDescriptors.isEmpty {
                ContentUnavailableView(
                    "No tools found",
                    systemImage: "magnifyingglass",
                    description: Text("Try another name or clear the search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scroll in
                    List(selection: $model.selectedID) {
                        ForEach(model.filteredDescriptors) { descriptor in
                            HStack(spacing: 12) {
                                Image(systemName: model.presentation(for: descriptor).symbolName)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(descriptor.title)
                                    Text(descriptor.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Text("\\" + model.alias(for: descriptor))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Button(
                                    model.favoriteIDs.contains(descriptor.id) ? "Remove Favorite" : "Add Favorite",
                                    systemImage: model.favoriteIDs.contains(descriptor.id) ? "star.fill" : "star"
                                ) {
                                    model.toggleFavorite(descriptor)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .help("Favorite \(descriptor.title)")
                            }
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .tag(descriptor.id)
                            .id(descriptor.id)
                            .onTapGesture(count: 2) {
                                model.selectedID = descriptor.id
                                activateSelectedTool()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.isEmpty else { return .ignored }
                        activateSelectedTool()
                        return .handled
                    }
                    .onChange(of: model.selectedID) {
                        if let id = model.selectedID { scroll.scrollTo(id) }
                    }
                }
            }

            if let error = model.errorMessage, model.descriptors.isEmpty {
                errorLabel(error)
            }
            Divider()
            HStack {
                Text("↑↓ Select · Tab Complete · Return Open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Tool") { activateSelectedTool() }
                    .buttonStyle(.glassProminent)
                    .disabled(model.selectedDescriptor == nil || model.isWorking)
            }
        }
    }

    private func editor(for descriptor: ActionDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(descriptor.summary)
                .foregroundStyle(.secondary)

            if descriptor.id == MoonlightActionID.base64Text {
                Picker("Operation", selection: $model.base64Operation) {
                    ForEach(Base64TextOperation.allCases, id: \.self) { operation in
                        Text(operation.rawValue.capitalized).tag(operation)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isWorking)
            }

            if model.acceptsInput(descriptor) {
                TextEditor(text: $model.input)
                    .font(.body.monospaced())
                    .focused($focusedField, equals: .input)
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .accessibilityLabel("Input for \(descriptor.title)")
                    .disabled(model.isWorking)
            }

            if let result = model.result {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(result.summary).font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Copy Result", systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.detail, forType: .string)
                        }
                    }
                    ScrollView {
                        Text(result.detail)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
                .padding(12)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            if let error = model.errorMessage { errorLabel(error) }
            if !model.acceptsInput(descriptor) { Spacer(minLength: 0) }
            Divider()
            HStack {
                Text("Esc Back · ⌘Return Run")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Run \(descriptor.title)") {
                    Task { await model.execute(descriptor) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.glassProminent)
                .disabled(model.isWorking)
            }
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .textSelection(.enabled)
    }

    private func activateSelectedTool() {
        guard !model.isWorking, let descriptor = model.selectedDescriptor else { return }
        model.openSelectedTool()
        if !model.acceptsInput(descriptor) {
            Task { await model.execute(descriptor) }
        }
    }

    private func goBack() {
        if model.goBack() { onDismiss() }
    }

    private func restoreFocus() {
        if model.isEditing, let descriptor = model.selectedDescriptor {
            focusedField = model.acceptsInput(descriptor) ? .input : nil
        } else {
            focusedField = .search
        }
    }

}
