import AppIntents
import MoonlightDomain

public struct OpenMoonlightToolIntent: OpenIntent {
    /// Spotlight builds its shorthand from the initials of this title, and
    /// "Open Tool" produced the same `omt` as `OpenMoonlightIntent` — two rows
    /// in Spotlight carrying one badge. This one runs a named tool; the other
    /// opens the catalogue, so the title says which.
    public static let title: LocalizedStringResource = "Run Moonlight Tool"
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Tool")
    public var target: MoonlightToolEntity

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    public init() {}

    public init(target: MoonlightToolEntity) {
        self.target = target
    }

    public func perform() async throws -> some IntentResult {
        if target.id == MoonlightActionID.openColorPicker {
            _ = try await OpenColorPickerIntent().perform()
        } else {
            await foregroundClient.presentToolPalette(actionID: target.id)
        }
        return .result()
    }
}
