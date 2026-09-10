import Foundation
import MoonlightDomain

public enum QuicklinkStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case duplicateAlias(String)
    case reservedAlias(String)
    case emptyAlias
    case quicklinkNotFound(UUID)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The saved quicklinks are not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Saved quicklinks version \(version) is not supported."
        case let .duplicateAlias(alias):
            "The alias ‘\(alias)’ already belongs to another command."
        case let .reservedAlias(alias):
            "The alias ‘\(alias)’ belongs to a built-in Moonlight tool."
        case .emptyAlias:
            "Enter an alias for this quicklink."
        case let .quicklinkNotFound(identifier):
            "Quicklink \(identifier.uuidString) was not found."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

/// Stores quicklinks in their own versioned document in the App Group.
public actor QuicklinkStore {
    private struct Document: Codable {
        let version: Int
        let quicklinks: [QuicklinkCommand]
    }

    private static let currentVersion = 1

    public let fileURL: URL
    private let reservedAliases: Set<String>

    public init(
        fileURL: URL? = nil,
        reservedAliases: Set<String> = ShortcutCommandBinding.reservedAliases()
    ) throws {
        self.fileURL = try fileURL ?? Self.defaultFileURL()
        self.reservedAliases = reservedAliases
        try Self.ensureDocumentExists(at: self.fileURL)
        _ = try Self.readQuicklinks(at: self.fileURL)
    }

    public func quicklinks() throws -> [QuicklinkCommand] {
        try Self.readQuicklinks(at: fileURL)
    }

    @discardableResult
    public func add(_ quicklink: QuicklinkCommand) throws -> [QuicklinkCommand] {
        try mutate { quicklinks in
            try validate(quicklink, against: quicklinks)
            quicklinks.append(quicklink)
        }
    }

    @discardableResult
    public func update(_ quicklink: QuicklinkCommand) throws -> [QuicklinkCommand] {
        try mutate { quicklinks in
            guard let index = quicklinks.firstIndex(where: { $0.id == quicklink.id }) else {
                throw QuicklinkStoreError.quicklinkNotFound(quicklink.id)
            }
            try validate(quicklink, against: quicklinks, ignoring: quicklink.id)
            quicklinks[index] = quicklink
        }
    }

    @discardableResult
    public func remove(id: UUID) throws -> [QuicklinkCommand] {
        try mutate { quicklinks in
            guard quicklinks.contains(where: { $0.id == id }) else {
                throw QuicklinkStoreError.quicklinkNotFound(id)
            }
            quicklinks.removeAll { $0.id == id }
        }
    }

    private func validate(
        _ quicklink: QuicklinkCommand,
        against quicklinks: [QuicklinkCommand],
        ignoring identifier: UUID? = nil
    ) throws {
        guard !quicklink.alias.isEmpty else {
            throw QuicklinkStoreError.emptyAlias
        }
        guard !reservedAliases.contains(quicklink.alias) else {
            throw QuicklinkStoreError.reservedAlias(quicklink.alias)
        }
        guard !quicklinks.contains(where: {
            $0.alias == quicklink.alias && $0.id != identifier
        }) else {
            throw QuicklinkStoreError.duplicateAlias(quicklink.alias)
        }
        // A template that cannot produce a URL is refused at save time rather
        // than failing every time the command runs.
        _ = try quicklink.resolvedURL(query: quicklink.acceptsQuery ? "moonlight" : "")
    }

    private func mutate(
        _ body: (inout [QuicklinkCommand]) throws -> Void
    ) throws -> [QuicklinkCommand] {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<[QuicklinkCommand], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                var quicklinks = try Self.readQuicklinksWithoutCoordination(at: coordinatedURL)
                try body(&quicklinks)
                try Self.writeQuicklinksWithoutCoordination(quicklinks, to: coordinatedURL)
                return quicklinks
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        let quicklinks = try operationResult.get()
        MoonlightStorage.postQuicklinksDidChange()
        return quicklinks
    }

    public static func storedQuicklinks(at fileURL: URL) throws -> [QuicklinkCommand] {
        try readQuicklinks(at: fileURL)
    }

    public static func defaultFileURL(
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw QuicklinkStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }
        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "quicklinks-v1.json")
    }

    private static func readQuicklinks(at fileURL: URL) throws -> [QuicklinkCommand] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        var coordinationError: NSError?
        var operationResult: Result<[QuicklinkCommand], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readQuicklinksWithoutCoordination(at: coordinatedURL)
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
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try writeQuicklinksWithoutCoordination([], to: fileURL)
    }

    private static func readQuicklinksWithoutCoordination(
        at fileURL: URL
    ) throws -> [QuicklinkCommand] {
        guard let data = FileManager.default.contents(atPath: fileURL.path), !data.isEmpty else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw QuicklinkStoreError.invalidDocument
        }
        guard document.version == currentVersion else {
            throw QuicklinkStoreError.unsupportedVersion(document.version)
        }
        return document.quicklinks
    }

    private static func writeQuicklinksWithoutCoordination(
        _ quicklinks: [QuicklinkCommand],
        to fileURL: URL
    ) throws {
        let document = Document(version: currentVersion, quicklinks: quicklinks)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }
}
