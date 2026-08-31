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

        app.activate()
        let didAppear = try await waitForNote(note, in: app)
        XCTAssertTrue(didAppear)
    }

    @MainActor
    func testCaptureNoteWhileApplicationIsTerminated() async throws {
        let note = "Cold intent test \(UUID().uuidString)"
        app.terminate()

        _ = try await definitions
            .intents["CaptureNoteIntent"]
            .makeIntent(text: note)
            .run()

        app.launch()

        let didAppear = try await waitForNote(note, in: app)
        XCTAssertTrue(didAppear)
    }

    @MainActor
    func testLegacyCommandStillCapturesNote() async throws {
        let note = "Legacy intent test \(UUID().uuidString)"
        _ = try await definitions
            .intents["RunMoonlightCommandIntent"]
            .makeIntent(command: "note \(note)")
            .run()

        app.activate()
        let didAppear = try await waitForNote(note, in: app)
        XCTAssertTrue(didAppear)
    }

    @MainActor
    private func waitForNote(_ note: String, in app: XCUIApplication) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        let latestExecution = app.descendants(matching: .any)["latest-execution"]

        repeat {
            if latestExecution.exists, latestExecution.label.contains(note) {
                return true
            }
            try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline

        return false
    }
}
