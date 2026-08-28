import AppIntents
import MoonlightDomain
import MoonlightInfrastructure
import MoonlightSnippetUI
import SwiftUI

public struct ActionEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Moonlight Action")
    public static let defaultQuery = ActionQuery()

    public let id: String

    @Property(title: "Name")
    public var name: String

    @Property(title: "Summary")
    public var summary: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    public init(id: String, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }

    init(descriptor: ActionDescriptor) {
        self.init(
            id: descriptor.id,
            name: descriptor.title,
            summary: descriptor.summary
        )
    }
}

public struct ActionQuery: EntityQuery {
    private let injectedDescriptors: [ActionDescriptor]?

    public init() {
        injectedDescriptors = nil
    }

    public init(descriptors: [ActionDescriptor]) {
        injectedDescriptors = descriptors
    }

    public func entities(for identifiers: [ActionEntity.ID]) async throws -> [ActionEntity] {
        try resolvedEntities().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [ActionEntity] {
        try resolvedEntities()
    }

    private func resolvedEntities() throws -> [ActionEntity] {
        let descriptors: [ActionDescriptor]
        if let injectedDescriptors {
            descriptors = injectedDescriptors
        } else {
            descriptors = try MoonlightRuntime.client().descriptors()
        }
        return descriptors.map(ActionEntity.init(descriptor:))
    }
}

public struct ExecutionEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Moonlight Execution")
    public static let defaultQuery = ExecutionQuery()

    public let id: UUID

    @Property(title: "Action")
    public var actionTitle: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(actionTitle)")
    }

    public init(id: UUID, actionTitle: String) {
        self.id = id
        self.actionTitle = actionTitle
    }

    init(execution: Execution) {
        self.init(id: execution.id, actionTitle: execution.actionTitle)
    }
}

public struct ExecutionQuery: EntityQuery {
    private let injectedClient: MoonlightRuntimeClient?

    public init() {
        injectedClient = nil
    }

    public init(client: MoonlightRuntimeClient) {
        injectedClient = client
    }

    public func entities(for identifiers: [ExecutionEntity.ID]) async throws -> [ExecutionEntity] {
        let client = try resolvedClient()
        var entities: [ExecutionEntity] = []
        for identifier in identifiers {
            if let execution = try await client.execution(identifier) {
                entities.append(ExecutionEntity(execution: execution))
            }
        }
        return entities
    }

    public func suggestedEntities() async throws -> [ExecutionEntity] {
        let client = try resolvedClient()
        return try await client.recent(20).map(ExecutionEntity.init(execution:))
    }

    private func resolvedClient() throws -> MoonlightRuntimeClient {
        if let injectedClient {
            return injectedClient
        }
        return try MoonlightRuntime.client()
    }
}

public struct ExecuteActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Moonlight Action"
    public static let description = IntentDescription(
        "Runs a Moonlight action and presents its result as a system snippet."
    )
    public static var supportedModes: IntentModes { [.background] }
    public static var supportedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Action")
    public var action: ActionEntity

    @Parameter(title: "Text", inputOptions: .init(multiline: true))
    public var text: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$action) with \(\.$text)")
    }

    public init() {}

    public init(action: ActionEntity, text: String) {
        self.action = action
        self.text = text
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ExecutionEntity> & ShowsSnippetIntent {
        let client = try MoonlightRuntime.client()
        let execution = try await client.execute(
            ActionRequest(actionID: action.id, input: text)
        )
        let entity = ExecutionEntity(execution: execution)
        return .result(
            value: entity,
            snippetIntent: ExecutionSnippetIntent(execution: entity)
        )
    }
}

public enum ExecutionIntentError: Error, LocalizedError, Sendable {
    case executionNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case let .executionNotFound(identifier):
            "Execution \(identifier.uuidString) was not found."
        }
    }
}

public struct ExecutionSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Show Moonlight Result"
    public static var isDiscoverable: Bool { false }
    public static var supportedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Execution")
    public var execution: ExecutionEntity

    public init() {}

    public init(execution: ExecutionEntity) {
        self.execution = execution
    }

    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let client = try MoonlightRuntime.client()
        guard let storedExecution = try await client.execution(execution.id) else {
            throw ExecutionIntentError.executionNotFound(execution.id)
        }
        let view = await MainActor.run {
            ExecutionSnippetView(execution: storedExecution)
        }
        return .result(view: view)
    }
}

public struct MoonlightIntentsPackage: AppIntentsPackage {}
