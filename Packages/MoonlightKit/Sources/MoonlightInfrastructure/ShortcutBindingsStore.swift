import Foundation
import MoonlightDomain

public enum ShortcutBindingsStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case duplicateBindingID(UUID)
    case duplicateAlias(String)
    case emptyAlias
    case bindingNotFound(UUID)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The saved shortcuts are not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Saved shortcuts version \(version) is not supported."
        case let .duplicateBindingID(identifier):
            "A shortcut command with identifier \(identifier.uuidString) already exists."
        case let .duplicateAlias(alias):
            "The alias ‘\(alias)’ already belongs to another command."
        case .emptyAlias:
            "Enter an alias for this shortcut."
        case let .bindingNotFound(identifier):
            "Shortcut command \(identifier.uuidString) was not found."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

/// Stores the shortcuts registered as commands, in the App Group container.
///
/// Removing a binding removes Moonlight's link to a shortcut. It never edits or
/// deletes anything in the Shortcuts library.
public actor ShortcutBindingsStore {
    private struct Document: Codable {
        let version: Int
        let bindings: [ShortcutCommandBinding]
    }

    private static let currentVersion = 1

    public let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        self.fileURL = try fileURL ?? Self.defaultFileURL()
        try Self.ensureDocumentExists(at: self.fileURL)
        _ = try Self.readBindings(at: self.fileURL)
    }

    public func bindings() throws -> [ShortcutCommandBinding] {
        try Self.readBindings(at: fileURL)
    }

    public func binding(id: UUID) throws -> ShortcutCommandBinding? {
        try Self.readBindings(at: fileURL).first { $0.id == id }
    }

    /// Adds a binding. The alias must be unique so the palette can address one
    /// command unambiguously.
    @discardableResult
    public func add(_ binding: ShortcutCommandBinding) throws -> [ShortcutCommandBinding] {
        try mutate { bindings in
            guard !binding.alias.isEmpty else {
                throw ShortcutBindingsStoreError.emptyAlias
            }
            guard !bindings.contains(where: { $0.id == binding.id }) else {
                throw ShortcutBindingsStoreError.duplicateBindingID(binding.id)
            }
            guard !bindings.contains(where: { $0.alias == binding.alias }) else {
                throw ShortcutBindingsStoreError.duplicateAlias(binding.alias)
            }
            bindings.append(binding)
        }
    }

    /// Replaces a binding, keeping its Moonlight identity. Used when the user
    /// edits the alias or when a refresh updates the cached name.
    @discardableResult
    public func update(_ binding: ShortcutCommandBinding) throws -> [ShortcutCommandBinding] {
        try mutate { bindings in
            guard let index = bindings.firstIndex(where: { $0.id == binding.id }) else {
                throw ShortcutBindingsStoreError.bindingNotFound(binding.id)
            }
            guard !binding.alias.isEmpty else {
                throw ShortcutBindingsStoreError.emptyAlias
            }
            guard !bindings.contains(where: {
                $0.alias == binding.alias && $0.id != binding.id
            }) else {
                throw ShortcutBindingsStoreError.duplicateAlias(binding.alias)
            }
            bindings[index] = binding
        }
    }

    /// Removes Moonlight's link only. The shortcut itself stays untouched.
    @discardableResult
    public func remove(id: UUID) throws -> [ShortcutCommandBinding] {
        try mutate { bindings in
            guard bindings.contains(where: { $0.id == id }) else {
                throw ShortcutBindingsStoreError.bindingNotFound(id)
            }
            bindings.removeAll { $0.id == id }
        }
    }

    private func mutate(
        _ body: (inout [ShortcutCommandBinding]) throws -> Void
    ) throws -> [ShortcutCommandBinding] {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<[ShortcutCommandBinding], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                var bindings = try Self.readBindingsWithoutCoordination(at: coordinatedURL)
                try body(&bindings)
                try Self.writeBindingsWithoutCoordination(bindings, to: coordinatedURL)
                return bindings
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        let bindings = try operationResult.get()
        MoonlightStorage.postBindingsDidChange()
        return bindings
    }

    /// Reads the document without opening an actor, so a composition root can
    /// fill the catalog cache before any surface asks for it.
    public static func storedBindings(at fileURL: URL) throws -> [ShortcutCommandBinding] {
        try readBindings(at: fileURL)
    }

    public static func defaultFileURL(
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw ShortcutBindingsStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }

        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "shortcut-bindings-v1.json")
    }

    private static func readBindings(at fileURL: URL) throws -> [ShortcutCommandBinding] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        var coordinationError: NSError?
        var operationResult: Result<[ShortcutCommandBinding], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readBindingsWithoutCoordination(at: coordinatedURL)
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
        try writeBindingsWithoutCoordination([], to: fileURL)
    }

    private static func readBindingsWithoutCoordination(
        at fileURL: URL
    ) throws -> [ShortcutCommandBinding] {
        guard let data = FileManager.default.contents(atPath: fileURL.path) else { return [] }
        guard !data.isEmpty else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw ShortcutBindingsStoreError.invalidDocument
        }

        guard document.version == currentVersion else {
            throw ShortcutBindingsStoreError.unsupportedVersion(document.version)
        }

        var seenIDs = Set<UUID>()
        for binding in document.bindings {
            guard seenIDs.insert(binding.id).inserted else {
                throw ShortcutBindingsStoreError.duplicateBindingID(binding.id)
            }
        }
        return document.bindings
    }

    private static func writeBindingsWithoutCoordination(
        _ bindings: [ShortcutCommandBinding],
        to fileURL: URL
    ) throws {
        let document = Document(version: currentVersion, bindings: bindings)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }
}
