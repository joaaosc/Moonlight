import AppIntents
import MoonlightIntents

struct MoonlightAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureNoteIntent(),
            phrases: [
                "Capture a note with \(.applicationName)",
                "Save a note with \(.applicationName)",
            ],
            shortTitle: "Capture Note",
            systemImageName: "note.text.badge.plus"
        )

        AppShortcut(
            intent: OpenColorPickerIntent(),
            phrases: [
                "Open the color picker in \(.applicationName)",
                "Pick a color with \(.applicationName)",
            ],
            shortTitle: "Open Color Picker",
            systemImageName: "paintpalette"
        )
    }
}
