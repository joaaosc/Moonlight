import Foundation
import Synchronization

/// A URL the user turned into a command.
///
/// The template may contain `{query}`, which is replaced by the text typed in
/// the palette. Without the placeholder the link takes no input, so the palette
/// does not ask for text it would then discard.
public struct QuicklinkCommand: Codable, Equatable, Identifiable, Sendable {
    public static let commandIDPrefix = "quicklink:"
    public static let queryPlaceholder = "{query}"

    public let id: UUID
    public var title: String
    public var urlTemplate: String
    public var alias: String
    public var symbolName: String
    public let createdAt: Date

    public var commandID: String {
        Self.commandIDPrefix + id.uuidString.lowercased()
    }

    /// True when the template expects text from the palette.
    public var acceptsQuery: Bool {
        urlTemplate.contains(Self.queryPlaceholder)
    }

    public init(
        id: UUID = UUID(),
        title: String,
        urlTemplate: String,
        alias: String,
        symbolName: String = "arrow.up.right.square",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlTemplate = urlTemplate
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
                    ? "Quicklink · opens \(hostDescription) with your text"
                    : "Quicklink · opens \(hostDescription)",
                isIdempotent: true
            ),
            presentation: CommandPresentation(
                alias: alias,
                symbolName: symbolName,
                inputKind: acceptsQuery ? .text : .none,
                destination: .externalURL
            )
        )
    }

    /// Builds the URL for a query, percent-encoding the text as a query value.
    public func resolvedURL(query: String) throws -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard acceptsQuery else {
            guard trimmed.isEmpty else { throw ToolActionError.unexpectedInput }
            guard let url = URL(string: urlTemplate), url.scheme != nil else {
                throw QuicklinkError.invalidTemplate(urlTemplate)
            }
            return url
        }

        guard !trimmed.isEmpty else { throw ActionError.emptyInput }
        guard let encoded = trimmed.addingPercentEncoding(
            withAllowedCharacters: .moonlightQueryValueAllowed
        ) else {
            throw QuicklinkError.invalidTemplate(urlTemplate)
        }

        let filled = urlTemplate.replacingOccurrences(
            of: Self.queryPlaceholder,
            with: encoded
        )
        guard let url = URL(string: filled), url.scheme != nil else {
            throw QuicklinkError.invalidTemplate(urlTemplate)
        }
        return url
    }

    private var hostDescription: String {
        URL(string: urlTemplate.replacingOccurrences(of: Self.queryPlaceholder, with: "x"))?
            .host() ?? urlTemplate
    }
}

public enum QuicklinkError: Error, Equatable, LocalizedError, Sendable, CodedActionError {
    case invalidTemplate(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidTemplate(template):
            "‘\(template)’ is not a valid web address."
        }
    }

    public var failureCode: String {
        switch self {
        case .invalidTemplate: "invalid-quicklink-template"
        }
    }
}

public extension CharacterSet {
    /// Characters allowed inside a query value. Narrower than `urlQueryAllowed`,
    /// which permits `&` and `=` and would let typed text change the query.
    static let moonlightQueryValueAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}

/// Holds the quicklinks the synchronous catalog provider reads.
public final class QuicklinkCache: Sendable {
    private let storage = Mutex<[QuicklinkCommand]>([])

    public init(quicklinks: [QuicklinkCommand] = []) {
        storage.withLock { $0 = quicklinks }
    }

    public var quicklinks: [QuicklinkCommand] {
        storage.withLock { $0 }
    }

    public func replace(_ quicklinks: [QuicklinkCommand]) {
        storage.withLock { $0 = quicklinks }
    }
}

public struct QuicklinkCommandProvider: CommandCatalogProvider {
    private let cache: QuicklinkCache

    public init(cache: QuicklinkCache) {
        self.cache = cache
    }

    public func snapshot() throws -> [CommandDefinition] {
        var seenIDs = Set<String>()
        var definitions: [CommandDefinition] = []
        for quicklink in cache.quicklinks {
            let definition = quicklink.definition()
            guard seenIDs.insert(definition.id).inserted else {
                throw CommandCatalogError.duplicateCommandID(definition.id)
            }
            definitions.append(definition)
        }
        return definitions
    }
}

/// Runs a quicklink. Opening the URL belongs to the host; the handler resolves
/// and records it, so the result stays inspectable in history.
public struct QuicklinkCommandHandler: ActionHandler {
    private let quicklink: QuicklinkCommand

    public init(quicklink: QuicklinkCommand) {
        self.quicklink = quicklink
    }

    public var descriptor: ActionDescriptor {
        quicklink.definition().descriptor
    }

    public var presentation: CommandPresentation {
        quicklink.definition().presentation
    }

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }

        let url = try quicklink.resolvedURL(query: request.input)
        return ActionOutput(
            summary: "\(quicklink.title) opened",
            detail: url.absoluteString,
            value: .text(url.absoluteString)
        )
    }
}

public struct QuicklinkCommandHandlerResolver: ActionHandlerResolver {
    private let cache: QuicklinkCache

    public init(cache: QuicklinkCache) {
        self.cache = cache
    }

    public func handler(id: String) -> (any ActionHandler)? {
        guard id.hasPrefix(QuicklinkCommand.commandIDPrefix) else { return nil }
        return cache.quicklinks
            .first { $0.commandID == id }
            .map(QuicklinkCommandHandler.init(quicklink:))
    }

    public var definitions: [CommandDefinition] {
        cache.quicklinks.map { $0.definition() }
    }
}
