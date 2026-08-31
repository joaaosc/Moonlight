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

    @Test("Capture Note is a discoverable background intent")
    func captureNoteContract() {
        requireAppIntent(CaptureNoteIntent.self)
        #expect(CaptureNoteIntent.isDiscoverable)
        #expect(CaptureNoteIntent.supportedModes.contains(.background))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.main))
    }

    @Test("Open Color Picker is a discoverable main-process foreground intent")
    func openColorPickerContract() {
        requireAppIntent(OpenColorPickerIntent.self)
        #expect(OpenColorPickerIntent.isDiscoverable)
        #expect(OpenColorPickerIntent.supportedModes.contains(.foreground(.immediate)))
        #expect(OpenColorPickerIntent.allowedExecutionTargets.contains(.main))
        #expect(!OpenColorPickerIntent.allowedExecutionTargets.contains(.appIntentsExtension))
    }

    @Test("Legacy Moonlight command remains executable but not discoverable")
    func legacyCommandContract() {
        let legacy = RunMoonlightCommandIntent(command: "note Buy milk")

        requireAppIntent(RunMoonlightCommandIntent.self)
        #expect(!RunMoonlightCommandIntent.isDiscoverable)
        #expect(RunMoonlightCommandIntent.allowedExecutionTargets.contains(.main))
        #expect(!RunMoonlightCommandIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(legacy.command == "note Buy milk")
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

}

@MainActor
private final class PresentationProbe {
    var presentationCount = 0
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
