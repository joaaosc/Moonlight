import AppIntents

/// The short, curated set of phrases Moonlight publishes.
///
/// Kept deliberately small: the point of Moonlight is to reduce noise in
/// Spotlight, so only the tools that make sense as a spoken or typed phrase
/// appear here. Registering a handler does not add it to this list.
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
        AppShortcut(
            intent: CleanTextIntent(),
            phrases: [
                "Clean text with \(.applicationName)",
                "Clean this text in \(.applicationName)",
            ],
            shortTitle: "Clean Text",
            systemImageName: "text.badge.checkmark"
        )
        AppShortcut(
            intent: FormatJSONIntent(),
            phrases: [
                "Format JSON with \(.applicationName)",
                "Format this JSON in \(.applicationName)",
            ],
            shortTitle: "Format JSON",
            systemImageName: "curlybraces"
        )
        AppShortcut(
            intent: GenerateUUIDIntent(),
            phrases: [
                "Generate a UUID with \(.applicationName)",
                "New UUID in \(.applicationName)",
            ],
            shortTitle: "Generate UUID",
            systemImageName: "number"
        )
        AppShortcut(
            intent: CaptureNoteIntent(),
            phrases: [
                "Capture a note with \(.applicationName)",
                "Save a note in \(.applicationName)",
            ],
            shortTitle: "Capture Note",
            systemImageName: "square.and.pencil"
        )
    }
}
