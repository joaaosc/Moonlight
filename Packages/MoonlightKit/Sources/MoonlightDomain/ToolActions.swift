import Foundation

public enum MoonlightToolLimits {
    public static let maximumInputByteCount = 256 * 1_024
    public static let maximumOutputByteCount = 512 * 1_024
    public static let maximumJSONNestingDepth = 64
}

public enum Base64TextOperation: String, Codable, CaseIterable, Sendable {
    case encode
    case decode
}

public extension ActionRequest {
    static func transformBase64(
        input: String,
        operation: Base64TextOperation
    ) -> Self {
        Self(
            actionID: MoonlightActionID.base64Text,
            input: input,
            parameters: ActionParameters(
                values: [TransformBase64Action.operationParameterName: operation.rawValue]
            )
        )
    }
}

public enum ToolActionError: Error, Equatable, LocalizedError, Sendable {
    case unexpectedInput
    case unexpectedParameters
    case missingParameter(String)
    case invalidParameter(String)
    case invalidJSON
    case jsonRootMustBeContainer
    case jsonTooDeep(limit: Int)
    case invalidBase64
    case decodedTextIsNotUTF8

    public var errorDescription: String? {
        switch self {
        case .unexpectedInput:
            "This action does not accept text input."
        case .unexpectedParameters:
            "This action received parameters it does not support."
        case let .missingParameter(name):
            "The action is missing the \(name) parameter."
        case let .invalidParameter(name):
            "The \(name) parameter has an unsupported value."
        case .invalidJSON:
            "Enter valid JSON."
        case .jsonRootMustBeContainer:
            "JSON must have an object or array at its top level."
        case let .jsonTooDeep(limit):
            "JSON must contain at most \(limit) nested container levels."
        case .invalidBase64:
            "Enter valid Base64 without spaces or line breaks."
        case .decodedTextIsNotUTF8:
            "The Base64 value contains binary data, not UTF-8 text."
        }
    }
}

public struct CleanTextAction: ActionHandler {
    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.cleanText,
        title: "Clean Text",
        summary: "Normalize Unicode and trim surrounding whitespace",
        isIdempotent: true
    )

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        try ToolActionValidation.requireNoParameters(request.parameters)
        try ToolActionValidation.checkInputSize(request.input)

        let output = request.input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw ActionError.emptyInput
        }

        try ToolActionValidation.checkOutputSize(output)
        try Task.checkCancellation()

        return ActionOutput(summary: "Text cleaned", detail: output)
    }
}

public struct FormatJSONAction: ActionHandler {
    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.formatJSON,
        title: "Format JSON",
        summary: "Validate and format a JSON object or array",
        isIdempotent: true
    )

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        try ToolActionValidation.requireNoParameters(request.parameters)
        try ToolActionValidation.checkInputSize(request.input)

        guard !request.input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else {
            throw ActionError.emptyInput
        }
        guard !ToolActionValidation.containsTrailingJSONComma(request.input) else {
            throw ToolActionError.invalidJSON
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(
                with: Data(request.input.utf8),
                options: [.fragmentsAllowed]
            )
        } catch {
            throw ToolActionError.invalidJSON
        }

        guard jsonObject is [Any] || jsonObject is [String: Any] else {
            throw ToolActionError.jsonRootMustBeContainer
        }
        guard JSONSerialization.isValidJSONObject(jsonObject) else {
            throw ToolActionError.invalidJSON
        }
        try ToolActionValidation.checkJSONDepth(jsonObject)

        try Task.checkCancellation()

        let outputData: Data
        do {
            outputData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
        } catch {
            throw ToolActionError.invalidJSON
        }

        try ToolActionValidation.checkOutputSize(outputData.count)
        try Task.checkCancellation()

        return ActionOutput(
            summary: "JSON formatted",
            detail: String(decoding: outputData, as: UTF8.self)
        )
    }
}

public struct GenerateUUIDAction: ActionHandler {
    public typealias Generator = @Sendable () -> UUID

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.generateUUID,
        title: "Generate UUID",
        summary: "Generate a random version 4 UUID"
    )

    private let generator: Generator

    public init(generator: @escaping Generator = UUID.init) {
        self.generator = generator
    }

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        try ToolActionValidation.requireNoParameters(request.parameters)
        try ToolActionValidation.checkInputSize(request.input)

        guard request.input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else {
            throw ToolActionError.unexpectedInput
        }

        let output = generator().uuidString.lowercased()
        try ToolActionValidation.checkOutputSize(output)
        try Task.checkCancellation()

        return ActionOutput(summary: "UUID generated", detail: output)
    }
}

public struct TransformBase64Action: ActionHandler {
    public static let operationParameterName = "operation"

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.base64Text,
        title: "Base64",
        summary: "Encode or decode UTF-8 text with Base64",
        isIdempotent: true
    )

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        try ToolActionValidation.checkInputSize(request.input)

        guard let rawOperation = request.parameters[Self.operationParameterName] else {
            throw ToolActionError.missingParameter(Self.operationParameterName)
        }
        guard request.parameters.values.count == 1 else {
            throw ToolActionError.unexpectedParameters
        }
        guard let operation = Base64TextOperation(rawValue: rawOperation) else {
            throw ToolActionError.invalidParameter(Self.operationParameterName)
        }

        switch operation {
        case .encode:
            let output = Data(request.input.utf8).base64EncodedString()
            try ToolActionValidation.checkOutputSize(output)
            try Task.checkCancellation()
            return ActionOutput(summary: "Text encoded as Base64", detail: output)

        case .decode:
            guard let decodedData = Data(
                base64Encoded: request.input,
                options: []
            ), decodedData.base64EncodedString() == request.input else {
                throw ToolActionError.invalidBase64
            }
            try ToolActionValidation.checkOutputSize(decodedData.count)
            guard let output = String(data: decodedData, encoding: .utf8) else {
                throw ToolActionError.decodedTextIsNotUTF8
            }
            try Task.checkCancellation()
            return ActionOutput(summary: "Base64 decoded", detail: output)
        }
    }
}

private enum ToolActionValidation {
    static func requireNoParameters(_ parameters: ActionParameters) throws {
        guard parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }
    }

    static func checkInputSize(_ input: String) throws {
        guard input.utf8.count <= MoonlightToolLimits.maximumInputByteCount else {
            throw ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            )
        }
    }

    static func checkOutputSize(_ output: String) throws {
        try checkOutputSize(output.utf8.count)
    }

    static func checkOutputSize(_ byteCount: Int) throws {
        guard byteCount <= MoonlightToolLimits.maximumOutputByteCount else {
            throw ActionError.outputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumOutputByteCount
            )
        }
    }

    static func checkJSONDepth(_ value: Any, depth: Int = 0) throws {
        try Task.checkCancellation()

        if let array = value as? [Any] {
            let nextDepth = depth + 1
            guard nextDepth <= MoonlightToolLimits.maximumJSONNestingDepth else {
                throw ToolActionError.jsonTooDeep(
                    limit: MoonlightToolLimits.maximumJSONNestingDepth
                )
            }
            for element in array {
                try checkJSONDepth(element, depth: nextDepth)
            }
        } else if let dictionary = value as? [String: Any] {
            let nextDepth = depth + 1
            guard nextDepth <= MoonlightToolLimits.maximumJSONNestingDepth else {
                throw ToolActionError.jsonTooDeep(
                    limit: MoonlightToolLimits.maximumJSONNestingDepth
                )
            }
            for element in dictionary.values {
                try checkJSONDepth(element, depth: nextDepth)
            }
        }
    }

    static func containsTrailingJSONComma(_ input: String) -> Bool {
        let bytes = Array(input.utf8)
        var isInsideString = false
        var isEscaped = false
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if byte == 0x5C {
                    isEscaped = true
                } else if byte == 0x22 {
                    isInsideString = false
                }
            } else if byte == 0x22 {
                isInsideString = true
            } else if byte == 0x2C {
                var lookahead = index + 1
                while lookahead < bytes.count, isJSONWhitespace(bytes[lookahead]) {
                    lookahead += 1
                }
                if lookahead < bytes.count,
                   bytes[lookahead] == 0x7D || bytes[lookahead] == 0x5D
                {
                    return true
                }
            }

            index += 1
        }

        return false
    }

    private static func isJSONWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}
