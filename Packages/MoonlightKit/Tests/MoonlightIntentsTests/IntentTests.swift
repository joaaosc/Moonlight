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

    @Test("Capture Note executes independently in the App Intents extension")
    func captureNoteContract() {
        requireAppIntent(CaptureNoteIntent.self)
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(!CaptureNoteIntent.allowedExecutionTargets.contains(.main))
    }
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
