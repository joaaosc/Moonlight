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
    public var base64Operation: Base64TextOperation = .encode
    public private(set) var result: Execution?
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false
    public let preferredActionID: String?
    public private(set) var favoriteIDs: Set<String> = []

    private let client: MoonlightRuntimeClient
    private let preferences: UserDefaults?
    private let openColorPicker: @MainActor () -> Void
    private let catalog: MoonlightToolCatalog
    private let search = MoonlightToolSearch()
    private let draftStore = MoonlightToolDraftStore()

    public init(
        client: MoonlightRuntimeClient,
        preferredActionID: String? = nil,
        preferences: UserDefaults? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        self.client = client
        self.preferences = preferences
        self.preferredActionID = preferredActionID
        self.openColorPicker = onOpenColorPicker
        catalog = MoonlightToolCatalog(descriptors: client.descriptors())
        descriptors = catalog.descriptors
        favoriteIDs = Set(preferences?.stringArray(forKey: "favoriteToolIDs") ?? [])
        selectedID = descriptors.first { $0.id == preferredActionID }?.id ?? descriptors.first?.id
        isEditing = preferredActionID != nil && selectedID == preferredActionID
    }

    public convenience init(
        preferredActionID: String? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        switch MoonlightRuntime.liveClient {
        case let .success(client):
            self.init(
                client: client,
                preferredActionID: preferredActionID,
                preferences: .standard,
                onOpenColorPicker: onOpenColorPicker
            )
        case let .failure(error):
            self.init(client: .init(
                descriptors: { [] },
                execute: { _ in throw error },
                execution: { _ in nil },
                recent: { _ in [] }
            ), preferredActionID: preferredActionID, onOpenColorPicker: onOpenColorPicker)
            errorMessage = error.localizedDescription
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

    public func preparePresentation(preferredActionID: String? = nil) {
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
        MoonlightToolDraft(input: input, operation: base64Operation, result: result, errorMessage: errorMessage)
    }

    private func restore(_ draft: MoonlightToolDraft) {
        input = draft.input
        base64Operation = draft.operation
        result = draft.result
        errorMessage = draft.errorMessage
    }

    public func execute(_ descriptor: ActionDescriptor) async {
        guard !isWorking else { return }

        isWorking = true
        result = nil
        errorMessage = nil
        let selectionAtStart = selectedID
        var completedDraft = currentDraft
        defer { isWorking = false }

        let request: ActionRequest
        if descriptor.id == MoonlightActionID.base64Text {
            request = .transformBase64(input: input, operation: base64Operation)
        } else {
            request = ActionRequest(
                actionID: descriptor.id,
                input: input(for: descriptor)
            )
        }

        do {
            let execution = try await client.execute(request)
            if execution.status == .succeeded {
                completedDraft.result = execution
                if descriptor.id == MoonlightActionID.openColorPicker,
                   selectedID == selectionAtStart {
                    openColorPicker()
                }
            } else {
                completedDraft.errorMessage = execution.detail
            }
        } catch is CancellationError {
            // Cancellation is not a failed tool result.
        } catch {
            completedDraft.errorMessage = error.localizedDescription
        }
        if selectedID == selectionAtStart {
            result = completedDraft.result
            errorMessage = completedDraft.errorMessage
        } else if let selectionAtStart {
            draftStore.save(completedDraft, for: selectionAtStart)
        }
    }

    public func acceptsInput(_ descriptor: ActionDescriptor) -> Bool {
        presentation(for: descriptor).acceptsInput
    }

    private func input(for descriptor: ActionDescriptor) -> String {
        acceptsInput(descriptor) ? input : ""
    }
}
