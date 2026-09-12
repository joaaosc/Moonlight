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

    /// Where the answer is remembered that the system prompt was spent.
    ///
    /// macOS presents the accessibility prompt once per app. Every call after
    /// that returns normally and shows nothing, so a button wired only to the
    /// prompt does nothing at all from the second press onwards — which is
    /// exactly what it looks like to the user. The app cannot read that state
    /// back out of the system, so it records its own ask.
    static let hasAskedDefaultsKey = "MoonlightHasAskedForAccessibility"

    /// The Accessibility list in System Settings.
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    /// Takes the user to where the permission can be granted.
    ///
    /// The first press asks the system to prompt, which is the shortest path
    /// when it still works. Afterwards the prompt is spent, so the press opens
    /// the Settings pane instead: the same destination the prompt's own button
    /// leads to, and the only one that keeps working.
    ///
    /// The key is spelled out rather than read from `kAXTrustedCheckOptionPrompt`:
    /// that symbol is a mutable global, which strict concurrency rejects, and
    /// its value is a documented constant.
    @MainActor
    public static func requestPermission(defaults: UserDefaults = .standard) {
        switch permissionStep(consuming: defaults) {
        case .prompt:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .settings:
            openSettings()
        }
    }

    /// What pressing the button should do.
    enum PermissionStep: Equatable {
        /// Ask the system to prompt: only the first ask is ever shown.
        case prompt
        /// Open the Settings pane, because the prompt would show nothing.
        case settings
    }

    /// Decides the step and records that the ask happened.
    ///
    /// Separated from carrying it out so the rule can be tested without
    /// prompting the machine running the tests or opening its System Settings.
    static func permissionStep(consuming defaults: UserDefaults) -> PermissionStep {
        guard !defaults.bool(forKey: hasAskedDefaultsKey) else { return .settings }
        defaults.set(true, forKey: hasAskedDefaultsKey)
        return .prompt
    }

    /// Opens the Accessibility list, where Moonlight has to be switched on.
    @MainActor
    public static func openSettings() {
        guard let settingsURL else { return }
        NSWorkspace.shared.open(settingsURL)
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
