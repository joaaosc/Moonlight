import Foundation

/// One shortcut as the Shortcuts scripting dictionary describes it.
///
/// `acceptsInput` mirrors the `accepts input` property and says only that the
/// shortcut takes an input value. It is not a parameter schema: a shortcut can
/// still open its own UI, ask for access or fail for reasons Moonlight cannot
/// see from here.
public struct ShortcutSummary: Codable, Equatable, Identifiable, Sendable {
    /// The identifier owned by Shortcuts. Names are not unique and can change.
    public let externalID: String
    public let name: String
    public let subtitle: String
    public let acceptsInput: Bool
    public let actionCount: Int

    public var id: String { externalID }

    public init(
        externalID: String,
        name: String,
        subtitle: String = "",
        acceptsInput: Bool = false,
        actionCount: Int = 0
    ) {
        self.externalID = externalID
        self.name = name
        self.subtitle = subtitle
        self.acceptsInput = acceptsInput
        self.actionCount = actionCount
    }
}

/// Why a listing could not be produced. Each case is a distinct state the UI
/// can recover from; none of them may be reported as an empty library.
public enum ShortcutsClientError: Error, Equatable, LocalizedError, Sendable, CodedActionError {
    /// The user has not granted Moonlight permission to control Shortcuts, or
    /// the entitlement is missing from the signed build.
    case notAuthorized
    /// Shortcuts Events did not answer as a scriptable target.
    case unavailable
    /// The Apple Event did not answer in time. This does not prove the other
    /// side stopped, so no automatic retry follows it.
    case timedOut
    case shortcutNotFound(externalID: String)
    /// The bridge answered with something Moonlight cannot interpret.
    case bridgeFailure(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Moonlight is not allowed to control Shortcuts. Grant access in Privacy & Security ▸ Automation."
        case .unavailable:
            "Shortcuts Events did not respond on this Mac."
        case .timedOut:
            "Shortcuts did not answer in time. Moonlight did not retry."
        case let .shortcutNotFound(externalID):
            "The shortcut \(externalID) no longer exists in Shortcuts."
        case let .bridgeFailure(message):
            "Moonlight could not read the Shortcuts library: \(message)"
        }
    }

    public var failureCode: String {
        switch self {
        case .notAuthorized: "shortcuts-not-authorized"
        case .unavailable: "shortcuts-unavailable"
        case .timedOut: "shortcuts-timed-out"
        case .shortcutNotFound: "shortcut-not-found"
        case .bridgeFailure: "shortcuts-bridge-failure"
        }
    }
}
