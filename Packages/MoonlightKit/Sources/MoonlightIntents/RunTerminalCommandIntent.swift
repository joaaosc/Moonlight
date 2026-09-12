import AppIntents
import MoonlightDomain

/// Runs one of the user's saved terminal commands in Terminal.
///
/// A single static intent parameterized by a dynamic entity: Moonlight does not
/// generate an intent per command, and the target is always explicit, so a
/// script is never picked by guesswork. Mirrors `RunUserShortcutIntent`: the
/// execution records the resolved script, and the host presents it — here by
/// opening Terminal, the way `OpenColorPickerIntent` presents the color panel
/// instead of returning pixels.
public struct RunTerminalCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Terminal Command"
    public static let description = IntentDescription(
        "Runs a terminal command saved in Moonlight."
    )
    public static let isDiscoverable = true
    public static let supportedModes: IntentModes = [.background]
    /// Opening Terminal needs a `.command` file and Launch Services, which
    /// only the app process may do.
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Command", requestValueDialog: "Which terminal command?")
    public var command: MoonlightToolEntity

    @Parameter(title: "Input")
    public var input: String?

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Run terminal command \(\.$command) with \(\.$input)")
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
        if let script = output.value.text, !script.isEmpty {
            await foregroundClient.runTerminalScript(script)
        }
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
