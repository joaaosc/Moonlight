import MoonlightDomain

/// Immutable catalog that converts runtime descriptors into UI presentations.
public struct MoonlightToolCatalog: Sendable {
    public let definitions: [CommandDefinition]
    public let descriptors: [ActionDescriptor]
    public let presentations: [MoonlightToolPresentation]

    public init(definitions: [CommandDefinition]) throws {
        var seenIDs = Set<String>()
        for definition in definitions {
            let id = definition.descriptor.id
            guard !seenIDs.contains(id) else {
                throw CommandCatalogError.duplicateCommandID(id)
            }
            seenIDs.insert(id)
        }
        self.init(validatedDefinitions: definitions)
    }

    /// Legacy projection initializer. Prefer `init(definitions:) throws` for validated snapshots.
    public init(descriptors: [ActionDescriptor]) {
        let builtinRegistry = ActionRegistry.standard
        let definitions = descriptors.map { descriptor in
            let presentation = builtinRegistry.definition(id: descriptor.id)?.presentation ?? CommandPresentation(
                alias: descriptor.id,
                symbolName: "command",
                inputKind: .text,
                destination: .result
            )
            return CommandDefinition(descriptor: descriptor, presentation: presentation)
        }
        self.init(validatedDefinitions: definitions)
    }

    private init(validatedDefinitions: [CommandDefinition]) {
        let sorted = validatedDefinitions.sorted { $0.descriptor.title < $1.descriptor.title }
        self.definitions = sorted
        self.descriptors = sorted.map(\.descriptor)
        self.presentations = sorted.map(MoonlightToolPresentation.init(definition:))
    }

    public func presentation(for id: String) -> MoonlightToolPresentation? {
        presentations.first { $0.id == id }
    }

    public func descriptor(for id: String) -> ActionDescriptor? {
        descriptors.first { $0.id == id }
    }

    public func definition(for id: String) -> CommandDefinition? {
        definitions.first { $0.descriptor.id == id }
    }
}
