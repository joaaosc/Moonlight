import MoonlightDomain

public struct MoonlightToolDraft: Sendable, Equatable {
    public var input = ""
    /// Chosen values per option parameter, empty while the defaults apply.
    public var optionSelections: [String: String] = [:]
    public var result: Execution?
    public var errorMessage: String?

    public init(
        input: String = "",
        optionSelections: [String: String] = [:],
        result: Execution? = nil,
        errorMessage: String? = nil
    ) {
        self.input = input
        self.optionSelections = optionSelections
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
