import AppKit

/// Where the user was when Moonlight was invoked.
///
/// Captured before Moonlight activates, because after activation the frontmost
/// application is Moonlight itself and the origin is lost.
public struct MoonlightSourceContext: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let name: String

    public init(bundleIdentifier: String?, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    /// The frontmost application, or nil when Moonlight is already in front.
    @MainActor
    public static func current(
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        frontmostApplication: NSRunningApplication? = NSWorkspace.shared.frontmostApplication
    ) -> MoonlightSourceContext? {
        guard let application = frontmostApplication else { return nil }
        guard application.bundleIdentifier != ownBundleIdentifier else { return nil }
        guard let name = application.localizedName else { return nil }
        return MoonlightSourceContext(
            bundleIdentifier: application.bundleIdentifier,
            name: name
        )
    }
}
