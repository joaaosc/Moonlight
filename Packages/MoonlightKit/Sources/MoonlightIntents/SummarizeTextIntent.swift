import AppIntents
import MoonlightDomain

/// Shortens text to its opening sentences.
///
/// Published like every other text tool: the work lives in the domain as a
/// registered action, and this type only carries it to Spotlight, Shortcuts
/// and Siri. That is what the summary needed to become — an intent that
/// implements its own logic reaches Shortcuts but never the tool catalogue, so
/// it never appears in Spotlight as a Moonlight tool, and its runs are absent
/// from the history every other tool writes to.
public struct SummarizeTextIntent: AppIntent {
    public static let title: LocalizedStringResource = "Summarize Text"
    public static let description = IntentDescription(
        "Shortens text to its opening sentences."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "Text",
        requestValueDialog: "Which text should Moonlight summarize?"
    )
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Summarize \(\.$text)")
    }

    public init() {}

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.summarizeText,
            input: text
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "Text summarized.",
                systemImageName: "text.quote"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
