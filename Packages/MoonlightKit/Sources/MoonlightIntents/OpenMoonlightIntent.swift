import AppIntents

public struct OpenMoonlightIntent: AppIntent {
    public static let title: LocalizedStringResource = "Moonlight"
    public static let isDiscoverable = false
    public static let description = IntentDescription(
        "Opens Moonlight's tool palette."
    )
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Open Moonlight tools")
    }

    public init() {}

    public func perform() async throws -> some IntentResult {
        await foregroundClient.presentToolPalette(actionID: nil)
        return .result()
    }
}
