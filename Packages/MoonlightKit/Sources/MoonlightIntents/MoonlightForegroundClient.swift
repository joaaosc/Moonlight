public struct MoonlightForegroundClient: Sendable {
    private let presentColorPickerAction: @MainActor @Sendable () -> Void

    public init(
        presentColorPicker: @escaping @MainActor @Sendable () -> Void
    ) {
        presentColorPickerAction = presentColorPicker
    }

    @MainActor
    public func presentColorPicker() {
        presentColorPickerAction()
    }
}
