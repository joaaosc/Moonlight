import Foundation
import MoonlightDomain
import Synchronization

/// Dependencies composed once per process.
///
/// The app host and the App Intents extension are separate processes and each
/// one composes its own environment. The only state they share is the
/// `FileExecutionStore` document in the App Group container, coordinated by
/// `NSFileCoordinator`. Nothing here is interprocess: an actor or a global in
/// this module is visible to one process only.
public struct MoonlightEnvironment: Sendable {
    public let client: MoonlightRuntimeClient
    public let catalogProvider: any CommandCatalogProvider
    /// Reads the Shortcuts library. Apple Events live in their own module, so
    /// the host installs a real client and every other process keeps the
    /// unavailable one.
    public let shortcuts: ShortcutsCatalogClient
    public let bindingsStore: ShortcutBindingsStore?
    /// The snapshot the synchronous catalog provider may read.
    public let bindingsCache: ShortcutBindingsCache
    /// Durable notes, kept apart from the execution history.
    public let noteStore: (any NoteStore)?
    public let quicklinkStore: QuicklinkStore?
    public let quicklinkCache: QuicklinkCache
    public let terminalStore: TerminalCommandStore?
    public let terminalCache: TerminalCache

    public init(
        client: MoonlightRuntimeClient,
        catalogProvider: any CommandCatalogProvider,
        shortcuts: ShortcutsCatalogClient = .failing(.unavailable, status: .unavailable),
        bindingsStore: ShortcutBindingsStore? = nil,
        bindingsCache: ShortcutBindingsCache = ShortcutBindingsCache(),
        noteStore: (any NoteStore)? = nil,
        quicklinkStore: QuicklinkStore? = nil,
        quicklinkCache: QuicklinkCache = QuicklinkCache(),
        terminalStore: TerminalCommandStore? = nil,
        terminalCache: TerminalCache = TerminalCache()
    ) {
        self.client = client
        self.catalogProvider = catalogProvider
        self.shortcuts = shortcuts
        self.bindingsStore = bindingsStore
        self.bindingsCache = bindingsCache
        self.noteStore = noteStore
        self.quicklinkStore = quicklinkStore
        self.quicklinkCache = quicklinkCache
        self.terminalStore = terminalStore
        self.terminalCache = terminalCache
    }

    /// Composes the environment backed by the shared history document.
    /// - Parameters:
    ///   - shortcuts: supplied by the host, which is the only process allowed
    ///     to send Apple Events.
    ///   - shortcutRunner: runs registered shortcuts. A process without Apple
    ///     Events keeps the unavailable client, so a personal command fails
    ///     with a stated reason instead of silently doing nothing.
    public static func live(
        handlers: [any ActionHandler] = ActionRegistry.standardHandlers,
        store: FileExecutionStore? = nil,
        shortcuts: ShortcutsCatalogClient = .failing(.unavailable, status: .unavailable),
        shortcutRunner: ShortcutsRunClient = .unavailable(),
        retention: MoonlightRetention = MoonlightRetention()
    ) throws -> MoonlightEnvironment {
        let store = try store ?? FileExecutionStore(
            retentionLimit: retention.executionLimit
        )
        let bindingsStore = try ShortcutBindingsStore()
        let noteStore = try FileNoteStore(retentionLimit: retention.noteLimit)
        let quicklinkStore = try QuicklinkStore()
        let terminalStore = try TerminalCommandStore()
        let cache = ShortcutBindingsCache()
        let quicklinkCache = QuicklinkCache()
        let terminalCache = TerminalCache()

        // The catalog must be correct on the first request, so stored bindings
        // are read here instead of after the first surface appears.
        let bindingsFileURL = try ShortcutBindingsStore.defaultFileURL()
        if let stored = try? ShortcutBindingsStore.storedBindings(at: bindingsFileURL) {
            cache.replaceBindings(stored)
        }
        let quicklinkFileURL = try QuicklinkStore.defaultFileURL()
        if let stored = try? QuicklinkStore.storedQuicklinks(at: quicklinkFileURL) {
            quicklinkCache.replace(stored)
        }
        let terminalFileURL = try TerminalCommandStore.defaultFileURL()
        if let stored = try? TerminalCommandStore.storedCommands(at: terminalFileURL) {
            terminalCache.replace(stored)
        }

        // Capturing a note writes to the durable store; the handler list is
        // composed here so the domain keeps no ambient dependency.
        let composedHandlers = handlers.map { handler -> any ActionHandler in
            handler.descriptor.id == MoonlightActionID.captureNote
                ? CaptureNoteAction(recorder: noteStore.recorder())
                : handler
        }

        let registry = ActionRegistry(
            handlers: composedHandlers,
            resolvers: [
                ShortcutCommandHandlerResolver(cache: cache, client: shortcutRunner),
                QuicklinkCommandHandlerResolver(cache: quicklinkCache),
                TerminalCommandHandlerResolver(cache: terminalCache),
            ]
        )

        return MoonlightEnvironment(
            client: .fileBacked(registry: registry, store: store),
            catalogProvider: CompositeCommandCatalogProvider(
                BuiltInCommandProvider(registry: ActionRegistry(handlers: composedHandlers)),
                UserShortcutCommandProvider(cache: cache),
                QuicklinkCommandProvider(cache: quicklinkCache),
                TerminalCommandProvider(cache: terminalCache)
            ),
            shortcuts: shortcuts,
            bindingsStore: bindingsStore,
            bindingsCache: cache,
            noteStore: noteStore,
            quicklinkStore: quicklinkStore,
            quicklinkCache: quicklinkCache,
            terminalStore: terminalStore,
            terminalCache: terminalCache
        )
    }

    /// Composes an environment with no shared state, for previews and tests.
    public static func inMemory(
        registry: ActionRegistry = .standard,
        store: InMemoryExecutionStore = InMemoryExecutionStore()
    ) -> MoonlightEnvironment {
        MoonlightEnvironment(
            client: .inMemory(registry: registry, store: store),
            catalogProvider: BuiltInCommandProvider(registry: registry)
        )
    }

    /// Composes an environment whose personal commands run against a supplied
    /// client, for tests and previews that must not reach Apple Events.
    public static func inMemory(
        handlers: [any ActionHandler] = ActionRegistry.standardHandlers,
        store: InMemoryExecutionStore = InMemoryExecutionStore(),
        shortcuts: ShortcutsCatalogClient,
        shortcutRunner: ShortcutsRunClient,
        cache: ShortcutBindingsCache
    ) -> MoonlightEnvironment {
        let registry = ActionRegistry(
            handlers: handlers,
            resolvers: [
                ShortcutCommandHandlerResolver(cache: cache, client: shortcutRunner),
            ]
        )
        return MoonlightEnvironment(
            client: .inMemory(registry: registry, store: store),
            catalogProvider: CompositeCommandCatalogProvider(
                BuiltInCommandProvider(registry: ActionRegistry(handlers: handlers)),
                UserShortcutCommandProvider(cache: cache)
            ),
            shortcuts: shortcuts,
            bindingsStore: nil,
            bindingsCache: cache
        )
    }
}

/// The composition root of the running process.
///
/// Entry points resolve it once and hand the environment to the surfaces that
/// need it. Feature code takes its dependencies as parameters instead of
/// reaching for this type, so a surface can be composed differently in tests.
public enum MoonlightProcess {
    private static let installed = Mutex<Result<MoonlightEnvironment, MoonlightRuntimeError>?>(nil)

    /// Installs the environment composed by this process's entry point.
    ///
    /// The first installation wins: a later call must not swap dependencies
    /// under surfaces that already resolved them.
    @discardableResult
    public static func install(
        _ environment: Result<MoonlightEnvironment, MoonlightRuntimeError>
    ) -> Result<MoonlightEnvironment, MoonlightRuntimeError> {
        installed.withLock { current in
            if let current { return current }
            current = environment
            return environment
        }
    }

    /// The environment of this process, composed on first use when the entry
    /// point installed none.
    public static var environment: Result<MoonlightEnvironment, MoonlightRuntimeError> {
        installed.withLock { current in
            if let current { return current }
            let composed: Result<MoonlightEnvironment, MoonlightRuntimeError>
            do {
                composed = .success(try MoonlightEnvironment.live())
            } catch {
                composed = .failure(.initializationFailed(error.localizedDescription))
            }
            current = composed
            return composed
        }
    }

    public static func requireEnvironment() throws -> MoonlightEnvironment {
        try environment.get()
    }
}
