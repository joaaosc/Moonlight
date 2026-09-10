import Foundation

extension TransformBase64Action {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "base64",
            symbolName: "textformat.abc",
            inputKind: .base64,
            destination: .result
        )
    }
}
