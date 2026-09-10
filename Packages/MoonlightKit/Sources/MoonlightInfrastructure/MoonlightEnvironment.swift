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

    public init(
        client: MoonlightRuntimeClient,
        catalogProvider: any CommandCatalogProvider,
        shortcuts: ShortcutsCatalogClient = .failing(.unavailable, status: .unavailable),
        bindingsStore: ShortcutBindingsStore? = nil,
        bindingsCache: ShortcutBindingsCache = ShortcutBindingsCache()
    ) {
        self.client = client
        self.catalogProvider = catalogProvider
        self.shortcuts = shortcuts
        self.bindingsStore = bindingsStore
        self.bindingsCache = bindingsCache
    }

    /// Composes the environment backed by the shared history document.
    /// - Parameter shortcuts: supplied by the host, which is the only process
    ///   allowed to send Apple Events.
    public static func live(
        registry: ActionRegistry = .standard,
        store: FileExecutionStore? = nil,
        shortcuts: ShortcutsCatalogClient = .failing(.unavailable, status: .unavailable)
    ) throws -> MoonlightEnvironment {
        let store = try store ?? FileExecutionStore()
        return MoonlightEnvironment(
            client: .fileBacked(registry: registry, store: store),
            // Registered shortcuts are managed and persisted, but they are not
            // published to the palette yet: nothing can execute them, and a
            // command that cannot run must not be announced.
            catalogProvider: BuiltInCommandProvider(registry: registry),
            shortcuts: shortcuts,
            bindingsStore: try ShortcutBindingsStore(),
            bindingsCache: ShortcutBindingsCache()
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
