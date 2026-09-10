import AppIntents
import MoonlightDomain

/// Runs one of the user's registered shortcuts as a Moonlight command.
///
/// A single static intent parameterized by a dynamic entity: Moonlight does not
/// generate an intent per shortcut, and the target is always explicit, so a
/// shortcut is never picked by guesswork.
public struct RunUserShortcutIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Moonlight Command"
    public static let description = IntentDescription(
        "Runs a command registered in Moonlight, including your own shortcuts."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    /// Running a personal shortcut needs Apple Events, which only the app
    /// process may send.
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Command", requestValueDialog: "Which Moonlight command?")
    public var command: MoonlightToolEntity

    @Parameter(title: "Input")
    public var input: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$command) with \(\.$input)")
    }

    public init() {}

    public init(command: MoonlightToolEntity, input: String? = nil) {
        self.command = command
        self.input = input
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog & ShowsSnippetIntent {
        let execution = try await MoonlightIntentExecutor.succeeded(
            actionID: command.id,
            input: input ?? ""
        )

        let output = execution.resolvedOutput
        return .result(
            value: output.value.text ?? "",
            dialog: IntentDialog(
                full: "\(output.summary).",
                systemImageName: command.symbolName
            ),
            snippetIntent: ExecutionSnippetIntent(executionID: execution.id)
        )
    }
}
