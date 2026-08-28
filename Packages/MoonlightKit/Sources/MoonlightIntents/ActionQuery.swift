import AppIntents
import MoonlightDomain

public struct ActionQuery: EntityQuery {
    private let descriptors: [ActionDescriptor]

    public init() {
        descriptors = ActionRegistry.standard.descriptors
    }

    public init(descriptors: [ActionDescriptor]) {
        self.descriptors = descriptors
    }

    public func entities(for identifiers: [ActionEntity.ID]) async throws -> [ActionEntity] {
        resolvedEntities.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [ActionEntity] {
        resolvedEntities
    }

    private var resolvedEntities: [ActionEntity] {
        descriptors.map(ActionEntity.init(descriptor:))
    }
}
