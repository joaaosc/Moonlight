import AppKit
import MoonlightDomain

/// Keeps the icon for each app so the grid asks the system once.
///
/// Deliberately synchronous. `NSImage` is not `Sendable` and neither is
/// `NSWorkspace`, so loading off the main actor would mean carrying an unsafe
/// promise across isolation; and the demand is bounded anyway, because the grid
/// is lazy and only the page on screen asks. What must not happen is asking
/// repeatedly for the same icon while the user pages back and forth, and that
/// is what this prevents.
@MainActor
public final class AppIconCache {
    public static let shared = AppIconCache()

    private var icons: [String: NSImage] = [:]

    public init() {}

    public func icon(for app: InstalledApp) -> NSImage {
        if let cached = icons[app.bundleIdentifier] { return cached }

        let icon = NSWorkspace.shared.icon(forFile: app.url.path)
        // The icon arrives with every representation the bundle carries. Fixing
        // the size here lets SwiftUI pick one instead of scaling the largest.
        icon.size = NSSize(width: 128, height: 128)
        icons[app.bundleIdentifier] = icon
        return icon
    }

    /// Drops icons for apps that are no longer installed, so a long-running
    /// process does not hold images for bundles that went away.
    public func retain(only installed: some Collection<String>) {
        let keep = Set(installed)
        icons = icons.filter { keep.contains($0.key) }
    }

    public func removeAll() {
        icons.removeAll()
    }
}
