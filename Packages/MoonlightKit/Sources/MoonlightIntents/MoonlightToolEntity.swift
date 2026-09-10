import AppIntents
import CoreSpotlight
import MoonlightDomain
import MoonlightInfrastructure

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

    /// Carried on the entity so a personal command shows its own symbol; the
    /// query no longer looks identifiers up in the built-in registry.
    public let symbolName: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(summary)",
            image: .init(systemName: systemImageName)
        )
    }

    public init(
        id: String,
        name: String,
        summary: String,
        symbolName: String = "command"
    ) {
        // Plain stored properties come first: the @Property wrappers below
        // touch `self`, which requires the value to be fully initialized.
        self.id = id
        self.symbolName = symbolName
        self.name = name
        self.summary = summary
    }

    public init(descriptor: ActionDescriptor) {
        self.init(
            id: descriptor.id,
            name: descriptor.title,
            summary: descriptor.summary,
            symbolName: ActionRegistry.standard
                .definition(id: descriptor.id)?.presentation.symbolName ?? "command"
        )
    }

    public init(definition: CommandDefinition) {
        self.init(
            id: definition.descriptor.id,
            name: definition.descriptor.title,
            summary: definition.descriptor.summary,
            symbolName: definition.presentation.symbolName
        )
    }

    private var systemImageName: String {
        symbolName
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

    /// Everything Moonlight publishes: the built-in tools, plus the personal
    /// commands the user opted into. A registered shortcut stays out of
    /// Spotlight until it is explicitly exposed.
    public static var allEntities: [MoonlightToolEntity] {
        definitions()
            .map(MoonlightToolEntity.init(definition:))
            .sorted { $0.name < $1.name }
    }

    /// Identifiers that must not be in the index: personal commands that were
    /// removed, turned private again, or whose shortcut is missing.
    public static var withdrawnIdentifiers: [MoonlightToolEntity.ID] {
        guard let environment = try? MoonlightProcess.requireEnvironment() else { return [] }
        let snapshot = environment.bindingsCache.snapshot
        return snapshot.bindings
            .filter { !$0.isSpotlightExposed || !snapshot.isAvailable($0) }
            .map(\.commandID)
    }

    private static func definitions() -> [CommandDefinition] {
        guard
            let environment = try? MoonlightProcess.requireEnvironment(),
            let catalog = try? environment.catalogProvider.snapshot()
        else {
            // Composition failed: publish the compiled-in tools rather than an
            // empty catalog, and never guess about personal commands.
            return ActionRegistry.standard.definitions
        }

        let snapshot = environment.bindingsCache.snapshot
        let exposedCommandIDs = Set(
            snapshot.bindings
                .filter { $0.isSpotlightExposed && snapshot.isAvailable($0) }
                .map(\.commandID)
        )

        return catalog.filter { definition in
            guard definition.id.hasPrefix(ShortcutCommandBinding.commandIDPrefix) else {
                return true
            }
            return exposedCommandIDs.contains(definition.id)
        }
    }
}

public enum MoonlightToolSpotlightIndex {
    public static let name = "Moonlight_Tools"

    public static func refresh() async throws {
        // Stable IDs update existing items without a delete/reindex search gap.
        try await index(MoonlightToolEntityQuery.allEntities)
        // Withdrawing is part of a refresh: a command the user unpublished or
        // removed must stop appearing in search, not linger until reinstall.
        try await withdraw(MoonlightToolEntityQuery.withdrawnIdentifiers)
    }

    static func withdraw(_ identifiers: [MoonlightToolEntity.ID]) async throws {
        guard !identifiers.isEmpty else { return }
        try await CSSearchableIndex(name: name).deleteAppEntities(
            identifiedBy: identifiers,
            ofType: MoonlightToolEntity.self
        )
    }

    static func index(_ entities: [MoonlightToolEntity]) async throws {
        try await CSSearchableIndex(name: name).indexAppEntities(entities)
    }
}
