import AppIntents
import MoonlightDomain

public struct RunMoonlightCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Moonlight"
    public static let description = IntentDescription(
        "Runs a Moonlight tool from one text command. Try ‘note Buy milk’ or ‘color’."
    )
    public static let supportedModes: IntentModes = [
        .background,
        .foreground(.dynamic),
    ]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

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
