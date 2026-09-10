import AppIntents
import MoonlightDomain

/// Moonlight's typed command line, reachable from Spotlight.
///
/// The title matters: Spotlight builds its shorthand from it, so `omc` is the
/// initials of this action and not a string configured anywhere. The single
/// text parameter is what gives the Spotlight result its Tab-to-type field.
public struct OpenMoonlightCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Moonlight Command"
    public static let isDiscoverable = true
    public static let description = IntentDescription(
        "Runs a Moonlight command, typed as /name."
    )
    // Dynamic: an unpublished command still has to reach the palette, and that
    // is a foreground presentation the extension cannot perform.
    public static let supportedModes: IntentModes = [.foreground(.dynamic)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(
        title: "Command",
        requestValueDialog: "Which command? Commands start with a slash, like /note."
    )
    public var command: String

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$command)")
    }

    public init() {}

    public init(command: String) {
        self.command = command
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // A malformed command throws here and is reported as a syntax problem.
        // Only a well formed command reaches the catalogue, so "you typed it
        // wrong" and "that command does not exist" stay separate answers.
        let parsed = try SlashCommandParser().parse(command)

        if systemContext.currentMode.canContinueInForeground {
            try await continueInForeground(alwaysConfirm: false)
        }

        guard let definition = SlashCommandRegistry.definition(named: parsed.name) else {
            // Nothing is published yet, so every command lands here. The text is
            // handed to the palette rather than dropped: the user keeps what
            // they typed and can finish the job by hand.
            await foregroundClient.presentCommandLine(parsed.typedText)
            return .result(
                dialog: IntentDialog(
                    full: "Moonlight has no \(parsed.typedText) command yet.",
                    systemImageName: "questionmark.circle"
                )
            )
        }

        // Reached once a command is registered. Handing the parsed command to
        // the palette is the placeholder route; a published command replaces
        // this with its own execution.
        await foregroundClient.presentCommandLine(parsed.typedText)
        return .result(
            dialog: IntentDialog(
                full: "\(definition.summary)",
                systemImageName: "command"
            )
        )
    }
}
