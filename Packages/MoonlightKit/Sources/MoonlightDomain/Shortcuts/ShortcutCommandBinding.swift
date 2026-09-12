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
    /// The handle Shortcuts owns. It changes only through an explicit relink,
    /// when a shortcut was reimported or synced under a new identifier.
    public private(set) var externalID: String
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
    /// Whether this command is published to Spotlight. Opt-in per binding:
    /// Shortcuts already indexes the user's own items, and duplicating the
    /// whole library would add exactly the noise Moonlight exists to avoid.
    public var isSpotlightExposed: Bool

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
        lastSeenAt: Date? = nil,
        isSpotlightExposed: Bool = false
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
        self.isSpotlightExposed = isSpotlightExposed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        externalID = try container.decode(String.self, forKey: .externalID)
        cachedName = try container.decode(String.self, forKey: .cachedName)
        cachedSubtitle = try container.decode(String.self, forKey: .cachedSubtitle)
        alias = try container.decode(String.self, forKey: .alias)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        inputKind = try container.decode(CommandPresentation.InputKind.self, forKey: .inputKind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        // Bindings stored before Spotlight exposure existed stay private.
        isSpotlightExposed = try container.decodeIfPresent(
            Bool.self,
            forKey: .isSpotlightExposed
        ) ?? false
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
        let detail = cachedSubtitle.isEmpty
            ? String(SlashCommand.prefix) + alias
            : cachedSubtitle
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

    /// Points this command at another shortcut, keeping its Moonlight identity,
    /// alias and input policy. Used when the original identifier disappeared
    /// after a reimport or a sync.
    public func relinked(to summary: ShortcutSummary, at date: Date = Date()) -> Self {
        var updated = self
        updated.externalID = summary.externalID
        updated.cachedName = summary.name
        updated.cachedSubtitle = summary.subtitle
        updated.lastSeenAt = date
        return updated
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

    /// Aliases a personal command may not take, because a built-in tool
    /// already answers to them in the palette.
    public static func reservedAliases(
        registry: ActionRegistry = .standard
    ) -> Set<String> {
        Set(registry.definitions.map(\.presentation.alias))
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
