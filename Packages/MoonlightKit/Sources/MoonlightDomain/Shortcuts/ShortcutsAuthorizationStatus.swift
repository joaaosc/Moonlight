import Foundation

/// Whether this process may send Apple Events to Shortcuts.
///
/// The states are kept apart on purpose: a library that cannot be read yet is
/// not an empty library, and a denial is recoverable by the user in System
/// Settings. Asking the system for the status must not be confused with
/// prompting: prompting happens only from an explicit user action.
public enum ShortcutsAuthorizationStatus: String, Codable, Equatable, Sendable {
    /// Moonlight may talk to Shortcuts.
    case authorized
    /// The user has never answered. Consent is requested by a user action.
    case notDetermined
    /// The user declined, or the signed build lacks the scripting entitlement.
    case denied
    /// Shortcuts Events is not available as a scripting target on this Mac.
    case unavailable

    public var allowsListing: Bool {
        self == .authorized
    }
}
