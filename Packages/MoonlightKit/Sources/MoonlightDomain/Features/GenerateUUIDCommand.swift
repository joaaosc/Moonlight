import Foundation

extension GenerateUUIDAction {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "uuid",
            symbolName: "number",
            inputKind: .none,
            destination: .result
        )
    }
}
