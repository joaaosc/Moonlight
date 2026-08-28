import AppIntents
import MoonlightDomain
import MoonlightInfrastructure
import MoonlightIntents
import Testing

@Suite("App Intents adapters")
struct AppIntentsAdapterTests {
    @Test("Execution presentation is a hidden extension snippet intent")
    func snippetContract() {
        requireSnippetIntent(ExecutionSnippetIntent.self)
        #expect(!ExecutionSnippetIntent.isDiscoverable)
        #expect(ExecutionSnippetIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(!ExecutionSnippetIntent.allowedExecutionTargets.contains(.main))
    }

    @Test("Moonlight command is the single public foreground-capable intent")
    func moonlightCommandContract() {
        requireAppIntent(RunMoonlightCommandIntent.self)
        #expect(RunMoonlightCommandIntent.isDiscoverable)
        #expect(RunMoonlightCommandIntent.supportedModes.contains(.background))
        #expect(RunMoonlightCommandIntent.supportedModes.contains(.foreground(.dynamic)))
        #expect(RunMoonlightCommandIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(RunMoonlightCommandIntent.allowedExecutionTargets.contains(.main))
    }

    @Test("Foreground client forwards color picker presentation on the main actor")
    @MainActor
    func foregroundClientContract() {
        let probe = PresentationProbe()
        let client = MoonlightForegroundClient {
            probe.presentationCount += 1
        }

        client.presentColorPicker()

        #expect(probe.presentationCount == 1)
    }

#if DEBUG
    @Test("Color picker test intent remains hidden and main-process only")
    func colorPickerTestIntentContract() {
        requireAppIntent(PresentColorPickerForTestingIntent.self)
        #expect(!PresentColorPickerForTestingIntent.isDiscoverable)
        #expect(PresentColorPickerForTestingIntent.allowedExecutionTargets.contains(.main))
        #expect(!PresentColorPickerForTestingIntent.allowedExecutionTargets.contains(.appIntentsExtension))
    }
#endif
}

@MainActor
private final class PresentationProbe {
    var presentationCount = 0
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
