import AppIntents
import MoonlightDomain

/// Hash, URL e timestamp expostos ao Spotlight/Shortcuts.
///
/// Seguem o mesmo contrato dos demais text tools (background,
/// ReturnsValue + ProvidesDialog + Snippet por executionID), conforme
/// `AppIntent` em https://sosumi.ai/documentation/appintents/appintent
/// e o padrão de `ToolTextIntents.swift`.

public enum HashAlgorithmAppEnum: String, AppEnum {
    case sha256
    case sha512

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Hash Algorithm"
    )
    public static let caseDisplayRepresentations: [HashAlgorithmAppEnum: DisplayRepresentation] = [
        .sha256: "SHA-256",
        .sha512: "SHA-512",
    ]

    public var algorithm: HashAlgorithm {
        switch self {
        case .sha256: .sha256
        case .sha512: .sha512
        }
    }
}

public struct HashTextIntent: AppIntent {
    public static let title: LocalizedStringResource = "Hash Text"
    public static let description = IntentDescription(
        "Computes a SHA-256 or SHA-512 digest of UTF-8 text."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(title: "Text", requestValueDialog: "Which text should Moonlight hash?")
    public var text: String

    @Parameter(title: "Algorithm", default: .sha256)
    public var algorithm: HashAlgorithmAppEnum

    public static var parameterSummary: some ParameterSummary {
        Summary("Hash \(\.$text) with \(\.$algorithm)")
    }

    public init() {}

    public init(text: String, algorithm: HashAlgorithmAppEnum = .sha256) {
        self.text = text
        self.algorithm = algorithm
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.hashText,
            input: text,
            parameters: ActionParameters(
                values: [
                    HashTextAction.algorithmParameterName: algorithm.algorithm.rawValue,
                ]
            )
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "\(execution.summary).",
                systemImageName: "lock.shield"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}

public enum URLOperationAppEnum: String, AppEnum {
    case encode
    case decode

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "URL Operation"
    )
    public static let caseDisplayRepresentations: [URLOperationAppEnum: DisplayRepresentation] = [
        .encode: "Encode",
        .decode: "Decode",
    ]

    public var operation: URLTextOperation {
        switch self {
        case .encode: .encode
        case .decode: .decode
        }
    }
}

public struct TransformURLIntent: AppIntent {
    public static let title: LocalizedStringResource = "Encode or Decode URL"
    public static let description = IntentDescription(
        "Percent-encodes text for a URL, or decodes it back."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(title: "Text", requestValueDialog: "Which text should Moonlight transform?")
    public var text: String

    @Parameter(title: "Operation", default: .encode)
    public var operation: URLOperationAppEnum

    public static var parameterSummary: some ParameterSummary {
        Summary("\(\.$operation) \(\.$text) for a URL")
    }

    public init() {}

    public init(text: String, operation: URLOperationAppEnum = .encode) {
        self.text = text
        self.operation = operation
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.urlText,
            input: text,
            parameters: ActionParameters(
                values: [
                    TransformURLAction.operationParameterName: operation.operation.rawValue,
                ]
            )
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "\(execution.summary).",
                systemImageName: "link"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}

public struct ConvertTimestampIntent: AppIntent {
    public static let title: LocalizedStringResource = "Convert Timestamp"
    public static let description = IntentDescription(
        "Converts between Unix timestamps and ISO-8601 dates."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "Timestamp or Date",
        requestValueDialog: "Which timestamp or ISO-8601 date should Moonlight convert?"
    )
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$text) between timestamp and date")
    }

    public init() {}

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.convertTimestamp,
            input: text
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "Timestamp converted.",
                systemImageName: "clock.arrow.2.circlepath"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
