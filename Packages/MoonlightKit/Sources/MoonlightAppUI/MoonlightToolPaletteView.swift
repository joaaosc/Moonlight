import AppKit
import SwiftUI
import MoonlightDomain

public struct MoonlightToolPaletteView: View {
    /// Where the palette is being shown.
    ///
    /// The same view backs the floating launcher and the menu bar popover. The
    /// launcher owns its whole window and can afford the lighter, chrome-free
    /// treatment; the popover is already inside system chrome and would read as
    /// a panel inside a panel if it borrowed it.
    public enum Appearance: Sendable {
        case glassPanel
        case embedded
    }

    @Bindable private var model: MoonlightToolPaletteModel
    @FocusState private var focusedField: Field?
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let appearance: Appearance
    private let onDismiss: () -> Void

    private enum Field: Hashable {
        case search, input
    }

    private var isGlassPanel: Bool { appearance == .glassPanel }

    public init(
        model: MoonlightToolPaletteModel,
        appearance: Appearance = .embedded,
        onDismiss: @escaping () -> Void = { MoonlightToolPalettePresenter.shared.dismiss() }
    ) {
        self.model = model
        self.appearance = appearance
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !isGlassPanel || model.isEditing {
                Divider()
            }

            if let catalogError = model.catalogErrorMessage {
                errorLabel(catalogError)
            }

            if model.isEditing, let descriptor = model.selectedDescriptor {
                editor(for: descriptor)
                    .transition(.opacity)
            } else {
                catalogue
                    .transition(.opacity)
            }
        }
        .padding(isGlassPanel ? MoonlightGlassMetrics.contentPadding : 16)
        .frame(minWidth: 480, idealWidth: 640, minHeight: 420, idealHeight: 520)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: model.isEditing)
        .onAppear { restoreFocus() }
        .onChange(of: model.isEditing) { restoreFocus() }
        .onChange(of: model.presentationID) { restoreFocus() }
        .onExitCommand { goBack() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            if model.isEditing {
                backButton
            } else if !isGlassPanel {
                Image(systemName: "moon.stars")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            // In the launcher the search field below is the title: repeating
            // the app's name above it would be chrome with nothing to say.
            if model.isEditing || !isGlassPanel {
                Text(model.isEditing ? (model.selectedDescriptor?.title ?? "Moonlight") : "Moonlight")
                    .font(isGlassPanel ? .title3.weight(.semibold) : .headline)
            }

            Spacer(minLength: 0)

            if model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Running tool")
            }
        }
        // The search field is right below in the catalogue, so a button that
        // only moves focus there would be a second control for one action.
    }

    @ViewBuilder
    private var backButton: some View {
        let label = Image(systemName: "chevron.backward")
            .font(.body.weight(.medium))

        if isGlassPanel {
            Button { goBack() } label: {
                label.frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Back to tools")
            .help("Back to tools (Escape)")
        } else {
            Button("Back to tools", systemImage: "chevron.backward") { goBack() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Back to tools (Escape)")
        }
    }

    private var catalogue: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                TextField("Search tools", text: $model.query)
                    // Plain, so the field reads as the palette's own input
                    // instead of a bordered form control with a focus ring
                    // drawn around it.
                    .textFieldStyle(.plain)
                    .font(isGlassPanel ? .title2 : .title3)
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
            }
            .padding(.horizontal, isGlassPanel ? 14 : 10)
            .padding(.vertical, isGlassPanel ? 11 : 8)
            .background {
                if isGlassPanel {
                    // The field is the panel's primary control, so it gets its
                    // own glass rather than a filled rectangle competing with
                    // the surface behind it.
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.08))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quinary)
                }
            }
            .overlay {
                if isGlassPanel {
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
            }

            if let commandLineState = model.commandLineState {
                commandLinePlaceholder(commandLineState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filteredDescriptors.isEmpty {
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
                            let isFavorite = model.favoriteIDs.contains(descriptor.id)
                            HStack(spacing: 10) {
                                Image(systemName: model.presentation(for: descriptor).symbolName)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(descriptor.title)
                                    Text(descriptor.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Text("\\" + model.alias(for: descriptor))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                                Button(
                                    isFavorite ? "Remove Favorite" : "Add Favorite",
                                    systemImage: isFavorite ? "star.fill" : "star"
                                ) {
                                    model.toggleFavorite(descriptor, undoManager: undoManager)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                // Filled and tinted only when it means something;
                                // an outline in black on every row reads as a
                                // control rather than as state.
                                .foregroundStyle(isFavorite ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                                .help("Favorite \(descriptor.title)")
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .listRowSeparator(.hidden)
                            .tag(descriptor.id)
                            .id(descriptor.id)
                            .onTapGesture(count: 2) {
                                model.selectedID = descriptor.id
                                activateSelectedTool()
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 34)
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

            if let error = model.errorMessage {
                errorLabel(error)
            }
            Divider()
            HStack(spacing: 8) {
                Text("↑↓ Select · Tab Complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let sourceContext = model.sourceContext {
                    // Where the invocation came from: context, not a title.
                    Text("· from \(sourceContext.name)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .accessibilityLabel("Invoked from \(sourceContext.name)")
                }
                Spacer(minLength: 8)
                // A palette's primary action is the Return key. A filled button
                // here would compete with the selected row for attention.
                Button {
                    activateSelectedTool()
                } label: {
                    HStack(spacing: 4) {
                        Text("Open")
                        Image(systemName: "return")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(model.selectedDescriptor == nil || model.isWorking)
            }
        }
    }

    private func editor(for descriptor: ActionDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(descriptor.summary)
                .foregroundStyle(.secondary)

            // Options are declared by each feature; the palette renders them
            // without knowing which tool is selected.
            ForEach(model.presentation(for: descriptor).options) { option in
                Picker(option.title, selection: Binding(
                    get: { model.optionValue(option) },
                    set: { model.setOptionValue($0, for: option) }
                )) {
                    ForEach(option.choices) { choice in
                        Text(choice.title).tag(choice.value)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isWorking)
            }

            if model.acceptsInput(descriptor) {
                TextEditor(text: $model.input)
                    .font(.body.monospaced())
                    .focused($focusedField, equals: .input)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.quaternary)
                    )
                    .accessibilityLabel("Input for \(descriptor.title)")
                    .disabled(model.isWorking)
            }

            if let result = model.result {
                let output = result.resolvedOutput
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(output.summary).font(.subheadline.weight(.semibold))
                        Spacer()
                        // Availability comes from the result itself: a command
                        // that returned nothing offers no actions at all.
                        if let transfer = ExecutionResultTransfer(execution: result) {
                            // Dragging or sharing hands over the typed value,
                            // not the rendered summary around it.
                            ShareLink(item: transfer.text)
                                .labelStyle(.iconOnly)
                                .help("Share result")
                        }
                        if !model.resultActions.isEmpty {
                            Menu("Actions", systemImage: "ellipsis.circle") {
                                ForEach(model.resultActions) { action in
                                    Button(action.title, systemImage: action.symbolName) {
                                        model.perform(action)
                                    }
                                    .keyboardShortcut(Self.shortcut(for: action))
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .keyboardShortcut("k", modifiers: .command)
                            .help("Result actions (⌘K)")
                        }
                    }
                    if let value = output.value.text {
                        ScrollView {
                            Text(value)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 160)
                        .draggable(value)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.quaternary)
                )
            }

            if let error = model.errorMessage { errorLabel(error) }
            if !model.acceptsInput(descriptor) { Spacer(minLength: 0) }
            Divider()
            HStack {
                Text("Esc Back · ⌘Return Run")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Inside the editor there is a form to submit, so the default
                // button is the right control — unlike the catalogue, where
                // Return already acts on the selected row.
                Button("Run \(descriptor.title)") {
                    Task { await model.execute(descriptor) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
            }
        }
    }

    /// Each action keeps a direct key, so the whole cycle works without a mouse.
    private static func shortcut(for action: ExecutionResultAction) -> KeyEquivalent {
        switch action {
        case .copy: "c"
        case .save: "s"
        case .open: "o"
        }
    }

    /// What a typed command shows while the catalogue is still empty. The text
    /// the user typed stays on screen: nothing about the command is discarded.
    @ViewBuilder
    private func commandLinePlaceholder(
        _ state: MoonlightToolPaletteModel.CommandLineState
    ) -> some View {
        switch state {
        case let .unpublished(command):
            ContentUnavailableView(
                "No /\(command.name) command",
                systemImage: "command",
                description: Text("Moonlight does not publish this command yet.")
            )
        case let .invalid(message):
            ContentUnavailableView(
                "Not a command",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .textSelection(.enabled)
    }

    private func activateSelectedTool() {
        guard !model.isWorking, let descriptor = model.selectedDescriptor else { return }
        let presentation = model.presentation(for: descriptor)
        if presentation.destination == .colorPicker {
            Task { await model.execute(descriptor) }
            return
        }
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
