import MoonlightDomain
import SwiftUI

/// Everything the intents gallery lists.
public enum MoonlightIntentCatalog {
    /// Cards the interface runs itself, rather than through the action
    /// registry.
    ///
    /// Every other card's `id` is an `ActionHandler`'s identifier, which the
    /// runner hands straight to the registry. These three have no handler —
    /// they open a window, pick a shortcut, or parse a slash command — so the
    /// registry answered `unknownAction` and each press wrote a failed record
    /// to the history. Named here rather than spelled out at the call site so
    /// a new card cannot join them silently: the catalogue tests fail on any
    /// id that is neither registered nor listed below.
    public static let openMoonlightID = "open-moonlight"
    public static let runCommandID = "run-command"
    public static let runUserShortcutID = "run-user-shortcut"

    public static let interfaceHandledIDs: Set<String> = [
        openMoonlightID,
        runCommandID,
        runUserShortcutID,
    ]

    public static let allIntents: [MoonlightIntentItem] = [
        // MARK: - Core & Text
        MoonlightIntentItem(
            id: MoonlightActionID.captureNote,
            title: "Capture Note",
            subtitle: "Keep thoughts and snippets as durable Markdown notes",
            category: .core,
            symbolName: "square.and.pencil",
            accentColor: .orange,
            sampleInput: "Review macOS 27 Liquid Glass design specifications and refine Intent cards."
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.cleanText,
            title: "Clean Text",
            subtitle: "Normalize Unicode characters and trim whitespace",
            category: .core,
            symbolName: "text.badge.checkmark",
            accentColor: .teal,
            sampleInput: "   Hello   World! \n\t  Unicode normalization \u{0041}\u{030A}   "
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.formatJSON,
            title: "Format JSON",
            subtitle: "Validate, format, and pretty-print JSON structures",
            category: .core,
            symbolName: "curlybraces",
            accentColor: .blue,
            sampleInput: "{\"title\":\"Moonlight\",\"version\":27,\"features\":[\"Liquid Glass\",\"App Intents\"]}"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.generateUUID,
            title: "Generate UUID",
            subtitle: "Generate a cryptographically random version 4 UUID",
            category: .core,
            symbolName: "number",
            accentColor: .pink,
            requiresInput: false
        ),

        // MARK: - Transforms & Data
        MoonlightIntentItem(
            id: MoonlightActionID.base64Text,
            title: "Base64",
            subtitle: "Encode plain text to Base64 or decode Base64 back",
            category: .transforms,
            symbolName: "arrow.left.arrow.right",
            accentColor: .red,
            sampleInput: "Moonlight macOS 27 Liquid Glass",
            parameterKey: "operation",
            parameterOptions: [("Encode", "encode"), ("Decode", "decode")],
            defaultParameterValue: "encode"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.hashText,
            title: "Hash Text",
            subtitle: "Compute SHA-256 or SHA-512 cryptographic digests",
            category: .transforms,
            symbolName: "lock.shield",
            accentColor: .indigo,
            sampleInput: "Moonlight SHA Digest Input",
            parameterKey: "algorithm",
            parameterOptions: [("SHA-256", "sha256"), ("SHA-512", "sha512")],
            defaultParameterValue: "sha256"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.urlText,
            title: "Transform URL",
            subtitle: "Encode or decode percent-encoded URLs and query parameters",
            category: .transforms,
            symbolName: "link",
            accentColor: .green,
            sampleInput: "https://apple.com/macos?q=liquid glass&view=gallery",
            parameterKey: "operation",
            parameterOptions: [("Encode", "encode"), ("Decode", "decode")],
            defaultParameterValue: "encode"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.summarizeText,
            title: "Summarize Text",
            subtitle: "Shorten text to its opening sentences, without generating any",
            category: .core,
            symbolName: "text.quote",
            accentColor: .yellow,
            sampleInput: "Moonlight publishes every tool three ways. A tool is an action in the domain, an App Intent for Shortcuts and Siri, and an indexed entity for Spotlight. Skipping the first one is what leaves a tool reachable only from Shortcuts."
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.convertTimestamp,
            title: "Convert Timestamp",
            subtitle: "Convert between Unix timestamps and ISO-8601 dates",
            category: .transforms,
            symbolName: "clock.arrow.2.circlepath",
            accentColor: .orange,
            sampleInput: "1773000000"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.startTimer,
            title: "Timer",
            subtitle: "Start a minimal countdown from 25m, 90s or 1:30",
            category: .transforms,
            symbolName: "timer",
            accentColor: .cyan,
            sampleInput: "25m"
        ),

        // MARK: - System & Automation
        MoonlightIntentItem(
            id: MoonlightActionID.openColorPicker,
            title: "Color Picker",
            subtitle: "Open the system color inspector with RGB, HEX, and HSL",
            category: .system,
            symbolName: "paintpalette",
            accentColor: .purple,
            requiresInput: false
        ),
        MoonlightIntentItem(
            id: MoonlightIntentCatalog.runUserShortcutID,
            title: "Run Shortcut",
            subtitle: "Trigger Apple Shortcuts workflows directly from Moonlight",
            category: .system,
            symbolName: "arrow.triangle.2.circlepath",
            accentColor: .purple,
            requiresInput: false
        ),
        MoonlightIntentItem(
            id: MoonlightIntentCatalog.openMoonlightID,
            title: "Open Spotlight Palette",
            subtitle: "Summon the floating Liquid Glass command launcher",
            category: .system,
            symbolName: "moon.stars",
            accentColor: .indigo,
            requiresInput: false
        ),
        MoonlightIntentItem(
            id: MoonlightIntentCatalog.runCommandID,
            title: "Command Runner",
            subtitle: "Execute Moonlight slash commands and expressions directly",
            category: .system,
            symbolName: "terminal",
            accentColor: .mint,
            sampleInput: "note Capture idea from Control Panel"
        ),
    ]
}
