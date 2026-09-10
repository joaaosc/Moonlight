import CoreServices
import Foundation
import MoonlightDomain
import ScriptingBridge

/// Reads the user's Shortcuts library through Shortcuts Events.
///
/// Apple Events are synchronous and blocking, so the work is serialized on this
/// actor and never on the main actor. The type lives in its own module: the App
/// Intents extension links the rest of MoonlightKit and must not gain an Apple
/// Events dependency, since sending them from an extension is not supported.
public actor ShortcutsEventsClient {
    /// Shortcuts Events runs shortcuts without opening the Shortcuts app.
    public static let bundleIdentifier = "com.apple.shortcuts.events"
    /// The scripting access group the sandbox entitlement must name.
    public static let accessGroup = "com.apple.shortcuts.run"

    private let timeoutInTicks: Int

    /// - Parameter timeout: how long to wait for an answer. A timeout does not
    ///   prove the other side stopped, so it never triggers a retry.
    public init(timeout: Duration = .seconds(10)) {
        let seconds = Double(timeout.components.seconds)
            + Double(timeout.components.attoseconds) / 1e18
        timeoutInTicks = max(1, Int((seconds * 60).rounded()))
    }

    /// Adapts this actor to the domain contract.
    public nonisolated func catalogClient() -> ShortcutsCatalogClient {
        ShortcutsCatalogClient(
            authorizationStatus: { [self] askingUser in
                await authorizationStatus(askingUser: askingUser)
            },
            list: { [self] in try await list() },
            shortcut: { [self] externalID in try await shortcut(externalID: externalID) }
        )
    }

    /// Queries Apple Events permission. With `askingUser` false the system
    /// answers without showing a consent prompt.
    ///
    /// This is a preflight, not a gate. It cannot decide anything while the
    /// target is not running, so callers send the event and use this only to
    /// explain a failure.
    public func authorizationStatus(askingUser: Bool) -> ShortcutsAuthorizationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: Self.bundleIdentifier)
        guard let descriptor = target.aeDesc else { return .unavailable }
        let status = AEDeterminePermissionToAutomateTarget(
            descriptor,
            typeWildCard,
            typeWildCard,
            askingUser
        )

        switch status {
        case noErr:
            return .authorized
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(procNotFound):
            // Shortcuts Events is a faceless helper: it is not running until an
            // event is sent to it, and the preflight answers `procNotFound`
            // while that is the case. Not running says nothing about
            // permission, so the caller must stay free to try.
            return .notDetermined
        case OSStatus(connectionInvalid):
            return .unavailable
        default:
            return .denied
        }
    }

    /// The whole library, as Shortcuts reports it. Listing never runs anything.
    public func list() throws -> [ShortcutSummary] {
        try withBridge { application, delegate in
            guard let elements = application.shortcuts?() else {
                throw ShortcutsClientError.unavailable
            }
            let objects = elements.get() ?? []
            if let error = delegate.lastError {
                throw Self.clientError(from: error)
            }
            return objects.compactMap(Self.summary(from:))
        }
    }

    /// One shortcut resolved by the identifier Shortcuts owns. Names are not
    /// unique and can be renamed; the identifier is what a binding stores.
    public func shortcut(externalID: String) throws -> ShortcutSummary? {
        try withBridge { application, delegate in
            guard let elements = application.shortcuts?() else {
                throw ShortcutsClientError.unavailable
            }
            let object = elements.object(withID: externalID)
            if let error = delegate.lastError {
                let clientError = Self.clientError(from: error)
                // A missing shortcut is an answer, not a failure to reach it.
                if case .shortcutNotFound = clientError { return nil }
                throw clientError
            }
            guard let summary = Self.summary(from: object as Any) else { return nil }
            // Scripting Bridge can hand back a live reference for an ID that no
            // longer resolves; the returned identifier is what settles it.
            return summary.externalID == externalID ? summary : nil
        }
    }

    internal func withBridge<Value>(
        _ body: (any ShortcutsEventsApplication, ShortcutsEventsBridgeDelegate) throws -> Value
    ) throws -> Value {
        guard let application = SBApplication(bundleIdentifier: Self.bundleIdentifier) else {
            throw ShortcutsClientError.unavailable
        }
        let delegate = ShortcutsEventsBridgeDelegate()
        application.delegate = delegate
        application.timeout = timeoutInTicks
        // Shortcuts Events is a faceless helper; it must not be brought forward.
        application.launchFlags = [.defaults, .andHide]

        return try withExtendedLifetime(delegate) {
            try body(application, delegate)
        }
    }

    private static func summary(from object: Any) -> ShortcutSummary? {
        guard
            let shortcut = object as? ShortcutsEventsShortcut,
            let externalID = shortcut.id,
            !externalID.isEmpty,
            let name = shortcut.name
        else {
            return nil
        }

        return ShortcutSummary(
            externalID: externalID,
            name: name,
            subtitle: shortcut.subtitle ?? "",
            acceptsInput: shortcut.acceptsInput ?? false,
            actionCount: shortcut.actionCount ?? 0
        )
    }

    internal static func clientError(
        from error: NSError,
        externalID: String = ""
    ) -> ShortcutsClientError {
        let code = (error.userInfo["ErrorNumber"] as? NSNumber)?.intValue ?? error.code
        switch code {
        case Int(errAEEventNotPermitted), Int(errAEPrivilegeError):
            return .notAuthorized
        case Int(errAETimeout):
            return .timedOut
        case Int(procNotFound), Int(connectionInvalid), Int(errAEEventNotHandled):
            return .unavailable
        case Int(errAENoSuchObject), Int(errAEIllegalIndex):
            return .shortcutNotFound(externalID: externalID)
        default:
            let message = error.userInfo["ErrorString"] as? String
                ?? error.localizedDescription
            return .bridgeFailure(message)
        }
    }
}
