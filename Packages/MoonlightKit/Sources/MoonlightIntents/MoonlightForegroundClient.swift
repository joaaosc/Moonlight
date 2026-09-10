import Foundation

public struct MoonlightForegroundClient: Sendable {
    private let presentColorPickerAction: @MainActor @Sendable () -> Void
    private let presentToolPaletteAction: @MainActor @Sendable (String?) -> Void
    private let copyToPasteboardAction: @MainActor @Sendable (String) -> Void
    private let presentNotesAction: @MainActor @Sendable (String, UUID?) -> Void

    public init(
        presentColorPicker: @escaping @MainActor @Sendable () -> Void,
        presentToolPalette: @escaping @MainActor @Sendable (String?) -> Void = { _ in },
        copyToPasteboard: @escaping @MainActor @Sendable (String) -> Void = { _ in },
        presentNotes: @escaping @MainActor @Sendable (String, UUID?) -> Void = { _, _ in }
    ) {
        presentColorPickerAction = presentColorPicker
        presentToolPaletteAction = presentToolPalette
        copyToPasteboardAction = copyToPasteboard
        presentNotesAction = presentNotes
    }

    /// Opens the notes section, optionally on a search or a specific note.
    @MainActor
    public func presentNotes(searchText: String = "", noteID: UUID? = nil) {
        presentNotesAction(searchText, noteID)
    }

    /// The pasteboard belongs to the host process; the extension cannot reach it.
    @MainActor
    public func copyToPasteboard(_ text: String) {
        copyToPasteboardAction(text)
    }

    @MainActor
    public func presentColorPicker() {
        presentColorPickerAction()
    }

    @MainActor
    public func presentToolPalette(actionID: String? = nil) {
        presentToolPaletteAction(actionID)
    }
}
