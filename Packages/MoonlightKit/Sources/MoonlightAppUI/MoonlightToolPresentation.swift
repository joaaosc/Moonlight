import MoonlightDomain

/// UI metadata for one tool. Domain actions stay platform agnostic; this is
/// the single adapter used by the palette, menu bar and future Spotlight UI.
public struct MoonlightToolPresentation: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let alias: String
    public let symbolName: String
    public let acceptsInput: Bool

    public init(descriptor: ActionDescriptor) {
        id = descriptor.id
        title = descriptor.title
        summary = descriptor.summary
        alias = Self.alias(for: descriptor)
        symbolName = Self.symbolName(for: descriptor)
        acceptsInput = Self.acceptsInput(descriptor)
    }

    private static func alias(for descriptor: ActionDescriptor) -> String {
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

    private static func symbolName(for descriptor: ActionDescriptor) -> String {
        switch descriptor.id {
        case MoonlightActionID.captureNote: "note.text"
        case MoonlightActionID.openColorPicker: "paintpalette"
        case MoonlightActionID.cleanText: "text.redact"
        case MoonlightActionID.formatJSON: "curlybraces"
        case MoonlightActionID.generateUUID: "number"
        case MoonlightActionID.base64Text: "a.square"
        default: "command"
        }
    }

    private static func acceptsInput(_ descriptor: ActionDescriptor) -> Bool {
        descriptor.id != MoonlightActionID.generateUUID &&
            descriptor.id != MoonlightActionID.openColorPicker
    }
}
