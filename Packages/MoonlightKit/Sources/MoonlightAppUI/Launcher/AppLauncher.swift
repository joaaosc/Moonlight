import AppKit
import MoonlightDomain
import OSLog

/// Opens an installed application.
///
/// This works from inside the App Sandbox, which was measured rather than
/// assumed before the launcher was designed around it: Launch Services performs
/// the launch, so the sandboxed process is asking for it, not doing it. No
/// entitlement beyond the existing ones is involved, and no helper process.
@MainActor
public struct AppLauncher: Sendable {
    private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "Launcher"
    )

    public init() {}

    /// Opens `app`, bringing it to the front.
    ///
    /// Failure is reported to the log and swallowed: an app that refuses to
    /// launch is the system's answer, and turning it into an error dialog over
    /// a launcher the user is about to dismiss helps nobody.
    @discardableResult
    public func open(_ app: InstalledApp) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: app.url,
                configuration: configuration
            )
            return true
        } catch {
            Self.logger.error(
                "Failed to open \(app.bundleIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
