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

    @Test("Moonlight foreground route runs only in the app process")
    func openMoonlightContract() {
        requireAppIntent(OpenMoonlightIntent.self)
        #expect(OpenMoonlightIntent.isDiscoverable)
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
        // Restricting the target to the app is not enough on its own: the app
        // is an accessory, so a foreground presentation has to be asked for
        // explicitly or the system never brings it forward.
        #expect(OpenMoonlightToolIntent.supportedModes.contains(.foreground(.immediate)))
        #expect(OpenMoonlightToolIntent.allowedExecutionTargets.contains(.main))
        #expect(!OpenMoonlightToolIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        // Composed at runtime: the built-in tools are always published, and the
        // personal commands the user exposed may join them. Asserting equality
        // would make the test depend on the data of the machine running it.
        let builtInIDs = Set(ActionRegistry.standard.descriptors.map(\.id))
        #expect(builtInIDs.isSubset(of: Set(entities.map(\.id))))
        #expect(entities.map(\.name) == entities.map(\.name).sorted())
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

    @Test("Only the way in is published as a phrase")
    func curatedAppShortcuts() {
        let shortcuts = MoonlightAppShortcuts.appShortcuts

        // Each tool already reaches Spotlight as its own intent and as an
        // indexed entity; a phrase per tool was a third row for one action.
        #expect(shortcuts.count == 1)
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

    /// Moonlight is an accessory app: it has no scene the system can bring
    /// forward on its own, so an intent that ends in a window Moonlight puts on
    /// screen has to name a foreground mode. One that does not is started in
    /// the background and waits for a transition that never arrives, which
    /// Shortcuts reports as being unable to communicate with the app.
    @Test(
        "Every intent that presents a surface asks for the foreground",
        arguments: [
            ("OpenMoonlightIntent", OpenMoonlightIntent.supportedModes),
            ("OpenMoonlightToolIntent", OpenMoonlightToolIntent.supportedModes),
            ("OpenMoonlightSurfaceIntent", OpenMoonlightSurfaceIntent.supportedModes),
            ("OpenColorPickerIntent", OpenColorPickerIntent.supportedModes),
        ]
    )
    func presentingIntentsRunInForeground(intent: (name: String, modes: IntentModes)) {
        #expect(
            intent.modes.contains(.foreground(.immediate)),
            "\(intent.name) presents a Moonlight surface without asking for the foreground"
        )
        #expect(!intent.modes.contains(.background))
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
