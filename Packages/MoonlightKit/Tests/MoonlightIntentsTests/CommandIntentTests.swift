import AppIntents
import MoonlightDomain
import MoonlightIntents
import Testing

@Suite("Moonlight command line")
struct MoonlightCommandIntentTests {
    @Test("The command line is a discoverable action with one text parameter")
    func commandIntentContract() {
        requireAppIntent(OpenMoonlightCommandIntent.self)

        #expect(OpenMoonlightCommandIntent.isDiscoverable)
        #expect(OpenMoonlightCommandIntent.supportedModes.contains(.foreground(.dynamic)))
        // The palette lives in the app process; an extension cannot present it.
        #expect(OpenMoonlightCommandIntent.allowedExecutionTargets == [.main])
        #expect(OpenMoonlightCommandIntent(command: "/note").command == "/note")
    }

    @Test("Foreground client forwards a typed command on the main actor")
    @MainActor
    func forwardsCommandLine() {
        let probe = CommandProbe()
        let client = MoonlightForegroundClient(
            presentColorPicker: {},
            presentCommandLine: { probe.text = $0 }
        )

        client.presentCommandLine("/note Buy milk")

        #expect(probe.text == "/note Buy milk")
    }
}

@MainActor
private final class CommandProbe {
    var text: String?
}

private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
