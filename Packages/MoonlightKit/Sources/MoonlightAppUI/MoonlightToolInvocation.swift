import Foundation
import MoonlightDomain

/// Identity of a single command execution requested from the palette.
///
/// The tool ID alone cannot own a result: closing and reopening the palette,
/// or moving A→B→A while a command runs, would let a stale response take over
/// the current presentation. An invocation binds the tool to the presentation
/// and to the draft that produced it, so a late result is routed back to its
/// own draft or discarded instead of overwriting what is on screen now.
public struct MoonlightToolInvocation: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let presentationID: UUID
    public let toolID: String
    public let input: String
    public let optionSelections: [String: String]

    init(
        presentationID: UUID,
        toolID: String,
        input: String,
        optionSelections: [String: String]
    ) {
        self.id = UUID()
        self.presentationID = presentationID
        self.toolID = toolID
        self.input = input
        self.optionSelections = optionSelections
    }

    /// True when `draft` still holds the values this invocation was built from.
    func matches(_ draft: MoonlightToolDraft) -> Bool {
        draft.input == input && draft.optionSelections == optionSelections
    }
}
