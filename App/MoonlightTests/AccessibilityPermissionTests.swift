import Foundation
import Testing
@testable import MoonlightAppUI

/// The rule behind the accessibility button.
///
/// macOS presents the accessibility prompt once per app, and the app cannot
/// ask the system whether that already happened. So the first press prompts
/// and every press after it opens System Settings, which is the destination
/// that keeps working. Exercised through `permissionStep` rather than through
/// `requestPermission`, so running the tests neither prompts this machine nor
/// opens its Settings.
@Suite("Accessibility permission step")
struct AccessibilityPermissionTests {
    private func makeDefaults() -> UserDefaults {
        // A private suite: the real one carries the answer of whoever ran the
        // app on this machine, which would decide the test's outcome.
        UserDefaults(suiteName: "moonlight-permission-tests-\(UUID().uuidString)")!
    }

    @Test("The first ask prompts")
    func firstAskPrompts() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        #expect(ActiveAppShortcutsReader.permissionStep(consuming: defaults) == .prompt)
    }

    @Test("Every ask after the first opens Settings")
    func laterAsksOpenSettings() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        _ = ActiveAppShortcutsReader.permissionStep(consuming: defaults)

        #expect(ActiveAppShortcutsReader.permissionStep(consuming: defaults) == .settings)
        #expect(ActiveAppShortcutsReader.permissionStep(consuming: defaults) == .settings)
    }

    @Test("An app that already asked in a previous launch does not prompt again")
    func rememberedAskSurvivesRelaunch() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        defaults.set(true, forKey: ActiveAppShortcutsReader.hasAskedDefaultsKey)

        #expect(ActiveAppShortcutsReader.permissionStep(consuming: defaults) == .settings)
    }

    @Test("Settings opens the Accessibility list, not the pane's front page")
    func settingsURLNamesTheList() throws {
        let url = try #require(ActiveAppShortcutsReader.settingsURL)

        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.hasSuffix("Privacy_Accessibility"))
    }
}
