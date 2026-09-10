import Foundation

/// What a shortcut returned.
///
/// The cases are kept apart because a shortcut can legitimately return nothing,
/// and because an object Moonlight cannot read must not be turned into a string
/// that looks like a result.
public enum ShortcutRunResult: Equatable, Sendable {
    case empty
    case text(String)
    /// The shortcut returned a value of a type Moonlight does not convert.
    case unsupportedOutput(typeDescription: String)
}

/// Runs a shortcut the user registered.
///
/// Separate from the catalog contract: listing must remain incapable of
/// starting a workflow, and this type is the only thing that can.
public struct ShortcutsRunClient: Sendable {
    public var run: @Sendable (_ externalID: String, _ input: String?) async throws -> ShortcutRunResult

    public init(
        run: @escaping @Sendable (_ externalID: String, _ input: String?) async throws -> ShortcutRunResult
    ) {
        self.run = run
    }

    /// Refuses to run anything. Used by processes without Apple Events.
    public static func unavailable(
        _ error: ShortcutsClientError = .unavailable
    ) -> ShortcutsRunClient {
        ShortcutsRunClient(run: { _, _ in throw error })
    }
}

/// Prevents a shortcut from being started again while it is still running.
///
/// A shortcut can call back into Moonlight, and an Apple Event timeout does not
/// prove the workflow stopped. Re-entry is refused rather than retried.
public actor ShortcutExecutionGuard {
    private var running: Set<String> = []

    public init() {}

    public func begin(_ externalID: String) throws {
        guard running.insert(externalID).inserted else {
            throw ShortcutsClientError.alreadyRunning
        }
    }

    public func end(_ externalID: String) {
        running.remove(externalID)
    }
}
