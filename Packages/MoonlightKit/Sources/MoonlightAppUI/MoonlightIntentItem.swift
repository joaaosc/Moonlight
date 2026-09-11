import Foundation
import MoonlightDomain
import SwiftUI

/// Categories for organizing Moonlight's App Intents in the Control Panel gallery.
public enum MoonlightIntentCategory: String, CaseIterable, Identifiable, Sendable {
    case core = "Core & Text"
    case transforms = "Transforms & Data"
    case system = "System & Automation"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .core: "text.badge.checkmark"
        case .transforms: "arrow.left.arrow.right"
        case .system: "gearshape.2.fill"
        }
    }
}

/// Metadata and visual configuration for an Intent card in the Liquid Glass Control Panel.
public struct MoonlightIntentItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: MoonlightIntentCategory
    public let symbolName: String
    public let gradientColors: [Color]
    public let accentColor: Color
    public let requiresInput: Bool
    public let inputPlaceholder: String
    public let sampleInput: String
    public let parameterKey: String?
    public let parameterOptions: [(title: String, value: String)]
    public let defaultParameterValue: String?
    public let isFeatured: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        category: MoonlightIntentCategory,
        symbolName: String,
        gradientColors: [Color],
        accentColor: Color,
        requiresInput: Bool = true,
        inputPlaceholder: String = "Enter text...",
        sampleInput: String = "",
        parameterKey: String? = nil,
        parameterOptions: [(title: String, value: String)] = [],
        defaultParameterValue: String? = nil,
        isFeatured: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.symbolName = symbolName
        self.gradientColors = gradientColors
        self.accentColor = accentColor
        self.requiresInput = requiresInput
        self.inputPlaceholder = inputPlaceholder
        self.sampleInput = sampleInput
        self.parameterKey = parameterKey
        self.parameterOptions = parameterOptions
        self.defaultParameterValue = defaultParameterValue
        self.isFeatured = isFeatured
    }
}

/// Standard catalog of all available Moonlight App Intents and tools for the Control Panel.
public enum MoonlightIntentCatalog {
    public static let allIntents: [MoonlightIntentItem] = [
        // MARK: - Core & Text
        MoonlightIntentItem(
            id: MoonlightActionID.captureNote,
            title: "Capture Note",
            subtitle: "Keep thoughts and snippets as durable Markdown notes",
            category: .core,
            symbolName: "square.and.pencil",
            gradientColors: [
                Color(red: 0.98, green: 0.35, blue: 0.45),
                Color(red: 0.98, green: 0.60, blue: 0.22),
                Color(red: 0.60, green: 0.20, blue: 0.85)
            ],
            accentColor: Color(red: 0.98, green: 0.45, blue: 0.35),
            requiresInput: true,
            inputPlaceholder: "Enter note text (Markdown supported)...",
            sampleInput: "Review macOS 27 Liquid Glass design specifications and refine Intent cards.",
            isFeatured: true
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.cleanText,
            title: "Clean Text",
            subtitle: "Normalize Unicode characters and trim whitespace",
            category: .core,
            symbolName: "text.badge.checkmark",
            gradientColors: [
                Color(red: 0.05, green: 0.85, blue: 0.60),
                Color(red: 0.05, green: 0.60, blue: 0.88),
                Color(red: 0.10, green: 0.25, blue: 0.68)
            ],
            accentColor: Color(red: 0.05, green: 0.75, blue: 0.70),
            requiresInput: true,
            inputPlaceholder: "Enter unformatted text...",
            sampleInput: "   Hello   World! \n\t  Unicode normalization \u{0041}\u{030A}   "
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.formatJSON,
            title: "Format JSON",
            subtitle: "Validate, format, and pretty-print JSON structures",
            category: .core,
            symbolName: "curlybraces",
            gradientColors: [
                Color(red: 0.25, green: 0.55, blue: 0.98),
                Color(red: 0.50, green: 0.30, blue: 0.95),
                Color(red: 0.28, green: 0.12, blue: 0.65)
            ],
            accentColor: Color(red: 0.35, green: 0.45, blue: 0.98),
            requiresInput: true,
            inputPlaceholder: "Paste JSON string here...",
            sampleInput: "{\"title\":\"Moonlight\",\"version\":27,\"features\":[\"Liquid Glass\",\"App Intents\"]}"
        ),
        MoonlightIntentItem(
            id: MoonlightActionID.generateUUID,
            title: "Generate UUID",
            subtitle: "Generate a cryptographically random version 4 UUID",
            category: .core,
            symbolName: "number",
            gradientColors: [
                Color(red: 0.88, green: 0.18, blue: 0.58),
                Color(red: 0.95, green: 0.38, blue: 0.30),
                Color(red: 0.98, green: 0.62, blue: 0.20)
            ],
            accentColor: Color(red: 0.92, green: 0.25, blue: 0.48),
            requiresInput: false,
            inputPlaceholder: "",
            sampleInput: ""
        ),

        // MARK: - Transforms & Data
        MoonlightIntentItem(
            id: MoonlightActionID.base64Text,
            title: "Base64",
            subtitle: "Encode plain text to Base64 or decode Base64 back",
            category: .transforms,
            symbolName: "arrow.left.arrow.right",
            gradientColors: [
                Color(red: 0.98, green: 0.30, blue: 0.60),
                Color(red: 0.95, green: 0.45, blue: 0.25),
                Color(red: 0.98, green: 0.72, blue: 0.35)
            ],
            accentColor: Color(red: 0.98, green: 0.40, blue: 0.45),
            requiresInput: true,
            inputPlaceholder: "Enter text to encode or Base64 string to decode...",
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
            gradientColors: [
                Color(red: 0.10, green: 0.15, blue: 0.42),
                Color(red: 0.18, green: 0.38, blue: 0.72),
                Color(red: 0.28, green: 0.72, blue: 0.88)
            ],
            accentColor: Color(red: 0.22, green: 0.55, blue: 0.85),
            requiresInput: true,
            inputPlaceholder: "Enter text to compute cryptographic hash...",
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
            gradientColors: [
                Color(red: 0.08, green: 0.75, blue: 0.72),
                Color(red: 0.12, green: 0.85, blue: 0.52),
                Color(red: 0.08, green: 0.48, blue: 0.38)
            ],
            accentColor: Color(red: 0.10, green: 0.80, blue: 0.65),
            requiresInput: true,
            inputPlaceholder: "Enter URL or parameters to encode/decode...",
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
            gradientColors: [
                Color(red: 0.98, green: 0.58, blue: 0.38),
                Color(red: 0.92, green: 0.30, blue: 0.48),
                Color(red: 0.48, green: 0.18, blue: 0.65)
            ],
            accentColor: Color(red: 0.95, green: 0.42, blue: 0.42),
            requiresInput: true,
            inputPlaceholder: "Enter Unix timestamp (e.g. 1773000000) or ISO date...",
            sampleInput: "1773000000"
        ),

        // MARK: - System & Automation
        MoonlightIntentItem(
            id: MoonlightActionID.openColorPicker,
            title: "Color Picker",
            subtitle: "Open the system color inspector with RGB, HEX, and HSL",
            category: .system,
            symbolName: "paintpalette.fill",
            gradientColors: [
                Color(red: 0.98, green: 0.25, blue: 0.48),
                Color(red: 0.75, green: 0.25, blue: 0.92),
                Color(red: 0.20, green: 0.62, blue: 0.98),
                Color(red: 0.18, green: 0.85, blue: 0.62)
            ],
            accentColor: Color(red: 0.85, green: 0.30, blue: 0.85),
            requiresInput: false,
            inputPlaceholder: "",
            sampleInput: ""
        ),
        MoonlightIntentItem(
            id: "run-user-shortcut",
            title: "Run Shortcut",
            subtitle: "Trigger Apple Shortcuts workflows directly from Moonlight",
            category: .system,
            symbolName: "arrow.triangle.2.circlepath",
            gradientColors: [
                Color(red: 0.85, green: 0.15, blue: 0.95),
                Color(red: 0.55, green: 0.18, blue: 0.92),
                Color(red: 0.25, green: 0.15, blue: 0.70)
            ],
            accentColor: Color(red: 0.75, green: 0.20, blue: 0.92),
            requiresInput: false,
            inputPlaceholder: "Shortcut name or input...",
            sampleInput: ""
        ),
        MoonlightIntentItem(
            id: "open-moonlight",
            title: "Open Spotlight Palette",
            subtitle: "Summon the floating Liquid Glass command launcher",
            category: .system,
            symbolName: "moon.stars.fill",
            gradientColors: [
                Color(red: 0.08, green: 0.08, blue: 0.24),
                Color(red: 0.24, green: 0.20, blue: 0.50),
                Color(red: 0.42, green: 0.36, blue: 0.72)
            ],
            accentColor: Color(red: 0.35, green: 0.30, blue: 0.75),
            requiresInput: false,
            inputPlaceholder: "",
            sampleInput: ""
        ),
        MoonlightIntentItem(
            id: "run-command",
            title: "Command Runner",
            subtitle: "Execute Moonlight slash commands and expressions directly",
            category: .system,
            symbolName: "terminal.fill",
            gradientColors: [
                Color(red: 0.12, green: 0.35, blue: 0.38),
                Color(red: 0.20, green: 0.58, blue: 0.48),
                Color(red: 0.38, green: 0.78, blue: 0.62)
            ],
            accentColor: Color(red: 0.25, green: 0.65, blue: 0.52),
            requiresInput: true,
            inputPlaceholder: "Enter command, e.g. 'note Meeting notes' or 'color'...",
            sampleInput: "note Capture idea from Control Panel"
        ),
    ]

    public static func items(for category: MoonlightIntentCategory) -> [MoonlightIntentItem] {
        allIntents.filter { $0.category == category }
    }

    public static var featuredItem: MoonlightIntentItem {
        allIntents.first { $0.isFeatured } ?? allIntents[0]
    }
}
