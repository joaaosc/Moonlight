import AppKit
import ApplicationServices

/// Reads the frontmost application's own keyboard shortcuts from its menu bar.
///
/// The App Sandbox rules out the obvious route — a sandboxed process cannot
/// read another app's preferences, so `NSUserKeyEquivalents` is unreachable —
/// and it would only carry the user's customisations anyway. The accessibility
/// menu bar carries what the app actually publishes.
///
/// Reading is strictly one way: this inspects menu titles and never activates
/// an item.
public struct ActiveAppShortcutsReader: Sendable {
    /// How many items are worth showing. The menu bar of a large app holds
    /// hundreds; a menu bar popover is not where they belong.
    public static let limit = 8

    /// Menus whose contents belong to macOS rather than to the app, so they
    /// say nothing about what the user is working in.
    private static let ignoredMenuTitles: Set<String> = ["Window", "Help"]

    public init() {}

    /// Whether macOS has granted Moonlight the accessibility permission this
    /// needs. Never prompts: the prompt belongs to a button the user pressed.
    public static var isPermitted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the accessibility prompt.
    ///
    /// The key is spelled out rather than read from `kAXTrustedCheckOptionPrompt`:
    /// that symbol is a mutable global, which strict concurrency rejects, and
    /// its value is a documented constant.
    public static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Reads the shortcuts of the application with this process identifier.
    ///
    /// The caller passes a pid rather than an `NSRunningApplication` because
    /// the frontmost app has to be captured before Moonlight activates, which
    /// is a different moment from when this runs.
    public func shortcuts(forProcessIdentifier pid: pid_t) -> [ActiveAppShortcut] {
        guard Self.isPermitted else { return [] }

        let application = AXUIElementCreateApplication(pid)
        guard let menuBar = Self.element(application, attribute: kAXMenuBarAttribute) else {
            return []
        }

        var found: [ActiveAppShortcut] = []
        // The first child is the Apple menu, which belongs to the system.
        for menu in Self.children(of: menuBar).dropFirst() {
            let menuTitle = Self.string(menu, attribute: kAXTitleAttribute) ?? ""
            guard !Self.ignoredMenuTitles.contains(menuTitle) else { continue }

            // A menu holds a single list child, and the items hang off that.
            for item in Self.children(of: menu).flatMap(Self.children(of:)) {
                guard found.count < Self.limit else { return found }
                guard let shortcut = Self.shortcut(item, menuTitle: menuTitle) else { continue }
                found.append(shortcut)
            }
        }
        return found
    }

    private static func shortcut(
        _ item: AXUIElement,
        menuTitle: String
    ) -> ActiveAppShortcut? {
        guard let title = string(item, attribute: kAXTitleAttribute), !title.isEmpty else {
            return nil
        }
        guard let character = string(item, attribute: kAXMenuItemCmdCharAttribute),
              !character.isEmpty else {
            return nil
        }
        // A disabled item is not something the user can reach right now.
        guard bool(item, attribute: kAXEnabledAttribute) ?? true else { return nil }

        let modifiers = integer(item, attribute: kAXMenuItemCmdModifiersAttribute) ?? 0
        return ActiveAppShortcut(
            menuTitle: menuTitle,
            title: title,
            keys: keyEquivalent(character: character, modifiers: modifiers)
        )
    }

    /// Renders the modifier mask the way macOS writes it.
    ///
    /// The mask is the one `kAXMenuItemCmdModifiers` uses: Command is implied
    /// unless bit 3 says otherwise, and the remaining bits add to it.
    static func keyEquivalent(character: String, modifiers: Int) -> String {
        var keys = ""
        if modifiers & 0x04 != 0 { keys += "⌃" }
        if modifiers & 0x02 != 0 { keys += "⌥" }
        if modifiers & 0x01 != 0 { keys += "⇧" }
        if modifiers & 0x08 == 0 { keys += "⌘" }
        return keys + character.uppercased()
    }

    // MARK: - Accessibility reading

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &value
        ) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    private static func element(
        _ element: AXUIElement,
        attribute: String
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private static func integer(_ element: AXUIElement, attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return (value as? NSNumber)?.intValue
    }

    private static func bool(_ element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }
}
