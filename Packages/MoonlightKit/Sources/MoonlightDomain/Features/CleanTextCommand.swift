import Foundation

extension CleanTextAction {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "clean",
            symbolName: "text.badge.checkmark",
            inputKind: .text,
            destination: .result
        )
    }
}
