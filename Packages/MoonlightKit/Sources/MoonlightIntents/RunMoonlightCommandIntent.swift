import AppIntents
import MoonlightDomain

public struct RunMoonlightCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Legacy Moonlight Command"
    public static let description = IntentDescription(
        "Runs a text command saved by an earlier Moonlight build."
    )
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [
        .background,
        .foreground(.dynamic),
    ]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(
        title: "Command",
        requestValueDialog: "What should Moonlight do?"
    )
    public var command: String

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Run Moonlight with \(\.$command)")
    }

    public init() {}

    public init(command: String) {
        self.command = command
    }

    public func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let parsedCommand = try MoonlightCommandParser().parse(command)
        let execution: Execution

        switch parsedCommand {
        case let .captureNote(text):
            execution = try await MoonlightIntentExecutor.execute(
                actionID: MoonlightActionID.captureNote,
                input: text
            )
        case .openColorPicker:
            execution = try await MoonlightIntentExecutor.execute(
                actionID: MoonlightActionID.openColorPicker,
                input: ""
            )

            if systemContext.currentMode.canContinueInForeground {
                try await continueInForeground(alwaysConfirm: false)
            }
            await foregroundClient.presentColorPicker()
        }

        return .result(
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
