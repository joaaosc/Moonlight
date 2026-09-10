import Foundation

/// Reads the user's Shortcuts library.
///
/// Listing never runs a shortcut: registering a command must not trigger the
/// side effects of the workflow being registered. Execution arrives as its own
/// contract in a later batch, so nothing here can be mistaken for it.
public struct ShortcutsCatalogClient: Sendable {
    /// Reports whether Apple Events are allowed. `askingUser` is the only way a
    /// consent prompt can appear, so a background refresh passes `false`.
    public var authorizationStatus: @Sendable (_ askingUser: Bool) async -> ShortcutsAuthorizationStatus
    public var list: @Sendable () async throws -> [ShortcutSummary]
    public var shortcut: @Sendable (_ externalID: String) async throws -> ShortcutSummary?

    public init(
        authorizationStatus: @escaping @Sendable (_ askingUser: Bool) async -> ShortcutsAuthorizationStatus,
        list: @escaping @Sendable () async throws -> [ShortcutSummary],
        shortcut: @escaping @Sendable (_ externalID: String) async throws -> ShortcutSummary?
    ) {
        self.authorizationStatus = authorizationStatus
        self.list = list
        self.shortcut = shortcut
    }

    /// A client with a fixed library, for previews and for surfaces that must
    /// not reach Apple Events.
    public static func stub(
        _ shortcuts: [ShortcutSummary] = [],
        status: ShortcutsAuthorizationStatus = .authorized
    ) -> ShortcutsCatalogClient {
        ShortcutsCatalogClient(
            authorizationStatus: { _ in status },
            list: { shortcuts },
            shortcut: { externalID in shortcuts.first { $0.externalID == externalID } }
        )
    }

    /// A client that reports a permanent state, such as a missing entitlement.
    public static func failing(
        _ error: ShortcutsClientError,
        status: ShortcutsAuthorizationStatus = .denied
    ) -> ShortcutsCatalogClient {
        ShortcutsCatalogClient(
            authorizationStatus: { _ in status },
            list: { throw error },
            shortcut: { _ in throw error }
        )
    }
}
