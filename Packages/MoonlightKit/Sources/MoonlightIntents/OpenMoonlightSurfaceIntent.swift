import AppIntents
import MoonlightDomain

/// The route Spotlight takes when the user picks a surface it found by alias.
public struct OpenMoonlightSurfaceIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Moonlight Surface"
    public static let isDiscoverable = true
    public static let description = IntentDescription(
        "Opens a Moonlight surface by its shorthand."
    )
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Surface")
    public var target: MoonlightSurfaceEntity

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    public init() {}

    public init(target: MoonlightSurfaceEntity) {
        self.target = target
    }

    public func perform() async throws -> some IntentResult {
        switch target.id {
        case MoonlightSurfaceID.tools:
            await foregroundClient.presentToolPalette(actionID: nil)
        case MoonlightSurfaceID.window:
            await foregroundClient.presentWindow()
        case MoonlightSurfaceID.launcher:
            await foregroundClient.presentLauncher()
        default:
            // An identifier the index still carries but this build no longer
            // publishes: fall back to the palette rather than doing nothing.
            await foregroundClient.presentToolPalette(actionID: nil)
        }
        return .result()
    }
}
