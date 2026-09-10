import Foundation

extension OpenColorPickerAction {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "color",
            symbolName: "paintpalette",
            inputKind: .none,
            destination: .colorPicker
        )
    }
}
