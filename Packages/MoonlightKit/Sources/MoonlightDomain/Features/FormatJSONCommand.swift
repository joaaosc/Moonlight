import Foundation

extension FormatJSONAction {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "json",
            symbolName: "curlybraces",
            inputKind: .text,
            destination: .result
        )
    }
}
