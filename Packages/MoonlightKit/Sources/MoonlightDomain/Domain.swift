import Foundation

public enum MoonlightActionID {
    public static let captureNote = "capture-note"
    public static let openColorPicker = "open-color-picker"
    public static let cleanText = "clean-text"
    public static let formatJSON = "format-json"
    public static let generateUUID = "generate-uuid"
    public static let base64Text = "base64-text"
    public static let hashText = "hash-text"
    public static let urlText = "url-text"
    public static let convertTimestamp = "convert-timestamp"
}

public enum MoonlightCommand: Equatable, Sendable {
    case captureNote(String)
    case openColorPicker
}

public enum MoonlightCommandError: Error, Equatable, LocalizedError, Sendable {
    case emptyCommand
    case missingNoteText
    case unsupportedCommand(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCommand:
            "Enter a command, such as ‘note Buy milk’ or ‘color’."
        case .missingNoteText:
            "Add text after the note command."
        case let .unsupportedCommand(command):
            "Moonlight doesn’t recognize ‘\(command)’. Try ‘note’ or ‘color’."
        }
    }
}

public struct MoonlightCommandParser: Sendable {
    public init() {}

    public func parse(_ input: String) throws -> MoonlightCommand {
        let normalized = input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw MoonlightCommandError.emptyCommand
        }

        let parts = normalized.split(
            maxSplits: 1,
            whereSeparator: { $0.isWhitespace }
        )
        let verb = parts[0].lowercased()
        let argument = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        switch verb {
        case "note", "nota", "capture", "capturar":
            guard !argument.isEmpty else {
                throw MoonlightCommandError.missingNoteText
            }
            return .captureNote(argument)
        case "color", "colour", "cor", "picker":
            return .openColorPicker
        default:
            throw MoonlightCommandError.unsupportedCommand(String(parts[0]))
        }
    }
}

public struct ActionDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let isIdempotent: Bool

    public init(
        id: String,
        title: String,
        summary: String,
        isIdempotent: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.isIdempotent = isIdempotent
    }
}

public struct ActionParameters: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = ActionParameters()

    public let schemaVersion: Int
    public let values: [String: String]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        values: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.values = values
    }

    public subscript(name: String) -> String? {
        values[name]
    }
}

public struct ActionRequest: Codable, Equatable, Sendable {
    public let actionID: String
    public let input: String
    public let parameters: ActionParameters

    public init(
        actionID: String,
        input: String,
        parameters: ActionParameters = .empty
    ) {
        self.actionID = actionID
        self.input = input
        self.parameters = parameters
    }
}

public struct ActionOutput: Codable, Equatable, Sendable {
    public let summary: String
    public let detail: String
    public let value: ActionOutputValue

    public init(
        summary: String,
        detail: String,
        value: ActionOutputValue
    ) {
        self.summary = summary
        self.detail = detail
        self.value = value
    }

    /// A handler that only produces a string keeps its previous meaning.
    /// Declaring the value is not optional: `ActionOutputValue.none` and a
    /// missing argument must not be spelled the same way.
    public init(summary: String, detail: String) {
        self.init(summary: summary, detail: detail, value: .text(detail))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        detail = try container.decode(String.self, forKey: .detail)
        // Records written before typed output carry only the rendered string.
        value = try container.decodeIfPresent(
            ActionOutputValue.self,
            forKey: .value
        ) ?? .text(detail)
    }
}

public enum ActionError: Error, Equatable, LocalizedError, Sendable {
    case emptyInput
    case inputTooLong(limit: Int)
    case inputTooLarge(limitInBytes: Int)
    case outputTooLarge(limitInBytes: Int)
    case unsupportedParameterSchema(Int)
    case unknownAction(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Enter text before running the action."
        case let .inputTooLong(limit):
            "Text must contain at most \(limit) characters."
        case let .inputTooLarge(limitInBytes):
            "Input must contain at most \(limitInBytes) UTF-8 bytes."
        case let .outputTooLarge(limitInBytes):
            "The result must contain at most \(limitInBytes) UTF-8 bytes."
        case let .unsupportedParameterSchema(schemaVersion):
            "Unsupported action parameter schema: \(schemaVersion)."
        case let .unknownAction(actionID):
            "Unknown action: \(actionID)."
        }
    }
}

public enum ExecutionStatus: String, Codable, Equatable, Sendable {
    case succeeded
    case failed
}

public struct Execution: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let actionID: String
    public let actionTitle: String
    public let input: String
    public let parameters: ActionParameters?
    public let summary: String
    public let detail: String
    public let status: ExecutionStatus
    public let createdAt: Date
    /// Absent in records written before typed output existed.
    public let output: ActionOutput?
    /// Absent in successful records and in failures written before codes existed.
    public let failure: ExecutionFailure?

    public init(
        id: UUID,
        actionID: String,
        actionTitle: String,
        input: String,
        parameters: ActionParameters? = nil,
        summary: String,
        detail: String,
        status: ExecutionStatus,
        createdAt: Date,
        output: ActionOutput? = nil,
        failure: ExecutionFailure? = nil
    ) {
        self.id = id
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.input = input
        self.parameters = parameters
        self.summary = summary
        self.detail = detail
        self.status = status
        self.createdAt = createdAt
        self.output = output
        self.failure = failure
    }

    /// The typed result, reconstructed as plain text for historical records.
    public var resolvedOutput: ActionOutput {
        output ?? ActionOutput(summary: summary, detail: detail, value: .text(detail))
    }

    /// The coded failure, reconstructed for historical records.
    public var resolvedFailure: ExecutionFailure? {
        if let failure {
            return failure
        }
        guard status == .failed else { return nil }
        return ExecutionFailure(code: ExecutionFailure.unknownCode, message: detail)
    }
}

public protocol ActionHandler: Sendable {
    var descriptor: ActionDescriptor { get }
    var presentation: CommandPresentation { get }
    func perform(request: ActionRequest) async throws -> ActionOutput
}

public extension ActionHandler {
    var presentation: CommandPresentation {
        CommandPresentation(
            alias: descriptor.id,
            symbolName: "command",
            inputKind: .text,
            destination: .result
        )
    }
}

public struct CaptureNoteAction: ActionHandler {
    public static let maximumCharacterCount = 10_000

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.captureNote,
        title: "Capture Note",
        summary: "Save text as a Moonlight execution"
    )

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }

        let normalized = request.input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw ActionError.emptyInput
        }
        guard normalized.count <= Self.maximumCharacterCount else {
            throw ActionError.inputTooLong(limit: Self.maximumCharacterCount)
        }

        return ActionOutput(summary: "Note captured", detail: normalized, value: .text(normalized))
    }
}

public struct OpenColorPickerAction: ActionHandler {
    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.openColorPicker,
        title: "Open Color Picker",
        summary: "Open the system color picker"
    )

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }

        // Presenting the picker is the result; there is no value to render.
        return ActionOutput(
            summary: "Color picker opened",
            detail: "Moonlight continued in the foreground.",
            value: ActionOutputValue.none
        )
    }
}

public struct ActionRegistry: Sendable {
    private let handlers: [any ActionHandler]
    /// Sources of handlers whose identifiers only exist at runtime, such as the
    /// shortcuts a user registered. Compiled-in handlers always win a tie.
    private let resolvers: [any ActionHandlerResolver]

    public init(
        handlers: [any ActionHandler],
        resolvers: [any ActionHandlerResolver] = []
    ) {
        self.handlers = handlers
        self.resolvers = resolvers
    }

    public static let standardHandlers: [any ActionHandler] = [
        CaptureNoteAction(),
        OpenColorPickerAction(),
        CleanTextAction(),
        FormatJSONAction(),
        GenerateUUIDAction(),
        TransformBase64Action(),
        HashTextAction(),
        TransformURLAction(),
        ConvertTimestampAction(),
    ]

    public static let standard = ActionRegistry(handlers: standardHandlers)

    public var descriptors: [ActionDescriptor] {
        definitions.map(\.descriptor)
    }

    public var definitions: [CommandDefinition] {
        handlers.map { handler in
            CommandDefinition(
                descriptor: handler.descriptor,
                presentation: handler.presentation
            )
        } + resolvers.flatMap(\.definitions)
    }

    public func handler(id: String) -> (any ActionHandler)? {
        if let handler = handlers.first(where: { $0.descriptor.id == id }) {
            return handler
        }
        for resolver in resolvers {
            if let handler = resolver.handler(id: id) {
                return handler
            }
        }
        return nil
    }

    public func definition(id: String) -> CommandDefinition? {
        if let handler = handlers.first(where: { $0.descriptor.id == id }) {
            return CommandDefinition(
                descriptor: handler.descriptor,
                presentation: handler.presentation
            )
        }
        return resolvers
            .lazy
            .compactMap { $0.handler(id: id) }
            .first
            .map { handler in
                CommandDefinition(
                    descriptor: handler.descriptor,
                    presentation: handler.presentation
                )
            }
    }
}

public protocol ExecutionStore: Sendable {
    func upsert(_ execution: Execution) async throws
    func execution(id: UUID) async throws -> Execution?
    func recent(limit: Int) async throws -> [Execution]
}

public actor InMemoryExecutionStore: ExecutionStore {
    private var executions: [UUID: Execution]

    public init(executions: [Execution] = []) {
        self.executions = Dictionary(
            uniqueKeysWithValues: executions.map { ($0.id, $0) }
        )
    }

    public func upsert(_ execution: Execution) {
        executions[execution.id] = execution
    }

    public func execution(id: UUID) -> Execution? {
        executions[id]
    }

    public func recent(limit: Int) -> [Execution] {
        guard limit > 0 else { return [] }
        return executions.values
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }
}

public struct ActionRunner: Sendable {
    public typealias Clock = @Sendable () -> Date
    public typealias IdentifierGenerator = @Sendable () -> UUID

    public let registry: ActionRegistry
    private let store: any ExecutionStore
    private let clock: Clock
    private let identifierGenerator: IdentifierGenerator

    public init(
        registry: ActionRegistry,
        store: any ExecutionStore,
        clock: @escaping Clock = Date.init,
        identifierGenerator: @escaping IdentifierGenerator = UUID.init
    ) {
        self.registry = registry
        self.store = store
        self.clock = clock
        self.identifierGenerator = identifierGenerator
    }

    @discardableResult
    public func execute(_ request: ActionRequest) async throws -> Execution {
        try Task.checkCancellation()

        guard let handler = registry.handler(id: request.actionID) else {
            return try await persistFailure(
                request: request,
                actionTitle: request.actionID,
                error: ActionError.unknownAction(request.actionID)
            )
        }

        guard request.parameters.schemaVersion == ActionParameters.currentSchemaVersion else {
            return try await persistFailure(
                request: request,
                actionTitle: handler.descriptor.title,
                error: ActionError.unsupportedParameterSchema(
                    request.parameters.schemaVersion
                )
            )
        }

        let output: ActionOutput
        do {
            output = try await handler.perform(request: request)
        } catch is CancellationError {
            // A cancelled command never becomes history: there is no result to
            // record and no failure to report. Callers distinguish it by the
            // error type, never by inspecting a stored execution.
            throw CancellationError()
        } catch {
            return try await persistFailure(
                request: request,
                actionTitle: handler.descriptor.title,
                error: error
            )
        }

        try Task.checkCancellation()

        let execution = Execution(
            id: identifierGenerator(),
            actionID: handler.descriptor.id,
            actionTitle: handler.descriptor.title,
            input: request.input,
            parameters: request.parameters,
            summary: output.summary,
            detail: output.detail,
            status: .succeeded,
            createdAt: clock(),
            output: output
        )
        try await store.upsert(execution)
        return execution
    }

    private func persistFailure(
        request: ActionRequest,
        actionTitle: String,
        error: any Error
    ) async throws -> Execution {
        let execution = Execution(
            id: identifierGenerator(),
            actionID: request.actionID,
            actionTitle: actionTitle,
            input: request.input,
            parameters: request.parameters,
            summary: "Action failed",
            detail: error.localizedDescription,
            status: .failed,
            createdAt: clock(),
            failure: ExecutionFailure(error: error)
        )
        try await store.upsert(execution)
        return execution
    }
}
