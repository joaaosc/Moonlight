import Foundation

/// One keyboard shortcut the frontmost app publishes in its own menu bar.
///
/// A value, not a live accessibility handle: the menu bar is read once when
/// Moonlight opens and what is shown afterwards must not depend on the other
/// app still being in the state it was read from.
public struct ActiveAppShortcut: Identifiable, Hashable, Sendable {
    public var id: String { "\(menuTitle)/\(title)/\(keys)" }

    /// The menu the item was found under — "File", "Edit" — kept so two items
    /// with the same name stay distinguishable.
    public let menuTitle: String
    public let title: String
    /// The shortcut already rendered the way macOS writes it, e.g. `⌘⇧N`.
    public let keys: String

    public init(menuTitle: String, title: String, keys: String) {
        self.menuTitle = menuTitle
        self.title = title
        self.keys = keys
    }
}
