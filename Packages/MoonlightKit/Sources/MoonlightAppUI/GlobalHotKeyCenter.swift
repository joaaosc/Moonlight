import AppKit
import Carbon.HIToolbox
import Observation
import OSLog

/// Why a chosen shortcut is not active.
public enum GlobalHotKeyFailure: Equatable, Sendable {
    /// Another application already owns the combination. macOS refuses the
    /// registration; Moonlight shows it instead of pretending it worked.
    case alreadyInUse
    case registrationFailed(OSStatus)

    public var message: String {
        switch self {
        case .alreadyInUse:
            "Another app already uses this shortcut. Choose a different combination."
        case let .registrationFailed(status):
            "macOS refused this shortcut (error \(status))."
        }
    }
}

/// Registers the system-wide shortcut that opens Moonlight.
///
/// Uses the Carbon hot key API, which a sandboxed app may call without
/// Accessibility access. This is Moonlight's own shortcut: it is not a
/// Spotlight Quick Key and must never be presented as one.
@MainActor
@Observable
public final class GlobalHotKeyCenter {
    public private(set) var hotKey: MoonlightHotKey?
    public private(set) var failure: GlobalHotKeyFailure?

    public var isActive: Bool { hotKeyReference != nil }

    @ObservationIgnored private var hotKeyReference: EventHotKeyRef?
    @ObservationIgnored private var eventHandler: EventHandlerRef?
    @ObservationIgnored private var action: @MainActor () -> Void = {}
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let storageKey: String
    /// Distinguishes this registration from any other the app makes. Carbon
    /// delivers every hot key carrying this signature to every handler
    /// installed on the target, so without it a second shortcut would also fire
    /// the first one's action.
    @ObservationIgnored fileprivate let hotKeyID: UInt32
    @ObservationIgnored private static let signature: OSType = 0x4D4F_4F4E // 'MOON'
    @ObservationIgnored private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "HotKey"
    )

    public init(
        preferences: UserDefaults = .standard,
        storageKey: String = "globalHotKey",
        hotKeyID: UInt32 = 1
    ) {
        self.preferences = preferences
        self.storageKey = storageKey
        self.hotKeyID = hotKeyID
        hotKey = Self.storedHotKey(in: preferences, key: storageKey)
    }

    /// Releases the Carbon registrations. The center lives for the process, so
    /// this exists for tests and for a host that tears its UI down explicitly.
    public func stop() {
        deactivate()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        action = {}
    }

    /// Installs the handler and activates the stored shortcut, if any.
    public func start(action: @escaping @MainActor () -> Void) {
        self.action = action
        installEventHandlerIfNeeded()
        if let hotKey {
            activate(hotKey)
        }
    }

    /// Stores and activates a new combination. A refusal leaves the previous
    /// shortcut inactive and visible as an error, never silently applied.
    public func update(to hotKey: MoonlightHotKey) {
        installEventHandlerIfNeeded()
        deactivate()
        self.hotKey = hotKey
        preferences.set(try? JSONEncoder().encode(hotKey), forKey: storageKey)
        activate(hotKey)
    }

    public func clear() {
        deactivate()
        hotKey = nil
        failure = nil
        preferences.removeObject(forKey: storageKey)
    }

    private func activate(_ hotKey: MoonlightHotKey) {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: Self.signature, id: hotKeyID)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            failure = status == OSStatus(eventHotKeyExistsErr)
                ? .alreadyInUse
                : .registrationFailed(status)
            Self.logger.error("Hot key registration failed with status \(status, privacy: .public)")
            return
        }

        hotKeyReference = reference
        failure = nil
    }

    private func deactivate() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
        }
        hotKeyReference = nil
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr, identifier.signature == GlobalHotKeyCenter.signature else {
                    return OSStatus(eventNotHandledErr)
                }

                // Carbon delivers hot keys on the main run loop, which is the
                // main actor; no hop is needed and none would be safe here.
                return MainActor.assumeIsolated {
                    let center = Unmanaged<GlobalHotKeyCenter>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    // Every handler on the target sees every Moonlight hot key,
                    // so each one answers only for its own registration.
                    guard identifier.id == center.hotKeyID else {
                        return OSStatus(eventNotHandledErr)
                    }
                    center.action()
                    return noErr
                }
            },
            1,
            &specification,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private static func storedHotKey(
        in preferences: UserDefaults,
        key: String
    ) -> MoonlightHotKey? {
        guard let data = preferences.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MoonlightHotKey.self, from: data)
    }
}
