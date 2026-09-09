import AppIntentsTesting
import XCTest

final class MoonlightAppIntentsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var definitions: IntentDefinitions!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.terminate()
        app.launch()

        definitions = IntentDefinitions(bundleIdentifier: "com.joaocosta.Moonlight")
    }

    @MainActor
    func testCaptureNoteThroughSystemInfrastructure() async throws {
        let note = "Intent test \(UUID().uuidString)"
        _ = try await definitions
            .intents["CaptureNoteIntent"]
            .makeIntent(text: note)
            .run()
    }

    @MainActor
    func testCaptureNoteWhileApplicationIsTerminated() async throws {
        let note = "Cold intent test \(UUID().uuidString)"
        app.terminate()

        _ = try await definitions
            .intents["CaptureNoteIntent"]
            .makeIntent(text: note)
            .run()
    }

    @MainActor
    func testOpenMoonlightIntentRunsWhileApplicationIsTerminated() async throws {
        app.terminate()

        _ = try await definitions
            .intents["OpenMoonlightIntent"]
            .makeIntent()
            .run()
    }

    @MainActor
    func testOpenIndexedToolRunsWhileApplicationIsTerminated() async throws {
        let tool = definitions
            .entities["MoonlightToolEntity"]
            .makeReference(identifier: "format-json")
        app.terminate()

        _ = try await definitions
            .intents["OpenMoonlightToolIntent"]
            .makeIntent(target: tool)
            .run()

        XCTAssertTrue(app.buttons["Run Format JSON"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.windows["Moonlight"].exists)
    }

    @MainActor
    func testIndexedColorPickerOpensOnlyColorPanel() async throws {
        let tool = definitions.entities["MoonlightToolEntity"]
            .makeReference(identifier: "open-color-picker")
        app.terminate()
        _ = try await definitions.intents["OpenMoonlightToolIntent"]
            .makeIntent(target: tool).run()

        XCTAssertTrue(app.windows["Moonlight Color Picker"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.windows["Moonlight Tools"].exists)
        XCTAssertFalse(app.windows["Moonlight"].exists)
    }

    @MainActor
    func testDirectColorPickerDismissesExistingPalette() async throws {
        _ = try await definitions.intents["OpenMoonlightIntent"].makeIntent().run()
        XCTAssertTrue(app.windows["Moonlight Tools"].waitForExistence(timeout: 5))
        _ = try await definitions.intents["OpenColorPickerIntent"].makeIntent().run()

        XCTAssertTrue(app.windows["Moonlight Color Picker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.windows["Moonlight Tools"].exists)
        XCTAssertFalse(app.windows["Moonlight"].exists)
    }

    @MainActor
    func testIndexedToolsPresentTheirDestinationWhileRunning() async throws {
        let entity = definitions.entities["MoonlightToolEntity"]
        _ = try await definitions.intents["OpenMoonlightToolIntent"]
            .makeIntent(target: entity.makeReference(identifier: "format-json")).run()
        XCTAssertTrue(app.buttons["Run Format JSON"].waitForExistence(timeout: 5), app.debugDescription)

        _ = try await definitions.intents["OpenMoonlightToolIntent"]
            .makeIntent(target: entity.makeReference(identifier: "open-color-picker")).run()
        XCTAssertTrue(app.windows["Moonlight Color Picker"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.windows["Moonlight Tools"].exists)
        XCTAssertFalse(app.windows["Moonlight"].exists)
    }

    @MainActor
    func testToolQueriesAndSpotlightIndex() async throws {
        let entity = definitions.entities["MoonlightToolEntity"]
        let matches = try await entity.entities(matching: "color picker")
        XCTAssertEqual(matches.count, 1)
        let name: String = try XCTUnwrap(matches.first).name
        XCTAssertEqual(name, "Open Color Picker")

        let indexed = try await entity.spotlightQuery(nil)
        let names: [String] = try indexed.map { try $0.name }
        XCTAssertEqual(Set(names), Set([
            "Base64", "Capture Note", "Clean Text", "Format JSON",
            "Generate UUID", "Open Color Picker"
        ]))
    }

    @MainActor
    func testLegacyCommandStillCapturesNote() async throws {
        let note = "Legacy intent test \(UUID().uuidString)"
        _ = try await definitions
            .intents["RunMoonlightCommandIntent"]
            .makeIntent(command: "note \(note)")
            .run()
    }
}
