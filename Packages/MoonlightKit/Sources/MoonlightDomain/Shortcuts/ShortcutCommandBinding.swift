import Foundation

/// A shortcut the user registered as a Moonlight command.
///
/// Identity is Moonlight's own `id`: renaming the shortcut, or reusing a name
/// another shortcut already has, cannot move a binding. `externalID` is the
/// handle Shortcuts owns, and `cachedName` is only what was seen last — never
/// the identity.
public struct ShortcutCommandBinding: Codable, Equatable, Identifiable, Sendable {
    /// Prefixes the command identifier so a personal command can never collide
    /// with a built-in tool ID.
    public static let commandIDPrefix = "shortcut:"

    public let id: UUID
    public let externalID: String
    public var cachedName: String
    public var cachedSubtitle: String
    public var alias: String
    public var symbolName: String
    /// Whether Moonlight sends text to the shortcut. Kept apart from the
    /// `accepts input` flag reported by Shortcuts, which is not a parameter
    /// schema and can be wrong for what the user wants here.
    public var inputKind: CommandPresentation.InputKind
    public let createdAt: Date
    /// When the shortcut was last seen in the library.
    public var lastSeenAt: Date?

    public var commandID: String {
        Self.commandIDPrefix + id.uuidString.lowercased()
    }

    public init(
        id: UUID = UUID(),
        externalID: String,
        cachedName: String,
        cachedSubtitle: String = "",
        alias: String,
        symbolName: String = "link",
        inputKind: CommandPresentation.InputKind = .none,
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.externalID = externalID
        self.cachedName = cachedName
        self.cachedSubtitle = cachedSubtitle
        self.alias = alias
        self.symbolName = symbolName
        self.inputKind = inputKind
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }

    /// Builds a binding from a listing entry. Registering never runs anything.
    public init(
        summary: ShortcutSummary,
        alias: String,
        symbolName: String = "link",
        inputKind: CommandPresentation.InputKind? = nil,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.init(
            id: id,
            externalID: summary.externalID,
            cachedName: summary.name,
            cachedSubtitle: summary.subtitle,
            alias: alias,
            symbolName: symbolName,
            inputKind: inputKind ?? (summary.acceptsInput ? .text : .none),
            createdAt: createdAt,
            lastSeenAt: createdAt
        )
    }

    /// The definition this binding contributes to the command catalog.
    ///
    /// Two shortcuts may share a name, so the summary carries the subtitle or
    /// the alias to keep the rows distinguishable.
    public func definition(isAvailable: Bool = true) -> CommandDefinition {
        let detail = cachedSubtitle.isEmpty ? "\\" + alias : cachedSubtitle
        let summary = isAvailable
            ? "Shortcut · \(detail)"
            : "Shortcut unavailable · \(detail)"

        return CommandDefinition(
            descriptor: ActionDescriptor(
                id: commandID,
                title: cachedName,
                summary: summary
            ),
            presentation: CommandPresentation(
                alias: alias,
                symbolName: isAvailable ? symbolName : "exclamationmark.triangle",
                inputKind: inputKind,
                destination: .result
            )
        )
    }

    /// Normalizes an alias typed by the user. Aliases address a command from
    /// the palette, so they stay lowercase and free of whitespace.
    public static func normalizedAlias(_ rawAlias: String) -> String {
        let lowercased = rawAlias
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = lowercased.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" ? character : "-"
        }
        return String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    /// A starting alias derived from the shortcut name, made unique against
    /// aliases already in use.
    public static func suggestedAlias(
        for name: String,
        avoiding usedAliases: Set<String>
    ) -> String {
        let base = normalizedAlias(name)
        let candidate = base.isEmpty ? "shortcut" : base
        guard usedAliases.contains(candidate) else { return candidate }

        var suffix = 2
        while usedAliases.contains("\(candidate)-\(suffix)") {
            suffix += 1
        }
        return "\(candidate)-\(suffix)"
    }
}
