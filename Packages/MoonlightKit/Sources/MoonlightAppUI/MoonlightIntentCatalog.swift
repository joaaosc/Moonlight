import MoonlightDomain
import SwiftUI

/// Everything the intents gallery lists.
public enum MoonlightIntentCatalog {
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
            id: MoonlightActionID.convertTimestamp,
            title: "Convert Timestamp",
            subtitle: "Convert between Unix timestamps and ISO-8601 dates",
            category: .transforms,
            symbolName: "clock.arrow.2.circlepath",
            accentColor: .orange,
            sampleInput: "1773000000"
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
            id: "run-user-shortcut",
            title: "Run Shortcut",
            subtitle: "Trigger Apple Shortcuts workflows directly from Moonlight",
            category: .system,
            symbolName: "arrow.triangle.2.circlepath",
            accentColor: .purple,
            requiresInput: false
        ),
        MoonlightIntentItem(
            id: "open-moonlight",
            title: "Open Spotlight Palette",
            subtitle: "Summon the floating Liquid Glass command launcher",
            category: .system,
            symbolName: "moon.stars",
            accentColor: .indigo,
            requiresInput: false
        ),
        MoonlightIntentItem(
            id: "run-command",
            title: "Command Runner",
            subtitle: "Execute Moonlight slash commands and expressions directly",
            category: .system,
            symbolName: "terminal",
            accentColor: .mint,
            sampleInput: "note Capture idea from Control Panel"
        ),
    ]
}
