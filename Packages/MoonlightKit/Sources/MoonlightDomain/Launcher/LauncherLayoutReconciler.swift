import Foundation

/// Merges what is installed with where the user put it.
///
/// This is the rule the user notices when it is wrong: apps must not move
/// because something unrelated was installed or removed. So an uninstalled app
/// leaves a hole rather than pulling everything after it one slot back, and a
/// newly installed app fills the first hole rather than pushing anything aside.
///
/// The hole is the point. Collapsing is tidier to look at and destroys the
/// muscle memory that makes a launcher faster than search.
public struct LauncherLayoutReconciler: Sendable {
    /// How a newly seen app is sorted before being placed.
    public enum Arrival: Sendable {
        /// Alphabetical, the order a first run should produce.
        case byName
        /// The order the catalogue reported them in.
        case asGiven
    }

    private let arrival: Arrival

    public init(arrival: Arrival = .byName) {
        self.arrival = arrival
    }

    /// Returns `layout` updated to describe exactly the apps in `catalog`.
    ///
    /// - Apps in the layout that are no longer installed are removed, leaving
    ///   their slot empty and every other app where it was.
    /// - Apps in the catalogue that the layout does not place, and that the
    ///   user has not hidden, are added to the first free slots.
    /// - Hidden apps are never added back, even though they are installed.
    public func reconcile(
        layout: LauncherLayout,
        catalog: [InstalledApp]
    ) -> LauncherLayout {
        var reconciled = layout.normalized()

        let installed = Set(catalog.map(\.bundleIdentifier))
        for placed in Set(reconciled.placedAppIdentifiers) where !installed.contains(placed) {
            reconciled.remove(app: placed)
        }

        // A hidden app that was somehow placed is removed too: the two states
        // contradict each other, and the explicit choice wins.
        for hidden in reconciled.hiddenAppIdentifiers {
            reconciled.remove(app: hidden)
        }

        let placed = Set(reconciled.placedAppIdentifiers)
        var missing = catalog.filter {
            !placed.contains($0.bundleIdentifier)
                && !reconciled.hiddenAppIdentifiers.contains($0.bundleIdentifier)
        }
        if arrival == .byName {
            missing.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        for app in missing {
            let position = reconciled.firstFreePosition()
            reconciled.pages[position.page][position.slot] = .app(app.bundleIdentifier)
        }

        // Hidden entries for apps that no longer exist are dropped: keeping
        // them would grow the document forever with identifiers nothing can
        // ever match again.
        reconciled.hiddenAppIdentifiers.formIntersection(installed)

        reconciled.normalize()
        return reconciled
    }

    /// Builds the arrangement a machine with no saved layout should get.
    public func initialLayout(
        catalog: [InstalledApp],
        grid: LauncherGrid = .standard
    ) -> LauncherLayout {
        reconcile(layout: LauncherLayout(grid: grid), catalog: catalog)
    }
}
