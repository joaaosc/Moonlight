import AppKit

/// Remembers which application was in front before Moonlight took activation.
///
/// Asking `NSWorkspace` at presentation time is already too late for anything
/// the user reaches by clicking: the menu bar popover only exists after the
/// status item has activated Moonlight, so by the time its content appears the
/// frontmost application is Moonlight itself and the origin is lost. The same
/// applies to a palette opened from a button inside another Moonlight surface.
///
/// Watching activations as they happen keeps the answer from before that
/// moment. Moonlight's own activations are ignored, so the value always names
/// the app the user was actually working in.
@MainActor
public final class FrontmostApplicationMonitor {
    /// The host installs one and every surface reads it.
    public static let shared = FrontmostApplicationMonitor()

    /// The last application to come forward that was not Moonlight.
    public private(set) var application: NSRunningApplication?

    private let ownBundleIdentifier: String?
    private var observation: Task<Void, Never>?

    public init(ownBundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    deinit {
        observation?.cancel()
    }

    /// Starts watching activations. A second call is ignored, so a surface may
    /// start it defensively without registering twice.
    public func start(workspace: NSWorkspace = .shared) {
        guard observation == nil else { return }
        record(workspace.frontmostApplication)

        let notifications = workspace.notificationCenter.notifications(
            named: NSWorkspace.didActivateApplicationNotification
        )
        observation = Task { [weak self] in
            for await notification in notifications {
                guard
                    let application = notification.userInfo?[
                        NSWorkspace.applicationUserInfoKey
                    ] as? NSRunningApplication
                else {
                    continue
                }
                self?.record(application)
            }
        }
    }

    /// Stops watching. The shared instance lives for the process; tests and
    /// previews use this to give the observation a bounded lifetime.
    public func stop() {
        observation?.cancel()
        observation = nil
    }

    /// Records an activation, keeping Moonlight's own out of the answer.
    func record(_ application: NSRunningApplication?) {
        guard let application else { return }
        guard application.bundleIdentifier != ownBundleIdentifier else { return }
        self.application = application
    }

    /// The application a presentation should be attributed to: whatever is in
    /// front right now, unless that is Moonlight, in which case the app it took
    /// activation from.
    ///
    /// Reading the live value first keeps the answer correct when the monitor
    /// was never started, which is the case in previews and tests.
    public func origin(
        frontmostApplication: NSRunningApplication? = NSWorkspace.shared.frontmostApplication
    ) -> NSRunningApplication? {
        if let frontmostApplication,
           frontmostApplication.bundleIdentifier != ownBundleIdentifier {
            return frontmostApplication
        }
        return application
    }
}
