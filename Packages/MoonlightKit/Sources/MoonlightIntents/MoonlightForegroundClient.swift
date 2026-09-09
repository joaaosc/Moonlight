public struct MoonlightForegroundClient: Sendable {
    private let presentColorPickerAction: @MainActor @Sendable () -> Void
    private let presentToolPaletteAction: @MainActor @Sendable (String?) -> Void

    public init(
        presentColorPicker: @escaping @MainActor @Sendable () -> Void,
        presentToolPalette: @escaping @MainActor @Sendable (String?) -> Void = { _ in }
    ) {
        presentColorPickerAction = presentColorPicker
        presentToolPaletteAction = presentToolPalette
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
