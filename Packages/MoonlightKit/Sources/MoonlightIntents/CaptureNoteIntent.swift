import AppIntents
import MoonlightDomain

public struct CaptureNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture Note"
    public static let description = IntentDescription(
        "Saves short text in Moonlight."
    )
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "Text",
        requestValueDialog: "What text should Moonlight capture?"
    )
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Capture a note with \(\.$text)")
    }

    public init() {}

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.execute(
            actionID: MoonlightActionID.captureNote,
            input: text
        )

        return .result(
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
