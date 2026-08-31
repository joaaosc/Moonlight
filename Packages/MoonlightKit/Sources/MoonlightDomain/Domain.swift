import Foundation

public enum MoonlightActionID {
    public static let captureNote = "capture-note"
    public static let openColorPicker = "open-color-picker"
    public static let cleanText = "clean-text"
    public static let formatJSON = "format-json"
    public static let generateUUID = "generate-uuid"
    public static let base64Text = "base64-text"
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

    public init(summary: String, detail: String) {
        self.summary = summary
        self.detail = detail
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

    public init(
        id: UUID,
        actionID: String,
        actionTitle: String,
        input: String,
        parameters: ActionParameters? = nil,
        summary: String,
        detail: String,
        status: ExecutionStatus,
        createdAt: Date
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
    }
}

public protocol ActionHandler: Sendable {
    var descriptor: ActionDescriptor { get }
    func perform(request: ActionRequest) async throws -> ActionOutput
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

        return ActionOutput(summary: "Note captured", detail: normalized)
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

        return ActionOutput(
            summary: "Color picker opened",
            detail: "Moonlight continued in the foreground."
        )
    }
}

public struct ActionRegistry: Sendable {
    private let handlers: [any ActionHandler]

    public init(handlers: [any ActionHandler]) {
        self.handlers = handlers
    }

    public static let standard = ActionRegistry(
        handlers: [
            CaptureNoteAction(),
            OpenColorPickerAction(),
            CleanTextAction(),
            FormatJSONAction(),
            GenerateUUIDAction(),
            TransformBase64Action(),
        ]
    )

    public var descriptors: [ActionDescriptor] {
        handlers.map(\.descriptor)
    }

    public func handler(id: String) -> (any ActionHandler)? {
        handlers.first { $0.descriptor.id == id }
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
            createdAt: clock()
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
            createdAt: clock()
        )
        try await store.upsert(execution)
        return execution
    }
}
