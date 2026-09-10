import CryptoKit
import Foundation

public enum HashAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha256
    case sha512

    public var displayName: String {
        switch self {
        case .sha256: "SHA-256"
        case .sha512: "SHA-512"
        }
    }
}

/// Hashes UTF-8 text.
///
/// The digest is written as lowercase hexadecimal, which is what other tools
/// expect when comparing hashes.
public struct HashTextAction: ActionHandler {
    public static let algorithmParameterName = "algorithm"

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.hashText,
        title: "Hash Text",
        summary: "Compute a SHA-256 or SHA-512 digest of UTF-8 text",
        isIdempotent: true
    )

    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "hash",
            symbolName: "number.square",
            inputKind: .text,
            destination: .result,
            options: [
                CommandOption(
                    parameterName: Self.algorithmParameterName,
                    title: "Algorithm",
                    choices: HashAlgorithm.allCases.map {
                        CommandOption.Choice(value: $0.rawValue, title: $0.displayName)
                    },
                    defaultValue: HashAlgorithm.sha256.rawValue
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

        let algorithm: HashAlgorithm
        switch request.parameters.values.count {
        case 0:
            algorithm = .sha256
        case 1:
            guard let raw = request.parameters[Self.algorithmParameterName] else {
                throw ToolActionError.unexpectedParameters
            }
            guard let parsed = HashAlgorithm(rawValue: raw) else {
                throw ToolActionError.invalidParameter(Self.algorithmParameterName)
            }
            algorithm = parsed
        default:
            throw ToolActionError.unexpectedParameters
        }

        let data = Data(request.input.utf8)
        let digest: String
        switch algorithm {
        case .sha256:
            digest = Self.hexadecimal(SHA256.hash(data: data))
        case .sha512:
            digest = Self.hexadecimal(SHA512.hash(data: data))
        }

        try Task.checkCancellation()
        return ActionOutput(
            summary: "\(algorithm.displayName) digest",
            detail: digest,
            value: .identifier(digest)
        )
    }

    private static func hexadecimal(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
