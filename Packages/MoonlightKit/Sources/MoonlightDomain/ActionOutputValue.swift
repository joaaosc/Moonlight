import Foundation

/// The typed payload of a command result.
///
/// `ActionOutput.detail` remains the rendered string, so records written by
/// earlier builds keep working. The value tells a renderer what that string
/// means without inspecting the tool ID, which is what let presentation code
/// grow switches over identifiers.
public enum ActionOutputValue: Equatable, Sendable {
    /// The command produced no value to show, only a confirmation.
    case none
    case text(String)
    case json(String)
    case identifier(String)

    /// The value as text, when the command produced one.
    public var text: String? {
        switch self {
        case .none: nil
        case let .text(value), let .json(value), let .identifier(value): value
        }
    }
}

extension ActionOutputValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case text
    }

    /// Stable on-disk tags. Renaming a Swift case must not rewrite history.
    private enum Kind: String, Codable {
        case none
        case text
        case json
        case identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none:
            self = .none
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .json:
            self = .json(try container.decode(String.self, forKey: .text))
        case .identifier:
            self = .identifier(try container.decode(String.self, forKey: .text))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case let .text(value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .text)
        case let .json(value):
            try container.encode(Kind.json, forKey: .kind)
            try container.encode(value, forKey: .text)
        case let .identifier(value):
            try container.encode(Kind.identifier, forKey: .kind)
            try container.encode(value, forKey: .text)
        }
    }
}

/// A failure recorded with a stable code, so callers stop matching localized
/// strings to decide what went wrong.
public struct ExecutionFailure: Codable, Equatable, Sendable {
    /// Used for records written before failures carried a code, and for errors
    /// outside the Moonlight domain.
    public static let unknownCode = "unknown"

    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    public init(error: any Error) {
        self.code = (error as? any CodedActionError)?.failureCode ?? Self.unknownCode
        self.message = error.localizedDescription
    }
}

/// An error that identifies itself with a stable, non-localized code.
public protocol CodedActionError: Error {
    var failureCode: String { get }
}

extension ActionError: CodedActionError {
    public var failureCode: String {
        switch self {
        case .emptyInput: "empty-input"
        case .inputTooLong: "input-too-long"
        case .inputTooLarge: "input-too-large"
        case .outputTooLarge: "output-too-large"
        case .unsupportedParameterSchema: "unsupported-parameter-schema"
        case .unknownAction: "unknown-action"
        }
    }
}

extension ToolActionError: CodedActionError {
    public var failureCode: String {
        switch self {
        case .unexpectedInput: "unexpected-input"
        case .unexpectedParameters: "unexpected-parameters"
        case .missingParameter: "missing-parameter"
        case .invalidParameter: "invalid-parameter"
        case .invalidJSON: "invalid-json"
        case .jsonRootMustBeContainer: "json-root-must-be-container"
        case .jsonTooDeep: "json-too-deep"
        case .invalidBase64: "invalid-base64"
        case .decodedTextIsNotUTF8: "decoded-text-not-utf8"
        case .invalidPercentEncoding: "invalid-percent-encoding"
        case .invalidTimestamp: "invalid-timestamp"
        }
    }
}
