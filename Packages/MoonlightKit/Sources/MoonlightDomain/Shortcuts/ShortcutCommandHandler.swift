import Foundation

/// Runs one registered shortcut as a Moonlight command.
///
/// The handler is built from a binding, so the command it runs is decided by
/// the identifier stored at registration time — never by a name typed later.
public struct ShortcutCommandHandler: ActionHandler {
    public let binding: ShortcutCommandBinding

    private let client: ShortcutsRunClient
    private let executionGuard: ShortcutExecutionGuard

    public init(
        binding: ShortcutCommandBinding,
        client: ShortcutsRunClient,
        executionGuard: ShortcutExecutionGuard
    ) {
        self.binding = binding
        self.client = client
        self.executionGuard = executionGuard
    }

    public var descriptor: ActionDescriptor {
        binding.definition().descriptor
    }

    public var presentation: CommandPresentation {
        binding.definition().presentation
    }

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }

        let input: String?
        switch binding.inputKind {
        case .none:
            guard request.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ToolActionError.unexpectedInput
            }
            input = nil
        case .text, .base64:
            let text = request.input
            guard text.utf8.count <= MoonlightToolLimits.maximumInputByteCount else {
                throw ActionError.inputTooLarge(
                    limitInBytes: MoonlightToolLimits.maximumInputByteCount
                )
            }
            guard !text.isEmpty else { throw ActionError.emptyInput }
            input = text
        }

        try await executionGuard.begin(binding.externalID)
        defer {
            // Releasing the guard is not cancelling the shortcut: cancelling a
            // local wait says nothing about the workflow on the other side.
            Task { await executionGuard.end(binding.externalID) }
        }

        let result = try await client.run(binding.externalID, input)

        switch result {
        case .empty:
            return ActionOutput(
                summary: "\(binding.cachedName) finished",
                detail: "The shortcut returned no value.",
                value: ActionOutputValue.none
            )
        case let .text(value):
            guard value.utf8.count <= MoonlightToolLimits.maximumOutputByteCount else {
                throw ActionError.outputTooLarge(
                    limitInBytes: MoonlightToolLimits.maximumOutputByteCount
                )
            }
            return ActionOutput(
                summary: "\(binding.cachedName) finished",
                detail: value,
                value: .text(value)
            )
        case let .unsupportedOutput(typeDescription):
            // A value Moonlight cannot read is reported, never stringified.
            throw ShortcutsClientError.unsupportedOutput(typeDescription)
        }
    }
}

/// Resolves handlers for commands whose identifiers only exist at runtime.
public protocol ActionHandlerResolver: Sendable {
    func handler(id: String) -> (any ActionHandler)?
    var definitions: [CommandDefinition] { get }
}

/// Builds a handler for each registered shortcut, reading the same cache the
/// catalog provider reads.
public struct ShortcutCommandHandlerResolver: ActionHandlerResolver {
    private let cache: ShortcutBindingsCache
    private let client: ShortcutsRunClient
    private let executionGuard: ShortcutExecutionGuard

    public init(
        cache: ShortcutBindingsCache,
        client: ShortcutsRunClient,
        executionGuard: ShortcutExecutionGuard = ShortcutExecutionGuard()
    ) {
        self.cache = cache
        self.client = client
        self.executionGuard = executionGuard
    }

    public func handler(id: String) -> (any ActionHandler)? {
        guard id.hasPrefix(ShortcutCommandBinding.commandIDPrefix) else { return nil }
        guard let binding = cache.snapshot.bindings.first(where: { $0.commandID == id }) else {
            return nil
        }
        return ShortcutCommandHandler(
            binding: binding,
            client: client,
            executionGuard: executionGuard
        )
    }

    public var definitions: [CommandDefinition] {
        let snapshot = cache.snapshot
        return snapshot.bindings.map { $0.definition(isAvailable: snapshot.isAvailable($0)) }
    }
}
