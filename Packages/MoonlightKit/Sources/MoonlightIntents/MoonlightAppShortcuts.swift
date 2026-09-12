import AppIntents

/// The short, curated set of phrases Moonlight publishes.
///
/// One entry, and only one: every tool already reaches Spotlight twice — as
/// its own discoverable intent and as an indexed `MoonlightToolEntity`. A
/// phrase for each of them was a third row saying the same thing, which is the
/// noise Moonlight exists to remove. What is left is the way in.
public struct MoonlightAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMoonlightIntent(),
            phrases: [
                "Open \(.applicationName) Tools",
                "Open the \(.applicationName) palette",
            ],
            shortTitle: "Open Moonlight Tools",
            systemImageName: "command.square"
        )
    }
}
