import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

/// Manages the shortcuts registered as Moonlight commands.
///
/// Reading the library is an explicit action: there is no polling and no
/// listing on launch, and registering a shortcut never runs it.
@MainActor
@Observable
public final class MoonlightShortcutsModel {
    public private(set) var authorization: ShortcutsAuthorizationStatus = .notDetermined
    public private(set) var library: [ShortcutSummary] = []
    public private(set) var bindings: [ShortcutCommandBinding] = []
    public private(set) var isLoadingLibrary = false
    public private(set) var hasLoadedLibrary = false
    public private(set) var errorMessage: String?
    public private(set) var storageMessage: String?

    private let shortcuts: ShortcutsCatalogClient
    private let store: ShortcutBindingsStore?
    private let cache: ShortcutBindingsCache

    public init(
        shortcuts: ShortcutsCatalogClient,
        store: ShortcutBindingsStore?,
        cache: ShortcutBindingsCache
    ) {
        self.shortcuts = shortcuts
        self.store = store
        self.cache = cache
        if store == nil {
            storageMessage = "Moonlight cannot reach its shared container, so shortcut commands cannot be saved."
        }
    }

    public convenience init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        switch environment {
        case let .success(environment):
            self.init(
                shortcuts: environment.shortcuts,
                store: environment.bindingsStore,
                cache: environment.bindingsCache
            )
        case let .failure(error):
            self.init(
                shortcuts: .failing(.unavailable, status: .unavailable),
                store: nil,
                cache: ShortcutBindingsCache()
            )
            storageMessage = error.localizedDescription
        }
    }

    /// Shortcuts already registered, minus the ones the library still offers.
    public var unregisteredLibrary: [ShortcutSummary] {
        let registeredIDs = Set(bindings.map(\.externalID))
        return library.filter { !registeredIDs.contains($0.externalID) }
    }

    public func binding(for summary: ShortcutSummary) -> ShortcutCommandBinding? {
        bindings.first { $0.externalID == summary.externalID }
    }

    /// True when the library was read and the shortcut behind this binding was
    /// not in it. Without a successful listing nothing is reported as missing.
    public func isUnavailable(_ binding: ShortcutCommandBinding) -> Bool {
        guard hasLoadedLibrary else { return false }
        return !library.contains { $0.externalID == binding.externalID }
    }

    public func loadBindings() async {
        guard let store else { return }
        do {
            let stored = try await store.bindings()
            bindings = stored
            cache.replaceBindings(stored)
            storageMessage = nil
        } catch {
            storageMessage = error.localizedDescription
        }
    }

    /// Reads the library after an explicit user action. This is the only place
    /// allowed to raise the system consent prompt.
    public func loadLibrary() async {
        guard !isLoadingLibrary else { return }
        isLoadingLibrary = true
        errorMessage = nil
        defer { isLoadingLibrary = false }

        authorization = await shortcuts.authorizationStatus(true)
        guard authorization.allowsListing else {
            // A library that cannot be read is not an empty library.
            cache.clearAvailability()
            errorMessage = Self.message(for: authorization)
            return
        }

        do {
            let summaries = try await shortcuts.list()
            library = summaries.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            hasLoadedLibrary = true
            cache.recordAvailability(externalIDs: Set(summaries.map(\.externalID)))
            await refreshCachedNames()
        } catch {
            cache.clearAvailability()
            errorMessage = error.localizedDescription
        }
    }

    /// Registers a shortcut as a command. The alias is unique so the palette
    /// can address it even when two shortcuts share a name.
    public func add(_ summary: ShortcutSummary) async {
        guard let store else { return }
        let binding = ShortcutCommandBinding(
            summary: summary,
            alias: ShortcutCommandBinding.suggestedAlias(
                for: summary.name,
                avoiding: Set(bindings.map(\.alias))
                    .union(ShortcutCommandBinding.reservedAliases())
            )
        )

        do {
            let stored = try await store.add(binding)
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateAlias(_ rawAlias: String, for binding: ShortcutCommandBinding) async {
        guard let store else { return }
        var updated = binding
        updated.alias = ShortcutCommandBinding.normalizedAlias(rawAlias)

        do {
            let stored = try await store.update(updated)
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateInputKind(
        _ inputKind: CommandPresentation.InputKind,
        for binding: ShortcutCommandBinding
    ) async {
        guard let store else { return }
        var updated = binding
        updated.inputKind = inputKind

        do {
            let stored = try await store.update(updated)
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Points an existing command at another shortcut. The command keeps its
    /// identity, alias and history; only the link moves.
    public func relink(_ binding: ShortcutCommandBinding, to summary: ShortcutSummary) async {
        guard let store else { return }
        do {
            let stored = try await store.update(binding.relinked(to: summary))
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes Moonlight's link. The shortcut stays in the user's library.
    public func remove(_ binding: ShortcutCommandBinding) async {
        guard let store else { return }
        do {
            let stored = try await store.remove(id: binding.id)
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates the cached names of bindings whose shortcut was renamed. The
    /// link follows the identifier, so a rename changes only what is displayed.
    private func refreshCachedNames() async {
        guard let store else { return }
        let byExternalID = Dictionary(
            library.map { ($0.externalID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for binding in bindings {
            guard let summary = byExternalID[binding.externalID] else { continue }
            guard summary.name != binding.cachedName
                || summary.subtitle != binding.cachedSubtitle
            else { continue }

            var updated = binding
            updated.cachedName = summary.name
            updated.cachedSubtitle = summary.subtitle
            updated.lastSeenAt = Date()
            do {
                apply(try await store.update(updated))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func apply(_ stored: [ShortcutCommandBinding]) {
        bindings = stored
        cache.replaceBindings(stored)
    }

    private static func message(for status: ShortcutsAuthorizationStatus) -> String? {
        switch status {
        case .authorized:
            nil
        case .notDetermined:
            "Moonlight is waiting for permission to read your shortcuts."
        case .denied:
            ShortcutsClientError.notAuthorized.localizedDescription
        case .unavailable:
            ShortcutsClientError.unavailable.localizedDescription
        }
    }
}
