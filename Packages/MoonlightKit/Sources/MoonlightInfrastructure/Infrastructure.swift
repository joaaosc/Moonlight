import Foundation
import MoonlightDomain

public enum FileExecutionStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case duplicateExecutionID(UUID)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The execution history is not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Execution history version \(version) is not supported."
        case let .duplicateExecutionID(identifier):
            "Execution history contains duplicate identifier \(identifier.uuidString)."
        }
    }
}

public actor FileExecutionStore: ExecutionStore {
    private struct Document: Codable {
        let version: Int
        let executions: [Execution]
    }

    private static let currentVersion = 1

    public let fileURL: URL
    private let retentionLimit: Int
    private var executions: [UUID: Execution]
    private var insertionOrder: [UUID: UInt64]
    private var nextSequence: UInt64

    public init(
        fileURL: URL = FileExecutionStore.defaultFileURL(),
        retentionLimit: Int = 500
    ) throws {
        self.fileURL = fileURL
        self.retentionLimit = max(1, retentionLimit)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            executions = [:]
            insertionOrder = [:]
            nextSequence = 0
            return
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw FileExecutionStoreError.invalidDocument
        }

        guard document.version == Self.currentVersion else {
            throw FileExecutionStoreError.unsupportedVersion(document.version)
        }

        var loaded: [UUID: Execution] = [:]
        var loadedOrder: [UUID: UInt64] = [:]
        let count = UInt64(document.executions.count)
        for (offset, execution) in document.executions.enumerated() {
            guard loaded[execution.id] == nil else {
                throw FileExecutionStoreError.duplicateExecutionID(execution.id)
            }
            loaded[execution.id] = execution
            loadedOrder[execution.id] = count - UInt64(offset)
        }
        executions = loaded
        insertionOrder = loadedOrder
        nextSequence = count
    }

    public func upsert(_ execution: Execution) throws {
        var updated = executions
        var updatedOrder = insertionOrder
        let sequence = nextSequence + 1
        updated[execution.id] = execution
        updatedOrder[execution.id] = sequence

        let retained = updated.values
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                return updatedOrder[$0.id, default: 0] > updatedOrder[$1.id, default: 0]
            }
            .prefix(retentionLimit)
            .map { $0 }
        let document = Document(
            version: Self.currentVersion,
            executions: retained
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        executions = Dictionary(uniqueKeysWithValues: retained.map { ($0.id, $0) })
        insertionOrder = Dictionary(
            uniqueKeysWithValues: retained.map { ($0.id, updatedOrder[$0.id, default: 0]) }
        )
        nextSequence = sequence
    }

    public func execution(id: UUID) -> Execution? {
        executions[id]
    }

    public func recent(limit: Int) -> [Execution] {
        guard limit > 0 else { return [] }
        return executions.values
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                return insertionOrder[$0.id, default: 0] > insertionOrder[$1.id, default: 0]
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("Moonlight", isDirectory: true)
            .appendingPathComponent("executions-v1.json")
    }
}

public enum MoonlightRuntimeError: Error, LocalizedError, Sendable {
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .initializationFailed(message):
            "Moonlight could not open its execution history: \(message)"
        }
    }
}

public struct MoonlightRuntimeClient: Sendable {
    public var descriptors: @Sendable () -> [ActionDescriptor]
    public var execute: @Sendable (ActionRequest) async throws -> Execution
    public var execution: @Sendable (UUID) async throws -> Execution?
    public var recent: @Sendable (Int) async throws -> [Execution]

    public init(
        descriptors: @escaping @Sendable () -> [ActionDescriptor],
        execute: @escaping @Sendable (ActionRequest) async throws -> Execution,
        execution: @escaping @Sendable (UUID) async throws -> Execution?,
        recent: @escaping @Sendable (Int) async throws -> [Execution]
    ) {
        self.descriptors = descriptors
        self.execute = execute
        self.execution = execution
        self.recent = recent
    }

    public static func inMemory(
        registry: ActionRegistry = .standard,
        store: InMemoryExecutionStore = InMemoryExecutionStore()
    ) -> MoonlightRuntimeClient {
        let runner = ActionRunner(registry: registry, store: store)
        return MoonlightRuntimeClient(
            descriptors: { registry.descriptors },
            execute: { request in try await runner.execute(request) },
            execution: { identifier in await store.execution(id: identifier) },
            recent: { limit in await store.recent(limit: limit) }
        )
    }
}

public enum MoonlightRuntime {
    public static let liveClient: Result<MoonlightRuntimeClient, MoonlightRuntimeError> = {
        do {
            let store = try FileExecutionStore()
            let registry = ActionRegistry.standard
            let runner = ActionRunner(registry: registry, store: store)
            return .success(
                MoonlightRuntimeClient(
                    descriptors: { registry.descriptors },
                    execute: { request in try await runner.execute(request) },
                    execution: { identifier in await store.execution(id: identifier) },
                    recent: { limit in await store.recent(limit: limit) }
                )
            )
        } catch {
            return .failure(.initializationFailed(error.localizedDescription))
        }
    }()

    public static func client() throws -> MoonlightRuntimeClient {
        try liveClient.get()
    }
}
