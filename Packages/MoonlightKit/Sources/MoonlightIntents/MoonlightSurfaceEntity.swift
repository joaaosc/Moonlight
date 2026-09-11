import AppIntents
import CoreSpotlight
import MoonlightDomain

/// A Moonlight surface as Spotlight sees it.
///
/// Separate from `MoonlightToolEntity` on purpose: a tool is something the
/// palette runs, while a surface is the palette itself. Mixing them would make
/// the alias compete for ranking with the tools it is supposed to reveal.
public struct MoonlightSurfaceEntity: IndexedEntity {
    public static let defaultQuery = MoonlightSurfaceEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Moonlight Surface",
        numericFormat: "\(placeholder: .int) Moonlight surfaces"
    )

    public let id: String

    @Property(title: "Name", indexingKey: \.title)
    public var name: String

    @Property(title: "Description", indexingKey: \.contentDescription)
    public var summary: String

    /// The typed shorthand. Carried on the entity so the row can show what the
    /// user typed to get here, and so the index can match it.
    public let alias: String
    public let symbolName: String
    private let keywords: [String]
    private let alternateNames: [String]

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(summary)",
            image: .init(systemName: symbolName)
        )
    }

    /// Augments the indexed properties with the alias.
    ///
    /// Without this, Spotlight only matches the title and description, and
    /// `omt` is a substring of neither. `alternateNames` makes the alias a name
    /// the item answers to; `keywords` makes it a term the item matches on.
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.keywords = keywords
        attributes.alternateNames = alternateNames
        return attributes
    }

    public init(surface: MoonlightSurface) {
        // Plain stored properties first: the @Property wrappers below touch
        // `self`, which requires the value to be fully initialized.
        id = surface.id
        alias = surface.alias
        symbolName = surface.symbolName
        keywords = surface.searchKeywords
        alternateNames = surface.alternateNames
        name = surface.title
        summary = surface.summary
    }
}

public struct MoonlightSurfaceEntityQuery: EntityStringQuery, IndexedEntityQuery {
    public init() {}

    public func entities(for identifiers: [MoonlightSurfaceEntity.ID]) async throws -> [MoonlightSurfaceEntity] {
        let identifierSet = Set(identifiers)
        return Self.allEntities.filter { identifierSet.contains($0.id) }
    }

    public func entities(matching string: String) async throws -> [MoonlightSurfaceEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.allEntities }

        // The alias is matched by prefix, not by containment: `om` should keep
        // narrowing towards `omt`, while an unrelated word that merely contains
        // those letters should not surface the launcher.
        return Self.allEntities.filter { entity in
            entity.alias.hasPrefix(query.lowercased())
                || entity.name.localizedStandardContains(query)
                || entity.summary.localizedStandardContains(query)
        }
    }

    public func suggestedEntities() async throws -> [MoonlightSurfaceEntity] {
        Self.allEntities
    }

    public func reindexEntities(
        for identifiers: [MoonlightSurfaceEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await entities(for: identifiers)
        try await MoonlightSurfaceSpotlightIndex.index(entities)
    }

    public func reindexAllEntities(
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await MoonlightSurfaceSpotlightIndex.index(Self.allEntities)
    }

    public static var allEntities: [MoonlightSurfaceEntity] {
        MoonlightSurfaceRegistry.standard.map(MoonlightSurfaceEntity.init(surface:))
    }
}

public enum MoonlightSurfaceSpotlightIndex {
    public static let name = "Moonlight_Surfaces"

    public static func refresh() async throws {
        // Stable IDs update existing items in place, so a refresh never opens
        // a window where the alias resolves to nothing.
        try await index(MoonlightSurfaceEntityQuery.allEntities)
        try await withdrawRetiredSurfaces()
    }

    /// Removes surfaces that were published by an older build and no longer
    /// exist. Without this an alias keeps answering after its surface is gone.
    static func withdrawRetiredSurfaces() async throws {
        let published = Set(MoonlightSurfaceRegistry.standard.map(\.id))
        let retired = Self.knownIdentifiers.filter { !published.contains($0) }
        guard !retired.isEmpty else { return }
        try await CSSearchableIndex(name: name).deleteAppEntities(
            identifiedBy: retired,
            ofType: MoonlightSurfaceEntity.self
        )
    }

    /// Every surface identifier this app ever indexed. Entries stay listed
    /// after a surface is retired so its index item can still be withdrawn.
    public static let knownIdentifiers: [String] = [
        MoonlightSurfaceID.tools,
        MoonlightSurfaceID.window,
        MoonlightSurfaceID.launcher,
    ]

    static func index(_ entities: [MoonlightSurfaceEntity]) async throws {
        try await CSSearchableIndex(name: name).indexAppEntities(entities)
    }
}
