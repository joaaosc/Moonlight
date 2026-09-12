import Foundation
import Synchronization

/// A shell script the user saved as a command.
///
/// Lines run top to bottom in the user's login shell when the host opens them.
/// The template may contain `{query}`, which is replaced by the text typed in
/// the palette. Without the placeholder the command takes no input, so the
/// palette does not ask for text it would then discard — the same contract as
/// `QuicklinkCommand`, with lines instead of a URL template.
public struct TerminalCommand: Codable, Equatable, Identifiable, Sendable {
    public static let commandIDPrefix = "terminal:"
    public static let queryPlaceholder = "{query}"

    public let id: UUID
    public var title: String
    public var lines: [String]
    public var alias: String
    public var symbolName: String
    public let createdAt: Date

    public var commandID: String {
        Self.commandIDPrefix + id.uuidString.lowercased()
    }

    /// The script as it runs: blank lines removed, the rest untouched.
    public var script: String {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// True when the script expects text from the palette.
    public var acceptsQuery: Bool {
        script.contains(Self.queryPlaceholder)
    }

    public init(
        id: UUID = UUID(),
        title: String,
        lines: [String],
        alias: String,
        symbolName: String = "terminal",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.lines = lines
        self.alias = alias
        self.symbolName = symbolName
        self.createdAt = createdAt
    }

    public func definition() -> CommandDefinition {
        CommandDefinition(
            descriptor: ActionDescriptor(
                id: commandID,
                title: title,
                summary: acceptsQuery
                    ? "Terminal · runs with your text"
                    : "Terminal · runs in Terminal",
                isIdempotent: false
            ),
            presentation: CommandPresentation(
                alias: alias,
                symbolName: symbolName,
                inputKind: acceptsQuery ? .text : .none,
                destination: .terminalScript
            )
        )
    }

    /// Fills the script with the typed query. The text is substituted raw: it
    /// is the user's own argument to their own script, not a value embedded
    /// in a larger syntax the way a quicklink query is embedded in a URL.
    public func resolvedScript(query: String) throws -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard acceptsQuery else {
            guard trimmed.isEmpty else { throw ToolActionError.unexpectedInput }
            return script
        }

        guard !trimmed.isEmpty else { throw ActionError.emptyInput }
        return script.replacingOccurrences(of: Self.queryPlaceholder, with: trimmed)
    }
}

public enum TerminalCommandError: Error, Equatable, LocalizedError, Sendable, CodedActionError {
    case emptyScript

    public var errorDescription: String? {
        switch self {
        case .emptyScript:
            "Enter at least one command line."
        }
    }

    public var failureCode: String {
        switch self {
        case .emptyScript: "empty-terminal-script"
        }
    }
}

/// Holds the terminal commands the synchronous catalog provider reads.
public final class TerminalCache: Sendable {
    private let storage = Mutex<[TerminalCommand]>([])

    public init(commands: [TerminalCommand] = []) {
        storage.withLock { $0 = commands }
    }

    public var commands: [TerminalCommand] {
        storage.withLock { $0 }
    }

    public func replace(_ commands: [TerminalCommand]) {
        storage.withLock { $0 = commands }
    }
}

public struct TerminalCommandProvider: CommandCatalogProvider {
    private let cache: TerminalCache

    public init(cache: TerminalCache) {
        self.cache = cache
    }

    public func snapshot() throws -> [CommandDefinition] {
        var seenIDs = Set<String>()
        var definitions: [CommandDefinition] = []
        for command in cache.commands {
            let definition = command.definition()
            guard seenIDs.insert(definition.id).inserted else {
                throw CommandCatalogError.duplicateCommandID(definition.id)
            }
            definitions.append(definition)
        }
        return definitions
    }
}

/// Runs a terminal command. Resolving the script belongs to the handler, so
/// the result stays inspectable in history; opening Terminal with it belongs
/// to the host, which is the only process that may.
public struct TerminalCommandHandler: ActionHandler {
    private let command: TerminalCommand

    public init(command: TerminalCommand) {
        self.command = command
    }

    public var descriptor: ActionDescriptor {
        command.definition().descriptor
    }

    public var presentation: CommandPresentation {
        command.definition().presentation
    }

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }
        guard request.input.utf8.count <= MoonlightToolLimits.maximumInputByteCount else {
            throw ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            )
        }

        let script = try command.resolvedScript(query: request.input)
        guard !script.isEmpty else {
            throw TerminalCommandError.emptyScript
        }
        guard script.utf8.count <= MoonlightToolLimits.maximumOutputByteCount else {
            throw ActionError.outputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumOutputByteCount
            )
        }
        try Task.checkCancellation()
        return ActionOutput(
            summary: "\(command.title) ready to run",
            detail: script,
            value: .text(script)
        )
    }
}

public struct TerminalCommandHandlerResolver: ActionHandlerResolver {
    private let cache: TerminalCache

    public init(cache: TerminalCache) {
        self.cache = cache
    }

    public func handler(id: String) -> (any ActionHandler)? {
        guard id.hasPrefix(TerminalCommand.commandIDPrefix) else { return nil }
        return cache.commands
            .first { $0.commandID == id }
            .map(TerminalCommandHandler.init(command:))
    }

    public var definitions: [CommandDefinition] {
        cache.commands.map { $0.definition() }
    }
}
