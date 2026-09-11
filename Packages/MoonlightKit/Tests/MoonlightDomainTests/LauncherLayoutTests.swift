import Foundation
import MoonlightDomain
import Testing

private func app(_ identifier: String, named name: String? = nil) -> InstalledApp {
    InstalledApp(
        bundleIdentifier: identifier,
        url: URL(fileURLWithPath: "/Applications/\(identifier).app"),
        name: name ?? identifier
    )
}

/// A small grid keeps the expectations readable: six slots is enough to show
/// paging without writing out thirty-five entries per assertion.
private let smallGrid = LauncherGrid(columns: 3, rows: 2)

@Suite("Launcher layout")
struct LauncherLayoutTests {
    @Test("Normalizing pads every page to the grid capacity")
    func normalizePads() {
        var layout = LauncherLayout(grid: smallGrid, pages: [[.app("a")]])
        layout.normalize()

        #expect(layout.pages.count == 1)
        #expect(layout.pages[0].count == 6)
        #expect(layout.pages[0][0].appIdentifier == "a")
        let restIsEmpty = layout.pages[0].dropFirst().allSatisfy(\.isEmpty)
        #expect(restIsEmpty)
    }

    @Test("A layout with no pages still offers one to drop into")
    func normalizeKeepsOnePage() {
        var layout = LauncherLayout(grid: smallGrid)
        layout.normalize()

        #expect(layout.pageCount == 1)
    }

    @Test("Overflowing a page spills onto the next one")
    func normalizeSpills() {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [(0 ..< 8).map { .app("app\($0)") }]
        )
        layout.normalize()

        let first = layout.pages[0].compactMap(\.appIdentifier)
        let second = layout.pages[1].compactMap(\.appIdentifier)

        #expect(layout.pageCount == 2)
        #expect(first.count == 6)
        #expect(second == ["app6", "app7"])
    }

    @Test("Moving within a page shifts the items between, rather than swapping")
    func moveShifts() {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .app("b"), .app("c"), .app("d"), .empty(), .empty()]]
        )

        layout.move(
            from: LauncherPosition(page: 0, slot: 3),
            to: LauncherPosition(page: 0, slot: 1)
        )

        let identifiers = layout.pages[0].compactMap(\.appIdentifier)
        #expect(identifiers == ["a", "d", "b", "c"])
    }

    @Test("Moving forward shifts the other way")
    func moveShiftsForward() {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .app("b"), .app("c"), .empty(), .empty(), .empty()]]
        )

        layout.move(
            from: LauncherPosition(page: 0, slot: 0),
            to: LauncherPosition(page: 0, slot: 2)
        )

        let identifiers = layout.pages[0].compactMap(\.appIdentifier)
        #expect(identifiers == ["b", "c", "a"])
    }

    @Test("Dropping an app onto another makes a folder holding both")
    func groupMakesFolder() {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .app("b"), .empty(), .empty(), .empty(), .empty()]]
        )

        let grouped = layout.group(
            LauncherPosition(page: 0, slot: 0),
            into: LauncherPosition(page: 0, slot: 1),
            folderName: { _ in "Utilities" }
        )

        #expect(grouped)
        #expect(layout.pages[0][0].isEmpty)
        let folder = layout.pages[0][1].folder
        #expect(folder?.name == "Utilities")
        #expect(folder?.appIdentifiers == ["b", "a"])
    }

    @Test("Dropping onto an existing folder adds to it")
    func groupExtendsFolder() {
        let folder = LauncherFolder(name: "Utilities", appIdentifiers: ["b", "c"])
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .folder(folder), .empty(), .empty(), .empty(), .empty()]]
        )

        let grouped = layout.group(
            LauncherPosition(page: 0, slot: 0),
            into: LauncherPosition(page: 0, slot: 1)
        )

        #expect(grouped)
        #expect(layout.pages[0][1].folder?.appIdentifiers == ["b", "c", "a"])
    }

    @Test("Taking the second-to-last app out dissolves the folder")
    func ungroupDissolves() {
        let folder = LauncherFolder(name: "Utilities", appIdentifiers: ["a", "b"])
        var layout = LauncherLayout(grid: smallGrid, pages: [[.folder(folder)]])
        layout.normalize()

        let ungrouped = layout.ungroup(app: "a", from: LauncherPosition(page: 0, slot: 0))

        #expect(ungrouped)
        let identifiers = layout.pages[0].compactMap(\.appIdentifier)
        #expect(identifiers.sorted() == ["a", "b"])
        let hasNoFolder = layout.pages[0].allSatisfy { $0.folder == nil }
        #expect(hasNoFolder)
    }

    @Test("Hiding an app removes it from the grid and remembers the choice")
    func hideRemembers() {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .app("b"), .empty(), .empty(), .empty(), .empty()]]
        )

        layout.hide(app: "a")

        #expect(layout.hiddenAppIdentifiers == ["a"])
        #expect(layout.placedAppIdentifiers == ["b"])
        #expect(layout.pages[0][0].isEmpty)
    }

    @Test("Hiding an app that lives in a folder shrinks the folder")
    func hideInsideFolder() {
        let folder = LauncherFolder(name: "Utilities", appIdentifiers: ["a", "b", "c"])
        var layout = LauncherLayout(grid: smallGrid, pages: [[.folder(folder)]])
        layout.normalize()

        layout.hide(app: "b")

        #expect(layout.pages[0][0].folder?.appIdentifiers == ["a", "c"])
    }

    @Test("Empty slots keep their identity across a normalize")
    func emptyIdentityIsStable() {
        var layout = LauncherLayout(grid: smallGrid, pages: [[.app("a")]])
        layout.normalize()
        let before = layout.pages[0].map(\.id)

        layout.normalize()

        let after = layout.pages[0].map(\.id)
        #expect(after == before)
    }

    @Test("A layout survives a round trip through JSON")
    func codableRoundTrip() throws {
        var layout = LauncherLayout(
            grid: smallGrid,
            pages: [[.app("a"), .folder(LauncherFolder(name: "Utilities", appIdentifiers: ["b", "c"]))]],
            hiddenAppIdentifiers: ["d"]
        )
        layout.normalize()

        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(LauncherLayout.self, from: data)

        #expect(decoded == layout)
    }
}

@Suite("Launcher layout reconciliation")
struct LauncherLayoutReconcilerTests {
    private let reconciler = LauncherLayoutReconciler()

    @Test("A first run arranges everything alphabetically")
    func initialLayoutSortsByName() {
        let layout = reconciler.initialLayout(
            catalog: [app("c", named: "Chess"), app("a", named: "Automator"), app("b", named: "Books")],
            grid: smallGrid
        )

        #expect(layout.placedAppIdentifiers == ["a", "b", "c"])
    }

    @Test("An uninstalled app leaves a hole and moves nothing else")
    func uninstallLeavesHole() {
        var layout = reconciler.initialLayout(
            catalog: [app("a"), app("b"), app("c")],
            grid: smallGrid
        )
        let positionOfC = layout.position(ofApp: "c")

        layout = reconciler.reconcile(layout: layout, catalog: [app("a"), app("c")])

        #expect(layout.pages[0][1].isEmpty)
        #expect(layout.position(ofApp: "c") == positionOfC)
        #expect(layout.position(ofApp: "b") == nil)
    }

    @Test("A newly installed app fills the first hole")
    func installFillsHole() {
        var layout = reconciler.initialLayout(
            catalog: [app("a"), app("b"), app("c")],
            grid: smallGrid
        )
        layout = reconciler.reconcile(layout: layout, catalog: [app("a"), app("c")])

        layout = reconciler.reconcile(
            layout: layout,
            catalog: [app("a"), app("c"), app("d", named: "Dictionary")]
        )

        #expect(layout.pages[0][1].appIdentifier == "d")
        #expect(layout.pages[0][2].appIdentifier == "c")
    }

    @Test("A hidden app is not added back even though it is installed")
    func hiddenStaysHidden() {
        var layout = reconciler.initialLayout(catalog: [app("a"), app("b")], grid: smallGrid)
        layout.hide(app: "b")

        layout = reconciler.reconcile(layout: layout, catalog: [app("a"), app("b")])

        #expect(layout.placedAppIdentifiers == ["a"])
        #expect(layout.hiddenAppIdentifiers == ["b"])
    }

    @Test("Hiding is forgotten once the app is gone for good")
    func hiddenForgottenOnUninstall() {
        var layout = reconciler.initialLayout(catalog: [app("a"), app("b")], grid: smallGrid)
        layout.hide(app: "b")

        layout = reconciler.reconcile(layout: layout, catalog: [app("a")])

        #expect(layout.hiddenAppIdentifiers.isEmpty)
    }

    @Test("Apps inside folders count as placed and are left alone")
    func folderedAppsAreNotDuplicated() {
        let folder = LauncherFolder(name: "Utilities", appIdentifiers: ["a", "b"])
        var layout = LauncherLayout(grid: smallGrid, pages: [[.folder(folder)]])
        layout.normalize()

        layout = reconciler.reconcile(layout: layout, catalog: [app("a"), app("b")])

        #expect(layout.pages[0][0].folder?.appIdentifiers == ["a", "b"])
        #expect(layout.placedAppIdentifiers.sorted() == ["a", "b"])
    }

    @Test("More apps than one page holds spill onto another page")
    func overflowAddsPage() {
        let catalog = (0 ..< 8).map { app("app\($0)", named: "App \($0)") }

        let layout = reconciler.initialLayout(catalog: catalog, grid: smallGrid)

        #expect(layout.pageCount == 2)
        #expect(layout.placedAppIdentifiers.count == 8)
    }

    @Test("Reconciling twice with the same catalogue changes nothing")
    func reconcileIsIdempotent() {
        let catalog = [app("a"), app("b"), app("c")]
        let once = reconciler.initialLayout(catalog: catalog, grid: smallGrid)

        let twice = reconciler.reconcile(layout: once, catalog: catalog)

        #expect(twice == once)
    }
}
