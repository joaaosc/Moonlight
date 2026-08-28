import AppIntents

public struct MoonlightAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureNoteIntent(),
            phrases: [
                "Capture a note in \(.applicationName)",
                "Save a note with \(.applicationName)",
            ],
            shortTitle: "Capture Note",
            systemImageName: "note.text.badge.plus"
        )
    }
}
