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
        app.launchEnvironment["MOONLIGHT_APP_INTENTS_TEST_SESSION_ID"] = UUID().uuidString
        app.launch()

        definitions = IntentDefinitions(bundleIdentifier: "com.joaocosta.Moonlight")
    }

    @MainActor
    func testCaptureNoteThroughSystemInfrastructure() async throws {
        let note = "Captured through App Intents Testing"
        let result = try await definitions
            .intents["CaptureNoteIntent"]
            .makeIntent(text: note)
            .run()

        let execution: AnyAppEntity = try result.value
        let actionTitle: String = try execution.actionTitle
        let summary: String = try execution.summary
        let detail: String = try execution.detail
        let status: String = try execution.status

        XCTAssertEqual(actionTitle, "Capture Note")
        XCTAssertEqual(summary, "Note captured")
        XCTAssertEqual(detail, note)
        XCTAssertEqual(status, "succeeded")
    }

    @MainActor
    func testActionEntityQueryThroughSystemInfrastructure() async throws {
        let actions = try await definitions
            .entities["ActionEntity"]
            .suggestedEntities()
        let names: [String] = try actions.map { action in
            try action.name
        }

        XCTAssertEqual(names, ["Capture Note"])
    }
}
