import AppIntents
import MoonlightDomain

/// Text tools exposed to Spotlight and Shortcuts.
///
/// Each one returns its typed value, so the next action in a shortcut receives
/// the result instead of a rendered sentence. The snippet is fetched by
/// execution identifier: redrawing it never runs the command again.

public struct CleanTextIntent: AppIntent {
    public static let title: LocalizedStringResource = "Clean Text"
    public static let description = IntentDescription(
        "Normalizes Unicode and trims surrounding whitespace."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(title: "Text", requestValueDialog: "Which text should Moonlight clean?")
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Clean \(\.$text)")
    }

    public init() {}

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.cleanText,
            input: text
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "Text cleaned.",
                systemImageName: "text.badge.checkmark"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}

public struct GenerateUUIDIntent: AppIntent {
    public static let title: LocalizedStringResource = "Generate UUID"
    public static let description = IntentDescription(
        "Generates a random version 4 UUID."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    public static var parameterSummary: some ParameterSummary {
        Summary("Generate a UUID with Moonlight")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.generateUUID,
            input: ""
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "\(execution.detail)",
                systemImageName: "number"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}

public struct TransformBase64Intent: AppIntent {
    public static let title: LocalizedStringResource = "Encode or Decode Base64"
    public static let description = IntentDescription(
        "Encodes UTF-8 text as Base64, or decodes it back."
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
    public var operation: Base64OperationAppEnum

    public static var parameterSummary: some ParameterSummary {
        Summary("\(\.$operation) \(\.$text) with Base64")
    }

    public init() {}

    public init(text: String, operation: Base64OperationAppEnum) {
        self.text = text
        self.operation = operation
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.base64Text,
            input: text,
            parameters: ActionParameters(
                values: [
                    TransformBase64Action.operationParameterName: operation.operation.rawValue,
                ]
            )
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "\(execution.summary).",
                systemImageName: "arrow.left.arrow.right"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}

public enum Base64OperationAppEnum: String, AppEnum {
    case encode
    case decode

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Base64 Operation"
    )
    public static let caseDisplayRepresentations: [Base64OperationAppEnum: DisplayRepresentation] = [
        .encode: "Encode",
        .decode: "Decode",
    ]

    public var operation: Base64TextOperation {
        switch self {
        case .encode: .encode
        case .decode: .decode
        }
    }
}
