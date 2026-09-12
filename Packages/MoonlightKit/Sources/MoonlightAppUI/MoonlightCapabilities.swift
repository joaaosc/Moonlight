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

    /// Accessibility is what the menu bar reads the active app's shortcuts
    /// with. Reported as unused it looked optional, and a user looking for why
    /// the section is empty found nothing here.
    ///
    /// "Denied" and "not requested" are told apart by the app's own record of
    /// having asked: the system answers whether the permission is held, never
    /// whether it was refused.
    public static func accessibility(defaults: UserDefaults = .standard) -> MoonlightCapability {
        let status: Status = if AXIsProcessTrusted() {
            .granted
        } else if defaults.bool(forKey: ActiveAppShortcutsReader.hasAskedDefaultsKey) {
            .denied
        } else {
            .notDetermined
        }
        return MoonlightCapability(
            name: "Accessibility",
            status: status,
            detail: "Needed to read the active app's keyboard shortcuts in the menu bar. Granted under Privacy & Security in System Settings."
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
