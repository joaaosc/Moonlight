import Foundation
import MoonlightDomain

/// A readable account of what Moonlight stores and where.
///
/// Every document is versioned and lives in the App Group; this report makes
/// that state inspectable without a debugger, which is what a support question
/// or a botched upgrade actually needs.
public struct MoonlightDiagnostics: Sendable, Equatable {
    public struct Document: Sendable, Equatable, Identifiable {
        public let name: String
        public let path: String
        public let exists: Bool
        public let byteCount: Int?
        public let itemCount: Int?
        public let errorMessage: String?

        public var id: String { name }

        public init(
            name: String,
            path: String,
            exists: Bool,
            byteCount: Int? = nil,
            itemCount: Int? = nil,
            errorMessage: String? = nil
        ) {
            self.name = name
            self.path = path
            self.exists = exists
            self.byteCount = byteCount
            self.itemCount = itemCount
            self.errorMessage = errorMessage
        }
    }

    public let appGroupIdentifier: String
    public let documents: [Document]

    public init(appGroupIdentifier: String, documents: [Document]) {
        self.appGroupIdentifier = appGroupIdentifier
        self.documents = documents
    }

    /// Collects the current state. Reads only: nothing is created or repaired
    /// as a side effect of looking.
    public static func current(environment: MoonlightEnvironment?) async -> MoonlightDiagnostics {
        var documents: [Document] = []

        documents.append(
            await describe(
                name: "Execution history",
                url: try? FileExecutionStore.defaultFileURL(),
                count: {
                    guard let environment else { return nil }
                    return try await environment.client.recent(1_000).count
                }
            )
        )
        documents.append(
            await describe(
                name: "Shortcut commands",
                url: try? ShortcutBindingsStore.defaultFileURL(),
                count: {
                    guard let store = environment?.bindingsStore else { return nil }
                    return try await store.bindings().count
                }
            )
        )
        documents.append(
            await describe(
                name: "Notes",
                url: try? FileNoteStore.defaultFileURL(),
                count: {
                    guard let store = environment?.noteStore else { return nil }
                    return try await store.notes(limit: 10_000).count
                }
            )
        )

        return MoonlightDiagnostics(
            appGroupIdentifier: MoonlightStorage.appGroupIdentifier,
            documents: documents
        )
    }

    private static func describe(
        name: String,
        url: URL?,
        count: () async throws -> Int?
    ) async -> Document {
        guard let url else {
            return Document(
                name: name,
                path: "—",
                exists: false,
                errorMessage: "The shared container is unavailable."
            )
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        let byteCount = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int

        do {
            return Document(
                name: name,
                path: url.path,
                exists: exists,
                byteCount: byteCount,
                itemCount: try await count()
            )
        } catch {
            return Document(
                name: name,
                path: url.path,
                exists: exists,
                byteCount: byteCount,
                errorMessage: error.localizedDescription
            )
        }
    }
}
