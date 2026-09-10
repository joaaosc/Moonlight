import Foundation

extension TransformBase64Action {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "base64",
            symbolName: "textformat.abc",
            inputKind: .text,
            destination: .result,
            options: [
                CommandOption(
                    parameterName: Self.operationParameterName,
                    title: "Operation",
                    choices: [
                        CommandOption.Choice(
                            value: Base64TextOperation.encode.rawValue,
                            title: "Encode"
                        ),
                        CommandOption.Choice(
                            value: Base64TextOperation.decode.rawValue,
                            title: "Decode"
                        ),
                    ],
                    defaultValue: Base64TextOperation.encode.rawValue
                ),
            ]
        )
    }
}
