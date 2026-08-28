import AppIntents
import MoonlightDomain

public struct CaptureNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture Note"
    public static let description = IntentDescription(
        "Saves a note in Moonlight and presents the result."
    )
    public static var supportedModes: IntentModes { [.background] }
    public static var supportedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "Text",
        inputOptions: .init(multiline: true),
        requestValueDialog: "What should Moonlight capture?"
    )
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$text)")
    }

    public init() {}

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ExecutionEntity> & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.execute(
            actionID: MoonlightActionID.captureNote,
            input: text
        )
        return .result(
            value: execution,
            snippetIntent: ExecutionSnippetIntent(execution: execution)
        )
    }
}
