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

    @Test("Capture Note is published as a short curated action")
    func captureNoteContract() {
        requireAppIntent(CaptureNoteIntent.self)
        // Discovery is now deliberate: the curated provider is the public list.
        #expect(CaptureNoteIntent.isDiscoverable)
        #expect(CaptureNoteIntent.supportedModes.contains(.background))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(CaptureNoteIntent.allowedExecutionTargets.contains(.main))
    }

    @Test("Format JSON is published as a short curated action")
    func formatJSONContract() {
        let intent = FormatJSONIntent(json: #"{"moonlight":true}"#)

        requireAppIntent(FormatJSONIntent.self)
        #expect(FormatJSONIntent.isDiscoverable)
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

    @Test("Text tools return their value so a shortcut can chain them")
    func typedToolIntents() {
        requireAppIntent(CleanTextIntent.self)
        requireAppIntent(GenerateUUIDIntent.self)
        requireAppIntent(TransformBase64Intent.self)

        #expect(CleanTextIntent.isDiscoverable)
        #expect(GenerateUUIDIntent.isDiscoverable)
        #expect(TransformBase64Intent.isDiscoverable)
        for targets in [
            CleanTextIntent.allowedExecutionTargets,
            GenerateUUIDIntent.allowedExecutionTargets,
            TransformBase64Intent.allowedExecutionTargets,
        ] {
            #expect(targets.contains(.appIntentsExtension))
            #expect(targets.contains(.main))
        }
        #expect(Base64OperationAppEnum.decode.operation == .decode)
        #expect(TransformBase64Intent(text: "a", operation: .encode).text == "a")
    }

    @Test("Result helpers work from an identifier and never re-run a command")
    func resultIntents() {
        let identifier = UUID()

        requireAppIntent(CopyExecutionResultIntent.self)
        requireAppIntent(SaveExecutionResultIntent.self)
        #expect(!CopyExecutionResultIntent.isDiscoverable)
        #expect(!SaveExecutionResultIntent.isDiscoverable)
        // Copying needs the host process: the extension has no pasteboard.
        #expect(CopyExecutionResultIntent.allowedExecutionTargets == [.main])
        #expect(CopyExecutionResultIntent(executionID: identifier).executionID
            == identifier.uuidString)
        #expect(SaveExecutionResultIntent(executionID: identifier).executionID
            == identifier.uuidString)
    }

    @Test("A single static intent runs any registered command by entity")
    func runUserShortcutContract() {
        let entity = MoonlightToolEntity(
            id: "shortcut:8b1f0f1c",
            name: "Daily Note",
            summary: "Shortcut · \\daily-note",
            symbolName: "link"
        )
        let intent = RunUserShortcutIntent(command: entity, input: "Moonlight")

        requireAppIntent(RunUserShortcutIntent.self)
        #expect(RunUserShortcutIntent.isDiscoverable)
        // Apple Events are only available in the app process.
        #expect(RunUserShortcutIntent.allowedExecutionTargets == [.main])
        #expect(intent.command.id == entity.id)
        #expect(intent.input == "Moonlight")
        #expect(entity.symbolName == "link")
    }

    @Test("The published phrase list stays short and curated")
    func curatedAppShortcuts() {
        let shortcuts = MoonlightAppShortcuts.appShortcuts

        #expect(shortcuts.count == 4)
        #expect(shortcuts.count < ActionRegistry.standard.descriptors.count)
    }

    @Test("Foreground client copies text on the main actor")
    @MainActor
    func foregroundClientCopiesText() {
        let probe = PresentationProbe()
        let client = MoonlightForegroundClient(
            presentColorPicker: {},
            presentToolPalette: { _ in },
            copyToPasteboard: { probe.copiedText = $0 }
        )

        client.copyToPasteboard("Moonlight")

        #expect(probe.copiedText == "Moonlight")
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
    var copiedText: String?
}

private func requireSnippetIntent<T: SnippetIntent>(_ type: T.Type) {}
private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
private func requireOpenIntent<T: OpenIntent>(_ type: T.Type) {}
