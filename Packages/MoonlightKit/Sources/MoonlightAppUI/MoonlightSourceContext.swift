import AppKit

/// Where the user was when Moonlight was invoked.
///
/// The origin has to be read from before Moonlight activated, because after
/// activation the frontmost application is Moonlight itself. Asking the
/// workspace at presentation time is too late for every surface the user
/// reaches by clicking, so the answer comes from `FrontmostApplicationMonitor`,
/// which keeps watching activations rather than sampling one.
public struct MoonlightSourceContext: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let name: String

    public init(bundleIdentifier: String?, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    /// The application Moonlight was invoked from, or nil when there is none
    /// to name.
    @MainActor
    public static func current(
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        frontmostApplication: NSRunningApplication? = FrontmostApplicationMonitor.shared.origin()
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
