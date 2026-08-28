import AppIntents

public struct MoonlightAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunMoonlightCommandIntent(),
            phrases: [
                "Run \(.applicationName)",
                "Use \(.applicationName)",
            ],
            shortTitle: "Moonlight",
            systemImageName: "moon.stars"
        )
    }
}
