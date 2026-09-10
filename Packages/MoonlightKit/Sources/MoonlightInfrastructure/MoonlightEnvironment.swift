import Foundation
import MoonlightDomain

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

    public init(
        client: MoonlightRuntimeClient,
        catalogProvider: any CommandCatalogProvider
    ) {
        self.client = client
        self.catalogProvider = catalogProvider
    }

    /// Composes the environment backed by the shared history document.
    public static func live(
        registry: ActionRegistry = .standard,
        store: FileExecutionStore? = nil
    ) throws -> MoonlightEnvironment {
        let store = try store ?? FileExecutionStore()
        return MoonlightEnvironment(
            client: .fileBacked(registry: registry, store: store),
            catalogProvider: BuiltInCommandProvider(registry: registry)
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
    public static let environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = {
        do {
            return .success(try MoonlightEnvironment.live())
        } catch {
            return .failure(.initializationFailed(error.localizedDescription))
        }
    }()

    public static func requireEnvironment() throws -> MoonlightEnvironment {
        try environment.get()
    }
}
