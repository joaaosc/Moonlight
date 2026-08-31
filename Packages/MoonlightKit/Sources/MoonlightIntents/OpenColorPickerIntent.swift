import AppIntents
import MoonlightDomain

public struct OpenColorPickerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Color Picker"
    public static let description = IntentDescription(
        "Opens the system color panel in Moonlight."
    )
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Open the Moonlight color picker")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.execute(
            actionID: MoonlightActionID.openColorPicker,
            input: ""
        )

        await foregroundClient.presentColorPicker()

        return .result(
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
