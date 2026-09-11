import Foundation
import MoonlightDomain

public enum LauncherLayoutStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The saved launcher arrangement is not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Saved launcher arrangement version \(version) is not supported."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

/// Stores the launcher arrangement in its own versioned document in the App
/// Group, following the same shape as the notes and quicklinks stores.
///
/// A damaged document resolves to an empty layout rather than to an error: an
/// arrangement is a convenience, and refusing to open the launcher because the
/// file cannot be parsed trades a small loss for a total one. Reconciliation
/// then rebuilds a usable grid from the catalogue on the next launch.
public actor LauncherLayoutStore {
    private struct Document: Codable {
        let version: Int
        let layout: LauncherLayout
    }

    private static let currentVersion = 1

    public let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        self.fileURL = try fileURL ?? Self.defaultFileURL()
    }

    public func layout() -> LauncherLayout {
        (try? Self.read(at: fileURL)) ?? .empty
    }

    /// Reads without swallowing the failure, for callers that want to know the
    /// document was unreadable rather than silently start over.
    public func strictLayout() throws -> LauncherLayout {
        try Self.read(at: fileURL)
    }

    public func save(_ layout: LauncherLayout) throws {
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
                try Self.writeWithoutCoordination(layout, to: coordinatedURL)
            }
        }

        if let coordinationError { throw coordinationError }
        guard let operationResult else { throw CocoaError(.fileWriteUnknown) }
        try operationResult.get()
    }

    public static func defaultFileURL(
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw LauncherLayoutStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }
        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "launcher-layout-v1.json")
    }

    private static func read(at fileURL: URL) throws -> LauncherLayout {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }

        var coordinationError: NSError?
        var operationResult: Result<LauncherLayout, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readWithoutCoordination(at: coordinatedURL)
            }
        }

        if let coordinationError { throw coordinationError }
        guard let operationResult else { throw CocoaError(.fileReadUnknown) }
        return try operationResult.get()
    }

    private static func readWithoutCoordination(at fileURL: URL) throws -> LauncherLayout {
        guard let data = FileManager.default.contents(atPath: fileURL.path), !data.isEmpty else {
            return .empty
        }

        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw LauncherLayoutStoreError.invalidDocument
        }
        guard document.version == currentVersion else {
            throw LauncherLayoutStoreError.unsupportedVersion(document.version)
        }
        return document.layout
    }

    private static func writeWithoutCoordination(
        _ layout: LauncherLayout,
        to fileURL: URL
    ) throws {
        let document = Document(version: currentVersion, layout: layout)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }
}
