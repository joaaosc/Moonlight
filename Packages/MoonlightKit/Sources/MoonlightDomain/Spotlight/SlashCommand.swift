import Foundation

/// One command as the user typed it: `/name` followed by whatever came after.
///
/// The slash is part of the grammar, not decoration. It is what separates a
/// command from free text, so a field that accepts both can tell them apart
/// without guessing.
public struct SlashCommand: Sendable, Hashable {
    public static let prefix: Character = "/"

    /// The command name, lowercased and without its slash.
    public let name: String
    /// Everything after the name, trimmed. Empty when the command took none.
    public let arguments: String

    public init(name: String, arguments: String = "") {
        self.name = name
        self.arguments = arguments
    }

    /// The command rendered back the way it is typed. Used to hand the text to
    /// a surface that will keep editing it.
    public var typedText: String {
        arguments.isEmpty
            ? "\(Self.prefix)\(name)"
            : "\(Self.prefix)\(name) \(arguments)"
    }
}

public enum SlashCommandError: Error, Equatable, LocalizedError {
    case empty
    case missingPrefix
    case missingName
    case invalidName(String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Type a command."
        case .missingPrefix:
            "Commands start with a slash, like /note."
        case .missingName:
            "Type a command name after the slash."
        case let .invalidName(name):
            "\(name) is not a valid command name. Use letters, digits and hyphens."
        }
    }
}

/// Turns typed text into a command. Knows the grammar and nothing about which
/// commands exist: resolving a name against the catalogue is a separate step,
/// so a typo in the syntax and an unknown command stay distinguishable.
public struct SlashCommandParser: Sendable {
    public init() {}

    public func parse(_ input: String) throws -> SlashCommand {
        let normalized = input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw SlashCommandError.empty
        }
        guard normalized.first == SlashCommand.prefix else {
            throw SlashCommandError.missingPrefix
        }

        let body = normalized.dropFirst()
        let parts = body.split(maxSplits: 1, whereSeparator: \.isWhitespace)

        guard let rawName = parts.first, !rawName.isEmpty else {
            throw SlashCommandError.missingName
        }

        let name = String(rawName).lowercased()
        guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
            throw SlashCommandError.invalidName(String(rawName))
        }

        let arguments = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return SlashCommand(name: name, arguments: arguments)
    }
}

/// One command the catalogue publishes.
public struct SlashCommandDefinition: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let summary: String

    public init(name: String, summary: String) {
        self.name = name
        self.summary = summary
    }
}

/// The commands Moonlight answers to.
///
/// Deliberately empty for now: the command line, its grammar and its route
/// through Spotlight are what this slice delivers. Publishing a command is
/// meant to be an entry in `standard` and nothing else.
public enum SlashCommandRegistry {
    public static let standard: [SlashCommandDefinition] = []

    public static func definition(named name: String) -> SlashCommandDefinition? {
        let normalized = name.lowercased()
        return standard.first { $0.name == normalized }
    }

    /// Names offered as completions for a partially typed command.
    public static func completions(matching prefix: String) -> [SlashCommandDefinition] {
        let normalized = prefix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .drop { $0 == SlashCommand.prefix }
        guard !normalized.isEmpty else { return standard }
        return standard.filter { $0.name.hasPrefix(normalized) }
    }
}
