import AppIntents
import CoreSpotlight
import MoonlightDomain

public struct MoonlightToolEntity: IndexedEntity {
    public static let defaultQuery = MoonlightToolEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Moonlight Tool",
        numericFormat: "\(placeholder: .int) Moonlight tools"
    )

    public let id: String

    @Property(title: "Name", indexingKey: \.title)
    public var name: String

    @Property(title: "Description", indexingKey: \.contentDescription)
    public var summary: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(summary)",
            image: .init(systemName: systemImageName)
        )
    }

    public init(id: String, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }

    public init(descriptor: ActionDescriptor) {
        self.init(
            id: descriptor.id,
            name: descriptor.title,
            summary: descriptor.summary
        )
    }

    public init(definition: CommandDefinition) {
        self.init(
            id: definition.descriptor.id,
            name: definition.descriptor.title,
            summary: definition.descriptor.summary
        )
    }

    private var systemImageName: String {
        ActionRegistry.standard.definition(id: id)?.presentation.symbolName ?? "command"
    }
}

public struct MoonlightToolEntityQuery: EntityStringQuery, IndexedEntityQuery {
    public init() {}

    public func entities(for identifiers: [MoonlightToolEntity.ID]) async throws -> [MoonlightToolEntity] {
        let identifierSet = Set(identifiers)
        return Self.allEntities.filter { identifierSet.contains($0.id) }
    }

    public func entities(matching string: String) async throws -> [MoonlightToolEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.allEntities }

        return Self.allEntities.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    public func suggestedEntities() async throws -> [MoonlightToolEntity] {
        Self.allEntities
    }

    public func reindexEntities(
        for identifiers: [MoonlightToolEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await entities(for: identifiers)
        try await MoonlightToolSpotlightIndex.index(entities)
    }

    public func reindexAllEntities(
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await MoonlightToolSpotlightIndex.index(Self.allEntities)
    }

    public static var allEntities: [MoonlightToolEntity] {
        ActionRegistry.standard.definitions
            .map(MoonlightToolEntity.init(definition:))
            .sorted { $0.name < $1.name }
    }
}

public enum MoonlightToolSpotlightIndex {
    public static let name = "Moonlight_Tools"

    public static func refresh() async throws {
        // Stable IDs update existing items without a delete/reindex search gap.
        try await index(MoonlightToolEntityQuery.allEntities)
    }

    static func index(_ entities: [MoonlightToolEntity]) async throws {
        try await CSSearchableIndex(name: name).indexAppEntities(entities)
    }
}
