import AppIntents
import MoonlightDomain

public struct OpenMoonlightToolIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Moonlight Tool"
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
