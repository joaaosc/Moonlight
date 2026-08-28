import AppIntents

public struct ExecuteActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Moonlight Action"
    public static let description = IntentDescription(
        "Runs a Moonlight action and presents its result."
    )
    public static let isDiscoverable = false
    public static var supportedModes: IntentModes { [.background] }
    public static var supportedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Action")
    public var action: ActionEntity

    @Parameter(title: "Text", inputOptions: .init(multiline: true))
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$action) with \(\.$text)")
    }

    public init() {}

    public init(action: ActionEntity, text: String) {
        self.action = action
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ExecutionEntity> & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.execute(
            actionID: action.id,
            input: text
        )
        return .result(
            value: execution,
            snippetIntent: ExecutionSnippetIntent(execution: execution)
        )
    }
}
