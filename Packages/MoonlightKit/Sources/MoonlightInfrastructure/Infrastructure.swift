import CoreFoundation
import Foundation
import MoonlightDomain

public enum FileExecutionStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case duplicateExecutionID(UUID)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The execution history is not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Execution history version \(version) is not supported."
        case let .duplicateExecutionID(identifier):
            "Execution history contains duplicate identifier \(identifier.uuidString)."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

public enum MoonlightStorage {
    public static let appGroupIdentifier = "33FPG9442W.com.joaocosta.Moonlight"
    public static let historyDidChangeNotification = Notification.Name(
        "com.joaocosta.Moonlight.execution-history-did-change"
    )
    public static let historyDidChangeDarwinName =
        "com.joaocosta.Moonlight.execution-history-did-change"

    static func postHistoryDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            historyDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: historyDidChangeDarwinName as CFString),
            nil,
            nil,
            true
        )
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

    public init(
        fileURL: URL? = nil,
        retentionLimit: Int = 500
    ) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = try Self.defaultFileURL()
        }
        self.retentionLimit = max(1, retentionLimit)
        try Self.ensureDocumentExists(at: self.fileURL)
        _ = try Self.readExecutions(at: self.fileURL)
    }

    public func upsert(_ execution: Execution) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<Void, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                var existing = try Self.readExecutionsWithoutCoordination(at: coordinatedURL)
                existing.removeAll { $0.id == execution.id }

                let ordered = ([execution] + existing)
                    .enumerated()
                    .sorted { lhs, rhs in
                        if lhs.element.createdAt != rhs.element.createdAt {
                            return lhs.element.createdAt > rhs.element.createdAt
                        }
                        return lhs.offset < rhs.offset
                    }
                    .prefix(retentionLimit)
                    .map(\.element)

                try Self.writeExecutionsWithoutCoordination(ordered, to: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        try operationResult.get()

        MoonlightStorage.postHistoryDidChange()
    }

    public func execution(id: UUID) throws -> Execution? {
        try Self.readExecutions(at: fileURL).first { $0.id == id }
    }

    public func recent(limit: Int) throws -> [Execution] {
        guard limit > 0 else { return [] }
        return try Self.readExecutions(at: fileURL)
            .prefix(limit)
            .map { $0 }
    }

    public static func defaultFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        temporaryDirectory: URL = .temporaryDirectory,
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
#if DEBUG
        if
            let rawSessionID = environment["MOONLIGHT_APP_INTENTS_TEST_SESSION_ID"],
            let sessionID = UUID(uuidString: rawSessionID)
        {
            return temporaryDirectory
                .appending(path: "MoonlightAppIntentsTests")
                .appending(path: sessionID.uuidString)
                .appending(path: "executions-v1.json")
        }
#endif

        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw FileExecutionStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }

        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "executions-v1.json")
    }

    private static func readExecutions(at fileURL: URL) throws -> [Execution] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        var coordinationError: NSError?
        var operationResult: Result<[Execution], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readExecutionsWithoutCoordination(at: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileReadUnknown)
        }
        return try operationResult.get()
    }

    private static func ensureDocumentExists(at fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<Void, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                guard !FileManager.default.fileExists(atPath: coordinatedURL.path) else {
                    return
                }
                try writeExecutionsWithoutCoordination([], to: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        try operationResult.get()
    }

    private static func readExecutionsWithoutCoordination(at fileURL: URL) throws -> [Execution] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
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

        guard document.version == currentVersion else {
            throw FileExecutionStoreError.unsupportedVersion(document.version)
        }

        var identifiers = Set<UUID>()
        for execution in document.executions {
            guard identifiers.insert(execution.id).inserted else {
                throw FileExecutionStoreError.duplicateExecutionID(execution.id)
            }
        }
        return document.executions
    }

    private static func writeExecutionsWithoutCoordination(
        _ executions: [Execution],
        to fileURL: URL
    ) throws {
        let document = Document(
            version: currentVersion,
            executions: executions
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
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
                    execution: { identifier in try await store.execution(id: identifier) },
                    recent: { limit in try await store.recent(limit: limit) }
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
