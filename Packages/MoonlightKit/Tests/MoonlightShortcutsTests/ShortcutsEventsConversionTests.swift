import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightShortcuts

/// Only the pure conversion is covered here. Sending an Apple Event would ask
/// the user for Automation access and read their personal library.
@Suite("Shortcuts Events value conversion")
struct ShortcutsEventsConversionTests {
    @Test("Nothing returned is an empty result, not an empty string")
    func convertsEmptyValues() {
        #expect(ShortcutsEventsClient.result(from: nil) == .empty)
        #expect(ShortcutsEventsClient.result(from: NSNull()) == .empty)
        #expect(ShortcutsEventsClient.result(from: "") == .empty)
    }

    @Test("Text and numbers convert to text")
    func convertsKnownValues() {
        #expect(ShortcutsEventsClient.result(from: "done") == .text("done"))
        #expect(ShortcutsEventsClient.result(from: NSNumber(value: 42)) == .text("42"))
        #expect(
            ShortcutsEventsClient.result(from: URL(string: "https://example.com")!)
                == .text("https://example.com")
        )
    }

    @Test("An unreadable value is reported with its type instead of a description")
    func reportsUnsupportedValues() {
        let result = ShortcutsEventsClient.result(from: ["a": 1])

        guard case let .unsupportedOutput(typeDescription) = result else {
            Issue.record("Expected an unsupported output, got \(result)")
            return
        }
        #expect(!typeDescription.isEmpty)
        #expect(result != .text("[\"a\": 1]"))
    }
}

@Suite("Preflight semantics")
struct ShortcutsPreflightTests {
    /// Shortcuts Events is a faceless helper and is normally not running, which
    /// is the state a cold start meets. The preflight answers `procNotFound`
    /// there; reading that as "unavailable" is what stopped the request that
    /// would have launched it — and with it the consent prompt.
    @Test("A target that is not running is never reported as unavailable")
    func notRunningIsNotUnavailable() async {
        let client = ShortcutsEventsClient()

        let status = await client.authorizationStatus(askingUser: false)

        #expect(status != .unavailable)
        #expect([.authorized, .notDetermined, .denied].contains(status))
    }
}
