import AppIntents
import MoonlightDomain

/// Starts a countdown from a typed duration.
///
/// Published like every other text tool (background, ReturnsValue +
/// ProvidesDialog + Snippet por executionID): the parsing lives in the domain
/// as a registered action, so the tool reaches Spotlight as an indexed entity
/// and its runs land in the execution history. The ticking itself belongs to
/// the UI (`MinimalTimerView`); this type only records the start.
public struct StartTimerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Timer"
    public static let description = IntentDescription(
        "Starts a countdown from a duration like 25m, 90s or 1:30."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "Duration",
        requestValueDialog: "How long should the timer run? Try 25m, 90s or 1:30."
    )
    public var duration: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$duration) timer")
    }

    public init() {}

    public init(duration: String) {
        self.duration = duration
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: MoonlightActionID.startTimer,
            input: duration
        )
        return .result(
            value: execution.resolvedOutput.value.text ?? execution.detail,
            dialog: IntentDialog(
                full: "\(execution.detail).",
                systemImageName: "timer"
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
