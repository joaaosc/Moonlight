import AppKit
import MoonlightDomain
import MoonlightInfrastructure
import Observation
import OSLog

/// The state behind the launcher surface: what is installed, where the user put
/// it, and what is being searched for.
///
/// The arrangement is the only thing that is persisted. What is installed is
/// read fresh every time the launcher opens, because an app installed while the
/// launcher was closed should be there when it opens.
@MainActor
@Observable
public final class MoonlightLauncherModel {
    public private(set) var layout: LauncherLayout = .empty
    public private(set) var apps: [String: InstalledApp] = [:]
    public private(set) var isLoading = false
    /// Set when the catalogue or the arrangement could not be read. Shown in
    /// place of the grid rather than thrown away.
    public private(set) var failure: String?

    public var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            // A new search starts at the top of its own list; the page the user
            // was on belongs to the arrangement, not to the results.
            if query.isEmpty { selection = nil } else { selection = searchResults.first?.id }
        }
    }

    /// The page currently on screen. Meaningless while searching.
    public var currentPage = 0

    /// The folder whose contents are open, if any.
    public var openFolder: LauncherFolder?

    /// The app the keyboard is on, by bundle identifier.
    public var selection: String?

    private let catalog: any InstalledAppsCatalog
    private let store: LauncherLayoutStore?
    private let reconciler: LauncherLayoutReconciler
    private let search = LauncherSearch()
    private let launcher = AppLauncher()
    private let iconCache: AppIconCache

    private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "Launcher"
    )

    public init(
        catalog: any InstalledAppsCatalog = DirectoryAppCatalog(),
        store: LauncherLayoutStore? = try? LauncherLayoutStore(),
        reconciler: LauncherLayoutReconciler = LauncherLayoutReconciler(),
        iconCache: AppIconCache = .shared
    ) {
        self.catalog = catalog
        self.store = store
        self.reconciler = reconciler
        self.iconCache = iconCache
    }

    // MARK: - Loading

    /// Reads the catalogue and merges it with the saved arrangement.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        let saved = await store?.layout() ?? .empty
        do {
            let installed = try await catalog.apps()
            apps = Dictionary(uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) })
            let reconciled = reconciler.reconcile(layout: saved, catalog: installed)
            layout = reconciled
            failure = nil
            iconCache.retain(only: apps.keys)

            // Saved only when reconciliation actually changed something, so
            // merely opening the launcher does not rewrite the document.
            if reconciled != saved {
                await persist()
            }
        } catch {
            failure = error.localizedDescription
            Self.logger.error(
                "Failed to read the application catalogue: \(error.localizedDescription, privacy: .public)"
            )
        }

        currentPage = min(currentPage, max(0, layout.pageCount - 1))
    }

    private func persist() async {
        guard let store else { return }
        do {
            try await store.save(layout)
        } catch {
            Self.logger.error(
                "Failed to save the launcher arrangement: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Applies a change to the arrangement and writes it out.
    func mutate(_ body: (inout LauncherLayout) -> Void) {
        var updated = layout
        body(&updated)
        updated.normalize()
        guard updated != layout else { return }
        layout = updated
        currentPage = min(currentPage, max(0, layout.pageCount - 1))
        Task { await persist() }
    }

    /// Fills the model in without reading the disk, for previews and for the
    /// snapshot renderer, which draws offscreen and cannot wait on a task.
    public func preload(apps installed: [InstalledApp], layout preloaded: LauncherLayout? = nil) {
        apps = Dictionary(uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) })
        layout = preloaded ?? reconciler.initialLayout(catalog: installed)
        failure = nil
    }

    // MARK: - Reading

    public func app(for identifier: String) -> InstalledApp? {
        apps[identifier]
    }

    public func icon(for app: InstalledApp) -> NSImage {
        iconCache.icon(for: app)
    }

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var searchResults: [InstalledApp] {
        search.apps(for: query, in: Array(apps.values))
    }

    /// The items on the page being shown, in slot order.
    public func items(onPage page: Int) -> [LauncherItem] {
        guard layout.pages.indices.contains(page) else { return [] }
        return layout.pages[page]
    }

    public var pageCount: Int { max(1, layout.pageCount) }

    // MARK: - Acting

    public func open(_ app: InstalledApp) async {
        await launcher.open(app)
    }

    public func openSelection() async -> Bool {
        guard let selection, let app = apps[selection] else { return false }
        await open(app)
        return true
    }

    public func hide(_ app: InstalledApp) {
        mutate { $0.hide(app: app.bundleIdentifier) }
    }

    // MARK: - Navigating

    public func goToNextPage() {
        guard !isSearching else { return }
        currentPage = min(currentPage + 1, pageCount - 1)
    }

    public func goToPreviousPage() {
        guard !isSearching else { return }
        currentPage = max(currentPage - 1, 0)
    }

    /// Moves the keyboard selection through whatever list is on screen.
    public func moveSelection(by offset: Int) {
        let identifiers = navigableIdentifiers
        guard !identifiers.isEmpty else { return }

        guard let current = selection, let index = identifiers.firstIndex(of: current) else {
            selection = identifiers.first
            return
        }

        let next = index + offset
        if next < 0 || next >= identifiers.count, !isSearching {
            // Running off the edge of a page turns it, which is what the arrow
            // keys should do in a paged grid.
            let wasPage = currentPage
            if next < 0 { goToPreviousPage() } else { goToNextPage() }
            if currentPage != wasPage {
                selection = next < 0 ? navigableIdentifiers.last : navigableIdentifiers.first
                return
            }
        }

        selection = identifiers[max(0, min(identifiers.count - 1, next))]
    }

    /// What the arrow keys walk: the search results, the open folder, or the
    /// current page.
    private var navigableIdentifiers: [String] {
        if isSearching { return searchResults.map(\.bundleIdentifier) }
        if let openFolder { return openFolder.appIdentifiers }
        return items(onPage: currentPage).compactMap(\.appIdentifier)
    }

    /// Resets transient state so a reopened launcher does not come back on the
    /// half-typed search of the last one.
    public func prepareForPresentation() {
        query = ""
        openFolder = nil
        selection = nil
    }
}
