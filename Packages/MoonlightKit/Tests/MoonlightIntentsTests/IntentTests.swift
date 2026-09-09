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

    @Test("Capture Note remains executable but leaves discovery to the palette")
    func captureNoteContract() {
        requireAppIntent(CaptureNoteIntent.self)
        #expect(!CaptureNoteIntent.isDiscoverable)
        #expect(CaptureNoteIntent.supportedModes.contains(.background))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.main))
    }

    @Test("Format JSON remains executable but leaves Spotlight discovery to the palette")
    func formatJSONContract() {
        let intent = FormatJSONIntent(json: #"{"moonlight":true}"#)

        requireAppIntent(FormatJSONIntent.self)
        #expect(!FormatJSONIntent.isDiscoverable)
        #expect(FormatJSONIntent.supportedModes.contains(.background))
        #expect(FormatJSONIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(FormatJSONIntent.allowedExecutionTargets.contains(.main))
        #expect(intent.json == #"{"moonlight":true}"#)
    }

    @Test("Moonlight foreground route remains executable but is not a second public entry")
    func openMoonlightContract() {
        requireAppIntent(OpenMoonlightIntent.self)
        #expect(!OpenMoonlightIntent.isDiscoverable)
        #expect(OpenMoonlightIntent.supportedModes.contains(.foreground(.immediate)))
        #expect(OpenMoonlightIntent.allowedExecutionTargets.contains(.main))
        #expect(!OpenMoonlightIntent.allowedExecutionTargets.contains(.appIntentsExtension))
    }

    @Test("Moonlight tools are searchable entities with a system open route")
    func toolEntityContract() async throws {
        let entities = MoonlightToolEntityQuery.allEntities
        let query = MoonlightToolEntityQuery()

        requireOpenIntent(OpenMoonlightToolIntent.self)
        #expect(OpenMoonlightToolIntent.isDiscoverable)
        #expect(OpenMoonlightToolIntent.allowedExecutionTargets.contains(.main))
        #expect(!OpenMoonlightToolIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(entities.map(\.id) == ActionRegistry.standard.descriptors
            .sorted { $0.title < $1.title }
            .map(\.id))
        #expect(try await query.entities(matching: "json").map(\.id) == [MoonlightActionID.formatJSON])
        #expect(try await query.entities(for: [MoonlightActionID.generateUUID]).map(\.id) == [MoonlightActionID.generateUUID])
    }

    @Test("Open Color Picker is a direct foreground action")
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

    @Test("Foreground client forwards palette and color presentation on the main actor")
    @MainActor
    func foregroundClientContract() {
        let probe = PresentationProbe()
        let client = MoonlightForegroundClient(
            presentColorPicker: { probe.colorPresentationCount += 1 },
            presentToolPalette: {
                probe.palettePresentationCount += 1
                probe.presentedActionID = $0
            }
        )

        client.presentColorPicker()
        client.presentToolPalette(actionID: MoonlightActionID.formatJSON)

        #expect(probe.colorPresentationCount == 1)
        #expect(probe.palettePresentationCount == 1)
        #expect(probe.presentedActionID == MoonlightActionID.formatJSON)
    }

}

@MainActor
private final class PresentationProbe {
    var colorPresentationCount = 0
    var palettePresentationCount = 0
    var presentedActionID: String?
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
private func requireOpenIntent<T: OpenIntent>(_ type: T.Type) {}
