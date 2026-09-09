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
            if let oldValue { drafts[oldValue] = currentDraft }
            restore(drafts[selectedID ?? ""] ?? Draft())
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
    private var drafts: [String: Draft] = [:]

    private struct Draft {
        var input = ""
        var operation: Base64TextOperation = .encode
        var result: Execution?
        var errorMessage: String?
    }

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
        descriptors = client.descriptors().sorted { $0.title < $1.title }
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
        let matches = descriptors.compactMap { descriptor -> (ActionDescriptor, Int)? in
            let score = searchScore(for: descriptor)
            return score > 0 ? (descriptor, score) : nil
        }
        return matches.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            let firstIsFavorite = favoriteIDs.contains($0.0.id)
            let secondIsFavorite = favoriteIDs.contains($1.0.id)
            if firstIsFavorite != secondIsFavorite { return firstIsFavorite }
            return $0.0.title < $1.0.title
        }.map(\.0)
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
        switch descriptor.id {
        case MoonlightActionID.captureNote: "note"
        case MoonlightActionID.openColorPicker: "color"
        case MoonlightActionID.cleanText: "clean"
        case MoonlightActionID.formatJSON: "json"
        case MoonlightActionID.generateUUID: "uuid"
        case MoonlightActionID.base64Text: "base64"
        default: descriptor.id
        }
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

    private func searchScore(for descriptor: ActionDescriptor) -> Int {
        var text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("\\") { text.removeFirst() }
        guard !text.isEmpty else { return 1 }
        let command = alias(for: descriptor)
        if command == text || descriptor.title.lowercased() == text { return 4 }
        if command.hasPrefix(text) || descriptor.title.lowercased().hasPrefix(text) { return 3 }
        let searchableText = "\(descriptor.title) \(descriptor.summary) \(command)".lowercased()
        return text.split(whereSeparator: \.isWhitespace).allSatisfy {
            searchableText.contains($0)
        } ? 2 : 0
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
        guard !filteredDescriptors.contains(where: { $0.id == selectedID }) else { return }
        selectedID = filteredDescriptors.first?.id
    }

    private var currentDraft: Draft {
        Draft(input: input, operation: base64Operation, result: result, errorMessage: errorMessage)
    }

    private func restore(_ draft: Draft) {
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
            drafts[selectionAtStart] = completedDraft
        }
    }

    public func acceptsInput(_ descriptor: ActionDescriptor) -> Bool {
        switch descriptor.id {
        case MoonlightActionID.generateUUID, MoonlightActionID.openColorPicker:
            false
        default:
            true
        }
    }

    private func input(for descriptor: ActionDescriptor) -> String {
        acceptsInput(descriptor) ? input : ""
    }
}
