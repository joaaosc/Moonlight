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
        VStack(alignment: .leading, spacing: MoonlightGlassMetrics.contentSpacing) {
            header
            Divider()

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
        .padding(MoonlightGlassMetrics.contentPadding)
        .frame(
            minWidth: MoonlightGlassMetrics.paletteMinimumSize.width,
            idealWidth: MoonlightGlassMetrics.paletteSize.width,
            maxWidth: .infinity,
            minHeight: MoonlightGlassMetrics.paletteMinimumSize.height,
            idealHeight: MoonlightGlassMetrics.paletteSize.height,
            maxHeight: .infinity
        )
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
            } else {
                Image(systemName: "moon.stars")
                    .foregroundStyle(MoonlightGlassPalette.glyph)
                    .accessibilityHidden(true)
            }

            Text(model.isEditing ? (model.selectedDescriptor?.title ?? "Moonlight") : "Moonlight")
                .font(.headline)

            Spacer(minLength: 0)

            if model.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Running tool")
            }
        }
        // The header is also the panel's grab bar. A palette is a list that
        // fills its window, so without a stated drag area a large panel had
        // nowhere left to be moved by.
        .frame(minHeight: MoonlightGlassMetrics.dragHandleHeight)
        .moonlightWindowDrag(isEnabled: isGlassPanel)
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
                    .font(MoonlightGlassMetrics.searchFont)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            // A capsule wherever the palette is shown — in the panel and in
            // the menu bar popover alike. The search field is Moonlight's
            // signature control, so it keeps one shape.
            .moonlightFieldBackground(Capsule())

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
                            row(for: descriptor)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                            .listRowSeparator(.hidden)
                            // Moonlight's own selection, not the system's flat
                            // table highlight: the one place in the catalogue
                            // where colour carries meaning.
                            .listRowBackground(
                                model.selectedID == descriptor.id
                                    ? MoonlightSelectionBackground()
                                    : nil
                            )
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
            HStack(spacing: 6) {
                KeyHint(
                    symbol: "arrow.up.arrow.down",
                    label: "Select",
                    description: "Select with the arrow keys"
                )
                KeyHint(
                    symbol: "arrow.right.to.line",
                    label: "Complete",
                    description: "Complete with Tab"
                )
                if let sourceContext = model.sourceContext {
                    // Where the invocation came from: context, not a title.
                    Text(sourceContext.name)
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
                    KeyHint(
                        symbol: "return",
                        label: "Open",
                        description: "Open the selected tool"
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.selectedDescriptor == nil || model.isWorking)
                .help("Open the selected tool (Return)")
            }
        }
    }

    /// One tool in the catalogue.
    ///
    /// Only the selected row carries its summary. Showing every description at
    /// once turns the list into a wall of prose, and the one being chosen is
    /// the only one whose detail is being read.
    @ViewBuilder
    private func row(for descriptor: ActionDescriptor) -> some View {
        let isFavorite = model.favoriteIDs.contains(descriptor.id)
        let isSelected = model.selectedID == descriptor.id

        HStack(spacing: 12) {
            Image(systemName: model.presentation(for: descriptor).symbolName)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 26, height: 26)
                // Colour marks the row being chosen, and nothing else in the
                // list: a tinted glyph on every row would be a palette of
                // twelve competing accents.
                .foregroundStyle(
                    isSelected
                        ? AnyShapeStyle(MoonlightGlassPalette.glyph)
                        : AnyShapeStyle(.secondary)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(descriptor.title)
                if isSelected {
                    Text(descriptor.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Text(String(SlashCommand.prefix) + model.alias(for: descriptor))
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            // Filled and tinted only when it means something; an outline on
            // every row reads as a control rather than as state.
            Button(
                isFavorite ? "Remove Favorite" : "Add Favorite",
                systemImage: isFavorite ? "star.fill" : "star"
            ) {
                model.toggleFavorite(descriptor, undoManager: undoManager)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(isFavorite ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
            .opacity(isFavorite || isSelected ? 1 : 0)
            .help("Favorite \(descriptor.title)")
        }
    }

    private func editor(for descriptor: ActionDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The tool's name and summary are already in the header; repeating
            // the summary here is a second title for the same screen.

            // Options are declared by each feature; the palette renders them
            // without knowing which tool is selected. The label is dropped
            // because a two-choice segmented control states its own question.
            ForEach(model.presentation(for: descriptor).options) { option in
                Picker(option.title, selection: model.binding(for: option)) {
                    ForEach(option.choices) { choice in
                        Text(choice.title).tag(choice.value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .disabled(model.isWorking)
            }

            if model.acceptsInput(descriptor) {
                TextEditor(text: $model.input)
                    .font(.body.monospaced())
                    .focused($focusedField, equals: .input)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .moonlightFieldBackground(MoonlightGlassMetrics.fieldShape)
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
                .moonlightFieldBackground(MoonlightGlassMetrics.fieldShape)
            }

            if let error = model.errorMessage { errorLabel(error) }
            if !model.acceptsInput(descriptor) { Spacer(minLength: 0) }
            Divider()
            HStack(spacing: 6) {
                KeyHint(symbol: "escape", label: "Back", description: "Back to tools")
                Spacer()
                // Inside the editor there is a form to submit, so the default
                // button is the right control — unlike the catalogue, where
                // Return already acts on the selected row. The tool's name is
                // in the header, so the button only has to name the verb.
                Button {
                    Task { await model.execute(descriptor) }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
                .help("Run \(descriptor.title) (⌘Return)")
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
