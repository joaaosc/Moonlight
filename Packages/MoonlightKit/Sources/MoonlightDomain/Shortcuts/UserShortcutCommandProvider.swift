import Foundation
import Synchronization

/// What the palette knows about registered shortcuts right now.
public struct ShortcutCatalogSnapshot: Equatable, Sendable {
    public var bindings: [ShortcutCommandBinding]
    /// Identifiers seen in the last listing. `nil` means the library was never
    /// read in this session, and absence is then not evidence of removal.
    public var availableExternalIDs: Set<String>?

    public init(
        bindings: [ShortcutCommandBinding] = [],
        availableExternalIDs: Set<String>? = nil
    ) {
        self.bindings = bindings
        self.availableExternalIDs = availableExternalIDs
    }

    public func isAvailable(_ binding: ShortcutCommandBinding) -> Bool {
        guard let availableExternalIDs else { return true }
        return availableExternalIDs.contains(binding.externalID)
    }
}

/// Holds the snapshot the synchronous catalog provider reads.
///
/// A catalog snapshot is requested on the main actor while the palette is being
/// prepared, so it must never perform I/O or send Apple Events. Refreshing
/// happens elsewhere and only publishes its result here.
public final class ShortcutBindingsCache: Sendable {
    private let state = Mutex(ShortcutCatalogSnapshot())

    public init(snapshot: ShortcutCatalogSnapshot = ShortcutCatalogSnapshot()) {
        state.withLock { $0 = snapshot }
    }

    public var snapshot: ShortcutCatalogSnapshot {
        state.withLock { $0 }
    }

    public func replaceBindings(_ bindings: [ShortcutCommandBinding]) {
        state.withLock { $0.bindings = bindings }
    }

    /// Records which shortcuts the last listing actually contained.
    public func recordAvailability(externalIDs: Set<String>) {
        state.withLock { $0.availableExternalIDs = externalIDs }
    }

    /// Forgets availability, so nothing is shown as missing on the strength of
    /// a listing that failed.
    public func clearAvailability() {
        state.withLock { $0.availableExternalIDs = nil }
    }
}

/// Contributes the user's registered shortcuts to the command catalog.
public struct UserShortcutCommandProvider: CommandCatalogProvider {
    private let cache: ShortcutBindingsCache

    public init(cache: ShortcutBindingsCache) {
        self.cache = cache
    }

    public func snapshot() throws -> [CommandDefinition] {
        let snapshot = cache.snapshot
        var seenIDs = Set<String>()
        var definitions: [CommandDefinition] = []

        for binding in snapshot.bindings {
            let definition = binding.definition(isAvailable: snapshot.isAvailable(binding))
            guard seenIDs.insert(definition.id).inserted else {
                throw CommandCatalogError.duplicateCommandID(definition.id)
            }
            definitions.append(definition)
        }

        return definitions
    }
}
