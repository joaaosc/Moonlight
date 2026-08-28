#if DEBUG
import AppIntents

public struct PresentColorPickerForTestingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Present Color Picker for Testing"
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public init() {}

    public func perform() async throws -> some IntentResult {
        await foregroundClient.presentColorPicker()
        return .result()
    }
}
#endif
