import MoonlightDomain

public struct MoonlightToolDraft: Sendable {
    public var input = ""
    public var operation: Base64TextOperation = .encode
    public var result: Execution?
    public var errorMessage: String?

    public init(
        input: String = "",
        operation: Base64TextOperation = .encode,
        result: Execution? = nil,
        errorMessage: String? = nil
    ) {
        self.input = input
        self.operation = operation
        self.result = result
        self.errorMessage = errorMessage
    }
}

@MainActor
public final class MoonlightToolDraftStore {
    private var drafts: [String: MoonlightToolDraft] = [:]

    public init() {}

    public func draft(for id: String) -> MoonlightToolDraft {
        drafts[id] ?? MoonlightToolDraft()
    }

    public func save(_ draft: MoonlightToolDraft, for id: String) {
        drafts[id] = draft
    }
}
