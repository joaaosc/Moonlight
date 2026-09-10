import Foundation

public enum URLTextOperation: String, Codable, CaseIterable, Sendable {
    case encode
    case decode
}

/// Percent-encodes or decodes text for use inside a URL.
///
/// Encoding escapes every character outside the unreserved set of RFC 3986, so
/// the result is safe in a path or a query value.
public struct TransformURLAction: ActionHandler {
    public static let operationParameterName = "operation"

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.urlText,
        title: "URL Encode",
        summary: "Percent-encode or decode text for a URL",
        isIdempotent: false
    )

    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "url",
            symbolName: "link.badge.plus",
            inputKind: .text,
            destination: .result,
            options: [
                CommandOption(
                    parameterName: Self.operationParameterName,
                    title: "Operation",
                    choices: [
                        CommandOption.Choice(
                            value: URLTextOperation.encode.rawValue,
                            title: "Encode"
                        ),
                        CommandOption.Choice(
                            value: URLTextOperation.decode.rawValue,
                            title: "Decode"
                        ),
                    ],
                    defaultValue: URLTextOperation.encode.rawValue
                ),
            ]
        )
    }

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.input.utf8.count <= MoonlightToolLimits.maximumInputByteCount else {
            throw ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            )
        }
        guard !request.input.isEmpty else {
            throw ActionError.emptyInput
        }
        guard let raw = request.parameters[Self.operationParameterName] else {
            throw ToolActionError.missingParameter(Self.operationParameterName)
        }
        guard request.parameters.values.count == 1 else {
            throw ToolActionError.unexpectedParameters
        }
        guard let operation = URLTextOperation(rawValue: raw) else {
            throw ToolActionError.invalidParameter(Self.operationParameterName)
        }

        let output: String
        switch operation {
        case .encode:
            guard let encoded = request.input.addingPercentEncoding(
                withAllowedCharacters: Self.unreserved
            ) else {
                throw ToolActionError.invalidParameter(Self.operationParameterName)
            }
            output = encoded
        case .decode:
            guard let decoded = request.input.removingPercentEncoding else {
                // Not a failure of the tool: the text is not valid encoding.
                throw ToolActionError.invalidPercentEncoding
            }
            output = decoded
        }

        guard output.utf8.count <= MoonlightToolLimits.maximumOutputByteCount else {
            throw ActionError.outputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumOutputByteCount
            )
        }
        try Task.checkCancellation()

        return ActionOutput(
            summary: operation == .encode ? "Text URL-encoded" : "Text URL-decoded",
            detail: output,
            value: .text(output)
        )
    }
}
