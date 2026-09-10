import Foundation

public struct BuiltInCommandProvider: CommandCatalogProvider {
    private let registry: ActionRegistry

    public init(registry: ActionRegistry = .standard) {
        self.registry = registry
    }

    public func snapshot() throws -> [CommandDefinition] {
        var seenIDs = Set<String>()
        var result: [CommandDefinition] = []

        for definition in registry.definitions {
            let id = definition.descriptor.id
            guard !seenIDs.contains(id) else {
                throw CommandCatalogError.duplicateCommandID(id)
            }
            seenIDs.insert(id)
            result.append(definition)
        }

        return result
    }
}
