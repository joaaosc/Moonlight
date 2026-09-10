import Foundation

public enum CommandCatalogError: Error, Equatable, LocalizedError, Sendable {
    case duplicateCommandID(String)

    public var errorDescription: String? {
        switch self {
        case let .duplicateCommandID(id):
            "Duplicate command identifier: '\(id)'."
        }
    }
}

public protocol CommandCatalogProvider: Sendable {
    func snapshot() throws -> [CommandDefinition]
}

public struct CompositeCommandCatalogProvider: CommandCatalogProvider {
    private let providers: [any CommandCatalogProvider]

    public init(providers: [any CommandCatalogProvider]) {
        self.providers = providers
    }

    public init(_ providers: any CommandCatalogProvider...) {
        self.init(providers: providers)
    }

    public func snapshot() throws -> [CommandDefinition] {
        var seenIDs = Set<String>()
        var combined: [CommandDefinition] = []

        for provider in providers {
            let definitions = try provider.snapshot()
            for definition in definitions {
                let id = definition.descriptor.id
                guard !seenIDs.contains(id) else {
                    throw CommandCatalogError.duplicateCommandID(id)
                }
                seenIDs.insert(id)
                combined.append(definition)
            }
        }

        return combined
    }
}
