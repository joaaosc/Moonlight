import Foundation
import MoonlightDomain

public enum TerminalCommandStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case duplicateAlias(String)
    case reservedAlias(String)
    case emptyAlias
    case emptyScript
    case commandNotFound(UUID)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The saved terminal commands are not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Saved terminal commands version \(version) is not supported."
        case let .duplicateAlias(alias):
            "The alias ‘\(alias)’ already belongs to another command."
        case let .reservedAlias(alias):
            "The alias ‘\(alias)’ belongs to a built-in Moonlight tool."
        case .emptyAlias:
            "Enter an alias for this terminal command."
        case .emptyScript:
            "Enter at least one command line."
        case let .commandNotFound(identifier):
            "Terminal command \(identifier.uuidString) was not found."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

/// Stores terminal commands in their own versioned document in the App Group.
///
/// The same shape as the quicklinks and shortcut-bindings stores: one file,
/// one version, coordinated reads and writes, alias uniqueness against the
/// built-in tools. Removing a command deletes only the saved script.
public actor TerminalCommandStore {
    private struct Document: Codable {
        let version: Int
        let commands: [TerminalCommand]
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
        _ = try Self.readCommands(at: self.fileURL)
    }

    public func commands() throws -> [TerminalCommand] {
        try Self.readCommands(at: fileURL)
    }

    @discardableResult
    public func add(_ command: TerminalCommand) throws -> [TerminalCommand] {
        try mutate { commands in
            try validate(command, against: commands)
            commands.append(command)
        }
    }

    @discardableResult
    public func update(_ command: TerminalCommand) throws -> [TerminalCommand] {
        try mutate { commands in
            guard let index = commands.firstIndex(where: { $0.id == command.id }) else {
                throw TerminalCommandStoreError.commandNotFound(command.id)
            }
            try validate(command, against: commands, ignoring: command.id)
            commands[index] = command
        }
    }

    @discardableResult
    public func remove(id: UUID) throws -> [TerminalCommand] {
        try mutate { commands in
            guard commands.contains(where: { $0.id == id }) else {
                throw TerminalCommandStoreError.commandNotFound(id)
            }
            commands.removeAll { $0.id == id }
        }
    }

    private func validate(
        _ command: TerminalCommand,
        against commands: [TerminalCommand],
        ignoring identifier: UUID? = nil
    ) throws {
        guard !command.alias.isEmpty else {
            throw TerminalCommandStoreError.emptyAlias
        }
        guard !reservedAliases.contains(command.alias) else {
            throw TerminalCommandStoreError.reservedAlias(command.alias)
        }
        guard !commands.contains(where: {
            $0.alias == command.alias && $0.id != identifier
        }) else {
            throw TerminalCommandStoreError.duplicateAlias(command.alias)
        }
        // A script with no runnable line is refused at save time rather than
        // failing every time the command runs.
        guard !command.script.isEmpty else {
            throw TerminalCommandStoreError.emptyScript
        }
        _ = try command.resolvedScript(query: command.acceptsQuery ? "moonlight" : "")
    }

    private func mutate(
        _ body: (inout [TerminalCommand]) throws -> Void
    ) throws -> [TerminalCommand] {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<[TerminalCommand], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                var commands = try Self.readCommandsWithoutCoordination(at: coordinatedURL)
                try body(&commands)
                try Self.writeCommandsWithoutCoordination(commands, to: coordinatedURL)
                return commands
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        let commands = try operationResult.get()
        MoonlightStorage.postTerminalCommandsDidChange()
        return commands
    }

    public static func storedCommands(at fileURL: URL) throws -> [TerminalCommand] {
        try readCommands(at: fileURL)
    }

    public static func defaultFileURL(
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw TerminalCommandStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }
        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "terminal-commands-v1.json")
    }

    private static func readCommands(at fileURL: URL) throws -> [TerminalCommand] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        var coordinationError: NSError?
        var operationResult: Result<[TerminalCommand], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readCommandsWithoutCoordination(at: coordinatedURL)
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
        try writeCommandsWithoutCoordination([], to: fileURL)
    }

    private static func readCommandsWithoutCoordination(
        at fileURL: URL
    ) throws -> [TerminalCommand] {
        guard let data = FileManager.default.contents(atPath: fileURL.path), !data.isEmpty else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw TerminalCommandStoreError.invalidDocument
        }
        guard document.version == currentVersion else {
            throw TerminalCommandStoreError.unsupportedVersion(document.version)
        }
        return document.commands
    }

    private static func writeCommandsWithoutCoordination(
        _ commands: [TerminalCommand],
        to fileURL: URL
    ) throws {
        let document = Document(version: currentVersion, commands: commands)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }
}
