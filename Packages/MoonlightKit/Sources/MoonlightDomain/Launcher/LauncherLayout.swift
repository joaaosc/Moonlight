import Foundation

/// The shape of one launcher page.
///
/// Capacity is part of the layout rather than of the view because the layout is
/// what has to decide where an app lands, and that answer changes with the
/// number of slots on a page.
public struct LauncherGrid: Sendable, Hashable, Codable {
    public let columns: Int
    public let rows: Int

    public var capacity: Int { columns * rows }

    public init(columns: Int, rows: Int) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    public static let standard = LauncherGrid(columns: 7, rows: 5)
}

/// A group of apps the user made by dropping one app onto another.
public struct LauncherFolder: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var appIdentifiers: [String]

    public init(id: UUID = UUID(), name: String, appIdentifiers: [String]) {
        self.id = id
        self.name = name
        self.appIdentifiers = appIdentifiers
    }
}

/// What occupies one slot on a page.
///
/// `empty` carries an identifier so a hole is as identifiable as anything else
/// in the grid: SwiftUI animates a move only when it can tell which element
/// moved, and a hole that changed identity on every reconcile would make every
/// rearrangement look like a full redraw.
public enum LauncherItem: Sendable, Equatable, Codable, Identifiable {
    case empty(UUID)
    case app(String)
    case folder(LauncherFolder)

    public var id: String {
        switch self {
        case let .empty(identifier): "empty:\(identifier.uuidString)"
        case let .app(bundleIdentifier): "app:\(bundleIdentifier)"
        case let .folder(folder): "folder:\(folder.id.uuidString)"
        }
    }

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    public var appIdentifier: String? {
        if case let .app(identifier) = self { return identifier }
        return nil
    }

    public var folder: LauncherFolder? {
        if case let .folder(folder) = self { return folder }
        return nil
    }

    /// Every app this item accounts for, whether loose or inside a folder.
    public var containedAppIdentifiers: [String] {
        switch self {
        case .empty: []
        case let .app(identifier): [identifier]
        case let .folder(folder): folder.appIdentifiers
        }
    }

    public static func empty() -> LauncherItem { .empty(UUID()) }
}

/// Where an item sits.
public struct LauncherPosition: Sendable, Hashable, Codable {
    public let page: Int
    public let slot: Int

    public init(page: Int, slot: Int) {
        self.page = page
        self.slot = slot
    }
}

/// The user's arrangement of the launcher: which apps sit where, which are
/// grouped, and which are hidden.
///
/// It is deliberately a description of *positions*, not of apps. Which apps
/// exist is the catalogue's business; reconciling the two is
/// ``LauncherLayoutReconciler``'s. Keeping them apart is what lets the
/// arrangement survive an app being uninstalled and reinstalled.
public struct LauncherLayout: Sendable, Equatable, Codable {
    public var grid: LauncherGrid
    public var pages: [[LauncherItem]]
    /// Apps the user removed from the grid without uninstalling them. Kept so
    /// reconciliation does not helpfully add them back on the next launch.
    public var hiddenAppIdentifiers: Set<String>

    public init(
        grid: LauncherGrid = .standard,
        pages: [[LauncherItem]] = [],
        hiddenAppIdentifiers: Set<String> = []
    ) {
        self.grid = grid
        self.pages = pages
        self.hiddenAppIdentifiers = hiddenAppIdentifiers
    }

    public static let empty = LauncherLayout()

    // MARK: - Reading

    public var pageCount: Int { pages.count }

    public func item(at position: LauncherPosition) -> LauncherItem? {
        guard pages.indices.contains(position.page),
              pages[position.page].indices.contains(position.slot)
        else { return nil }
        return pages[position.page][position.slot]
    }

    /// Every app the layout places, loose or foldered, in reading order.
    public var placedAppIdentifiers: [String] {
        pages.flatMap { $0.flatMap(\.containedAppIdentifiers) }
    }

    public func position(ofApp bundleIdentifier: String) -> LauncherPosition? {
        for (pageIndex, page) in pages.enumerated() {
            for (slotIndex, item) in page.enumerated()
            where item.containedAppIdentifiers.contains(bundleIdentifier) {
                return LauncherPosition(page: pageIndex, slot: slotIndex)
            }
        }
        return nil
    }

    // MARK: - Shape

    /// Pads every page to the grid's capacity and drops pages that hold
    /// nothing, so the rest of the type can assume a rectangular grid.
    ///
    /// The first page always survives: a launcher with no page at all has no
    /// place to drop anything into.
    public mutating func normalize() {
        for index in pages.indices {
            if pages[index].count > grid.capacity {
                let overflow = Array(pages[index].dropFirst(grid.capacity))
                pages[index] = Array(pages[index].prefix(grid.capacity))
                insertOverflow(overflow, after: index)
            }
            while pages[index].count < grid.capacity {
                pages[index].append(.empty())
            }
        }

        while pages.count > 1, pages.last?.allSatisfy(\.isEmpty) == true {
            pages.removeLast()
        }
        if pages.isEmpty {
            pages = [Self.blankPage(capacity: grid.capacity)]
        }
    }

    public func normalized() -> LauncherLayout {
        var copy = self
        copy.normalize()
        return copy
    }

    private mutating func insertOverflow(_ overflow: [LauncherItem], after index: Int) {
        let occupied = overflow.filter { !$0.isEmpty }
        guard !occupied.isEmpty else { return }
        var page = Self.blankPage(capacity: grid.capacity)
        for (slot, item) in occupied.prefix(grid.capacity).enumerated() {
            page[slot] = item
        }
        pages.insert(page, at: index + 1)
    }

    static func blankPage(capacity: Int) -> [LauncherItem] {
        (0 ..< capacity).map { _ in .empty() }
    }

    /// The first free slot, adding a page when every existing one is full.
    public mutating func firstFreePosition() -> LauncherPosition {
        normalize()
        for (pageIndex, page) in pages.enumerated() {
            if let slot = page.firstIndex(where: \.isEmpty) {
                return LauncherPosition(page: pageIndex, slot: slot)
            }
        }
        pages.append(Self.blankPage(capacity: grid.capacity))
        return LauncherPosition(page: pages.count - 1, slot: 0)
    }

    // MARK: - Rearranging

    /// Moves an item, pushing the items between source and destination along
    /// rather than swapping with whatever sat there.
    ///
    /// Swapping is the easier implementation and the wrong behaviour: dragging
    /// an app three slots to the left should not fling the app that was there
    /// across the page.
    public mutating func move(from source: LauncherPosition, to destination: LauncherPosition) {
        normalize()
        guard let moved = item(at: source), !moved.isEmpty,
              pages.indices.contains(destination.page),
              pages[destination.page].indices.contains(destination.slot),
              source != destination
        else { return }

        pages[source.page][source.slot] = .empty()

        if source.page == destination.page {
            shift(on: destination.page, from: source.slot, to: destination.slot)
        } else {
            // Across pages the destination page has to give up a slot, so the
            // displaced tail rolls forward into the following pages.
            insert(moved, on: destination.page, at: destination.slot)
            return
        }

        pages[destination.page][destination.slot] = moved
    }

    /// Closes the gap left at `origin` by walking the items between the two
    /// slots one place toward it.
    private mutating func shift(on page: Int, from origin: Int, to destination: Int) {
        guard origin != destination else { return }
        if origin < destination {
            for slot in origin ..< destination {
                pages[page][slot] = pages[page][slot + 1]
            }
        } else {
            for slot in stride(from: origin, to: destination, by: -1) {
                pages[page][slot] = pages[page][slot - 1]
            }
        }
    }

    /// Inserts at a slot, pushing the rest of the page down and spilling the
    /// last item onto the next page.
    private mutating func insert(_ item: LauncherItem, on page: Int, at slot: Int) {
        guard pages.indices.contains(page) else { return }
        pages[page].insert(item, at: slot)
        var carried = pages[page].removeLast()
        var index = page + 1
        while !carried.isEmpty {
            if index >= pages.count {
                pages.append(Self.blankPage(capacity: grid.capacity))
            }
            pages[index].insert(carried, at: 0)
            carried = pages[index].removeLast()
            index += 1
        }
        normalize()
    }

    // MARK: - Folders

    /// Groups the app at `source` with whatever sits at `destination`: a second
    /// app becomes a new folder, an existing folder simply gains a member.
    @discardableResult
    public mutating func group(
        _ source: LauncherPosition,
        into destination: LauncherPosition,
        folderName: (String) -> String = { $0 }
    ) -> Bool {
        normalize()
        guard source != destination,
              let dragged = item(at: source), let target = item(at: destination),
              let draggedApp = dragged.appIdentifier
        else { return false }

        switch target {
        case var .folder(folder):
            guard !folder.appIdentifiers.contains(draggedApp) else { return false }
            folder.appIdentifiers.append(draggedApp)
            pages[destination.page][destination.slot] = .folder(folder)
        case let .app(targetApp):
            let folder = LauncherFolder(
                name: folderName(targetApp),
                appIdentifiers: [targetApp, draggedApp]
            )
            pages[destination.page][destination.slot] = .folder(folder)
        case .empty:
            return false
        }

        pages[source.page][source.slot] = .empty()
        return true
    }

    /// Takes an app back out of a folder and drops it in the first free slot.
    ///
    /// A folder left with one app is dissolved: a folder of one is a box around
    /// a single icon, which is strictly worse than the icon.
    @discardableResult
    public mutating func ungroup(
        app bundleIdentifier: String,
        from position: LauncherPosition
    ) -> Bool {
        normalize()
        guard var folder = item(at: position)?.folder,
              folder.appIdentifiers.contains(bundleIdentifier)
        else { return false }

        folder.appIdentifiers.removeAll { $0 == bundleIdentifier }

        switch folder.appIdentifiers.count {
        case 0:
            pages[position.page][position.slot] = .empty()
        case 1:
            pages[position.page][position.slot] = .app(folder.appIdentifiers[0])
        default:
            pages[position.page][position.slot] = .folder(folder)
        }

        let free = firstFreePosition()
        pages[free.page][free.slot] = .app(bundleIdentifier)
        return true
    }

    @discardableResult
    public mutating func renameFolder(at position: LauncherPosition, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var folder = item(at: position)?.folder else { return false }
        folder.name = trimmed
        pages[position.page][position.slot] = .folder(folder)
        return true
    }

    // MARK: - Hiding

    /// Removes an app from the grid without uninstalling it, and remembers the
    /// choice so reconciliation does not undo it.
    public mutating func hide(app bundleIdentifier: String) {
        hiddenAppIdentifiers.insert(bundleIdentifier)
        remove(app: bundleIdentifier)
    }

    public mutating func reveal(app bundleIdentifier: String) {
        hiddenAppIdentifiers.remove(bundleIdentifier)
    }

    /// Clears an app out of the grid, leaving a hole where it sat and
    /// collapsing any folder that is left too small to be one.
    mutating func remove(app bundleIdentifier: String) {
        for pageIndex in pages.indices {
            for slotIndex in pages[pageIndex].indices {
                switch pages[pageIndex][slotIndex] {
                case let .app(identifier) where identifier == bundleIdentifier:
                    pages[pageIndex][slotIndex] = .empty()
                case var .folder(folder) where folder.appIdentifiers.contains(bundleIdentifier):
                    folder.appIdentifiers.removeAll { $0 == bundleIdentifier }
                    pages[pageIndex][slotIndex] = switch folder.appIdentifiers.count {
                    case 0: .empty()
                    case 1: .app(folder.appIdentifiers[0])
                    default: .folder(folder)
                    }
                default:
                    continue
                }
            }
        }
    }
}
