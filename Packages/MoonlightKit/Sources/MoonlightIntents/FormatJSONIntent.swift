import AppIntents
import MoonlightDomain

public struct FormatJSONIntent: AppIntent {
    public static let title: LocalizedStringResource = "Format JSON"
    public static let description = IntentDescription(
        "Validates and formats a JSON object or array."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "JSON",
        requestValueDialog: "What JSON should Moonlight format?"
    )
    public var json: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Format \(\.$json) as JSON")
    }

    public init() {}

    public init(json: String) {
        self.json = json
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.formatJSON,
            input: json
        )

        // The snippet is fetched by identifier, so redrawing it does not format
        // the JSON again or add a second execution to the history.
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "JSON formatted.",
                systemImageName: "curlybraces"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
