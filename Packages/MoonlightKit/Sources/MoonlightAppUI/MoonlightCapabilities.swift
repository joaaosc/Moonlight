import ApplicationServices
import Foundation
import MoonlightDomain

/// An optional system capability Moonlight can use.
///
/// Every entry is inspected without asking for anything: a capability is
/// requested only from an explicit user action, and never as a side effect of
/// opening a settings pane.
public struct MoonlightCapability: Sendable, Equatable, Identifiable {
    public enum Status: String, Sendable, Equatable {
        case granted
        case denied
        case notDetermined
        case notUsedYet

        public var summary: String {
            switch self {
            case .granted: "Granted"
            case .denied: "Denied"
            case .notDetermined: "Not requested"
            case .notUsedYet: "Not used"
            }
        }
    }

    public let name: String
    public let status: Status
    public let detail: String

    public var id: String { name }

    public init(name: String, status: Status, detail: String) {
        self.name = name
        self.status = status
        self.detail = detail
    }

    /// Accessibility is not used by any current feature. Reporting it as unused
    /// keeps the list honest instead of implying a pending request.
    public static func accessibility() -> MoonlightCapability {
        MoonlightCapability(
            name: "Accessibility",
            status: AXIsProcessTrusted() ? .granted : .notUsedYet,
            detail: "No Moonlight feature reads or controls other apps' windows today."
        )
    }

    public static func appleEvents(status: ShortcutsAuthorizationStatus) -> MoonlightCapability {
        let mapped: Status = switch status {
        case .authorized: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        case .unavailable: .notUsedYet
        }
        return MoonlightCapability(
            name: "Automation (Shortcuts)",
            status: mapped,
            detail: "Needed to list and run your shortcuts. Requested when you load the library."
        )
    }
}
