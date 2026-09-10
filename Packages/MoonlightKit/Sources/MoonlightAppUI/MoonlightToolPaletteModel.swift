import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

@MainActor
@Observable
public final class MoonlightToolPaletteModel {
    public private(set) var descriptors: [ActionDescriptor] = []
    public var query = "" {
        didSet { reconcileSelection() }
    }
    public var selectedID: String? {
        didSet {
            guard selectedID != oldValue else { return }
            if let oldValue { draftStore.save(currentDraft, for: oldValue) }
            restore(draftStore.draft(for: selectedID ?? ""))
        }
    }
    public private(set) var isEditing = false
    public private(set) var presentationID = UUID()
    public var input = ""
    /// Values chosen for the selected tool's declared options.
    public var optionSelections: [String: String] = [:]
    public private(set) var result: Execution?
    public private(set) var errorMessage: String?
    public private(set) var catalogErrorMessage: String?
    public private(set) var activeInvocation: MoonlightToolInvocation?
    public var isWorking: Bool { activeInvocation != nil }
    public let preferredActionID: String?
    /// The app the user came from, shown so a command's origin stays visible
    /// while the palette is in front.
    public private(set) var sourceContext: MoonlightSourceContext?
    public private(set) var favoriteIDs: Set<String> = []

    private let client: MoonlightRuntimeClient
    private let provider: (any CommandCatalogProvider)?
    private let preferences: UserDefaults?
    private let openColorPicker: @MainActor () -> Void
    private var catalog: MoonlightToolCatalog
    private let search = MoonlightToolSearch()
    private let performer = ExecutionResultActionPerformer()
    private let draftStore = MoonlightToolDraftStore()

    public init(
        client: MoonlightRuntimeClient,
        provider: (any CommandCatalogProvider)? = nil,
        preferredActionID: String? = nil,
        preferences: UserDefaults? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        self.client = client
        self.provider = provider
        self.preferences = preferences
        self.preferredActionID = preferredActionID
        self.openColorPicker = onOpenColorPicker
        self.favoriteIDs = Set(preferences?.stringArray(forKey: "favoriteToolIDs") ?? [])

        var loadedCatalog = MoonlightToolCatalog(descriptors: [])
        var initialCatalogError: String?

        do {
            let definitions: [CommandDefinition]
            if let provider {
                definitions = try provider.snapshot()
            } else {
                definitions = Self.makeDefinitions(from: client.descriptors())
            }
            loadedCatalog = try MoonlightToolCatalog(definitions: definitions)
        } catch {
            initialCatalogError = error.localizedDescription
        }

        self.catalog = loadedCatalog
        self.descriptors = loadedCatalog.descriptors
        self.catalogErrorMessage = initialCatalogError
        self.selectedID = descriptors.first { $0.id == preferredActionID }?.id ?? descriptors.first?.id
        self.isEditing = preferredActionID != nil && selectedID == preferredActionID
    }

    /// Builds the model from the environment composed by the host process.
    /// A composition failure keeps the palette usable and visible as an error
    /// instead of leaving the surface without a model.
    public convenience init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError>,
        preferredActionID: String? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        switch environment {
        case let .success(environment):
            self.init(
                client: environment.client,
                provider: environment.catalogProvider,
                preferredActionID: preferredActionID,
                preferences: .standard,
                onOpenColorPicker: onOpenColorPicker
            )
        case let .failure(error):
            self.init(
                client: .init(
                    descriptors: { [] },
                    execute: { _ in throw error },
                    execution: { _ in nil },
                    recent: { _ in [] }
                ),
                provider: nil,
                preferredActionID: preferredActionID,
                onOpenColorPicker: onOpenColorPicker
            )
            self.errorMessage = error.localizedDescription
            self.catalogErrorMessage = error.localizedDescription
        }
    }

    private static func makeDefinitions(from descriptors: [ActionDescriptor]) -> [CommandDefinition] {
        let builtinRegistry = ActionRegistry.standard
        return descriptors.map { descriptor in
            let presentation = builtinRegistry.definition(id: descriptor.id)?.presentation ?? CommandPresentation(
                alias: descriptor.id,
                symbolName: "command",
                inputKind: .text,
                destination: .result
            )
            return CommandDefinition(descriptor: descriptor, presentation: presentation)
        }
    }

    public func refreshCatalog() {
        do {
            let definitions: [CommandDefinition]
            if let provider {
                definitions = try provider.snapshot()
            } else {
                definitions = Self.makeDefinitions(from: client.descriptors())
            }
            let newCatalog = try MoonlightToolCatalog(definitions: definitions)
            catalog = newCatalog
            descriptors = newCatalog.descriptors
            catalogErrorMessage = nil

            if isEditing {
                if let currentSelectedID = selectedID, descriptors.contains(where: { $0.id == currentSelectedID }) {
                    // Se editando e ID existe, preservar selecao.
                } else {
                    // Se selecionado foi removido enquanto isEditing, voltar ao catalogo em vez de abrir editor de outra ferramenta automaticamente.
                    isEditing = false
                    reconcileSelection()
                }
            } else {
                // Se nao editando, reconcileSelection sempre para respeitar busca quando titulo mudar.
                reconcileSelection()
            }
        } catch {
            catalogErrorMessage = error.localizedDescription
        }
    }

    public var filteredDescriptors: [ActionDescriptor] {
        filteredPresentations.compactMap { catalog.descriptor(for: $0.id) }
    }

    public var filteredPresentations: [MoonlightToolPresentation] {
        search.ranked(
            presentations: catalog.presentations,
            query: query,
            favoriteIDs: favoriteIDs
        )
    }

    public func presentation(for descriptor: ActionDescriptor) -> MoonlightToolPresentation {
        catalog.presentation(for: descriptor.id) ?? MoonlightToolPresentation(descriptor: descriptor)
    }

    public func toggleFavorite(_ descriptor: ActionDescriptor) {
        if favoriteIDs.contains(descriptor.id) {
            favoriteIDs.remove(descriptor.id)
        } else {
            favoriteIDs.insert(descriptor.id)
        }
        preferences?.set(favoriteIDs.sorted(), forKey: "favoriteToolIDs")
    }

    public func alias(for descriptor: ActionDescriptor) -> String {
        presentation(for: descriptor).alias
    }

    /// Completes a local command. Does not intercept Spotlight's Tab behavior.
    public func completeSelection() -> Bool {
        guard !query.isEmpty, let descriptor = selectedDescriptor else { return false }
        let completion = "\\" + alias(for: descriptor)
        guard query != completion else { return false }
        query = completion
        selectedID = descriptor.id
        return true
    }

    public var selectedDescriptor: ActionDescriptor? {
        descriptors.first { $0.id == selectedID }
    }

    public func preparePresentation(
        preferredActionID: String? = nil,
        sourceContext: MoonlightSourceContext? = nil
    ) {
        self.sourceContext = sourceContext
        refreshCatalog()
        if let preferredActionID,
           descriptors.contains(where: { $0.id == preferredActionID }) {
            query = ""
            selectedID = preferredActionID
            isEditing = true
        } else {
            isEditing = false
            query = ""
            reconcileSelection()
        }
        presentationID = UUID()
    }

    public func moveSelection(by offset: Int) {
        let visible = filteredDescriptors
        guard !visible.isEmpty else { return }
        guard let current = visible.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = offset < 0 ? visible.last?.id : visible.first?.id
            return
        }
        let next = min(max(current + offset, 0), visible.count - 1)
        selectedID = visible[next].id
    }

    public func openSelectedTool() {
        guard selectedDescriptor != nil else { return }
        isEditing = true
    }

    /// Returns true when Escape has no navigation left and the panel may close.
    public func goBack() -> Bool {
        if isEditing {
            isEditing = false
        } else if !query.isEmpty {
            query = ""
        } else {
            return true
        }
        return false
    }

    private func reconcileSelection() {
        guard !filteredPresentations.contains(where: { $0.id == selectedID }) else { return }
        selectedID = filteredPresentations.first?.id
    }

    private var currentDraft: MoonlightToolDraft {
        MoonlightToolDraft(
            input: input,
            optionSelections: optionSelections,
            result: result,
            errorMessage: errorMessage
        )
    }

    private func restore(_ draft: MoonlightToolDraft) {
        input = draft.input
        optionSelections = draft.optionSelections
        result = draft.result
        errorMessage = draft.errorMessage
    }

    /// The value shown for one option, falling back to the tool's default.
    public func optionValue(_ option: CommandOption) -> String {
        option.resolvedValue(from: optionSelections)
    }

    public func setOptionValue(_ value: String, for option: CommandOption) {
        optionSelections[option.parameterName] = value
    }

    public func execute(_ descriptor: ActionDescriptor) async {
        guard activeInvocation == nil else { return }

        let invocation = MoonlightToolInvocation(
            presentationID: presentationID,
            toolID: descriptor.id,
            input: input,
            optionSelections: optionSelections
        )
        let presentation = presentation(for: descriptor)
        let request = makeRequest(for: descriptor, presentation: presentation)
        var completedDraft = MoonlightToolDraft(
            input: input,
            optionSelections: optionSelections
        )

        activeInvocation = invocation
        result = nil
        errorMessage = nil
        defer {
            if activeInvocation == invocation {
                activeInvocation = nil
            }
        }

        do {
            let execution = try await client.execute(request)
            if execution.status == .succeeded {
                completedDraft.result = execution
            } else {
                completedDraft.errorMessage = execution.detail
            }
        } catch is CancellationError {
            // Cancellation is not a failed tool result.
            return
        } catch {
            completedDraft.errorMessage = error.localizedDescription
        }

        // A result belongs to the presentation that requested it. Once that
        // presentation is gone the response has no surface left to own.
        guard invocation.presentationID == presentationID else { return }

        guard selectedID == invocation.toolID else {
            // The tool left the screen: keep the result with its own draft,
            // unless that draft already moved on without this invocation.
            guard invocation.matches(draftStore.draft(for: invocation.toolID)) else { return }
            draftStore.save(completedDraft, for: invocation.toolID)
            return
        }

        // The tool is still selected but its input may have been retyped.
        guard invocation.matches(currentDraft) else { return }

        result = completedDraft.result
        errorMessage = completedDraft.errorMessage
        if presentation.destination == .colorPicker, completedDraft.result != nil {
            openColorPicker()
        }
    }

    /// Builds the request from the tool's declared options. No branch here
    /// knows which tool it is building for.
    private func makeRequest(
        for descriptor: ActionDescriptor,
        presentation: MoonlightToolPresentation
    ) -> ActionRequest {
        ActionRequest(
            actionID: descriptor.id,
            input: presentation.acceptsInput ? input : "",
            parameters: presentation.options.parameters(from: optionSelections)
        )
    }

    /// The actions the current result supports. Empty until a command produced
    /// a value, so the menu never offers something that cannot be done.
    public var resultActions: [ExecutionResultAction] {
        result?.resultActions ?? []
    }

    /// Runs a result action and surfaces its failure in the palette.
    public func perform(_ action: ExecutionResultAction) {
        errorMessage = performer.perform(action)
    }

    public func acceptsInput(_ descriptor: ActionDescriptor) -> Bool {
        presentation(for: descriptor).acceptsInput
    }
}
