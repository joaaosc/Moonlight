import Foundation

public struct MoonlightForegroundClient: Sendable {
    private let presentColorPickerAction: @MainActor @Sendable () -> Void
    private let presentToolPaletteAction: @MainActor @Sendable (String?) -> Void
    private let copyToPasteboardAction: @MainActor @Sendable (String) -> Void
    private let presentNotesAction: @MainActor @Sendable (String, UUID?) -> Void
    private let presentCommandLineAction: @MainActor @Sendable (String) -> Void

    public init(
        presentColorPicker: @escaping @MainActor @Sendable () -> Void,
        presentToolPalette: @escaping @MainActor @Sendable (String?) -> Void = { _ in },
        copyToPasteboard: @escaping @MainActor @Sendable (String) -> Void = { _ in },
        presentNotes: @escaping @MainActor @Sendable (String, UUID?) -> Void = { _, _ in },
        presentCommandLine: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) {
        presentColorPickerAction = presentColorPicker
        presentToolPaletteAction = presentToolPalette
        copyToPasteboardAction = copyToPasteboard
        presentNotesAction = presentNotes
        presentCommandLineAction = presentCommandLine
    }

    /// Opens the palette on a command the user already typed.
    @MainActor
    public func presentCommandLine(_ text: String) {
        presentCommandLineAction(text)
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
