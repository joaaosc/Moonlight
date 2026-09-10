public struct MoonlightForegroundClient: Sendable {
    private let presentColorPickerAction: @MainActor @Sendable () -> Void
    private let presentToolPaletteAction: @MainActor @Sendable (String?) -> Void
    private let copyToPasteboardAction: @MainActor @Sendable (String) -> Void

    public init(
        presentColorPicker: @escaping @MainActor @Sendable () -> Void,
        presentToolPalette: @escaping @MainActor @Sendable (String?) -> Void = { _ in },
        copyToPasteboard: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) {
        presentColorPickerAction = presentColorPicker
        presentToolPaletteAction = presentToolPalette
        copyToPasteboardAction = copyToPasteboard
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
