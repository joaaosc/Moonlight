import AppKit
import Carbon.HIToolbox

/// A key combination the user chose for opening Moonlight from anywhere.
///
/// Stored as the raw key code plus the modifiers, never as a character: the
/// same physical key produces different characters across layouts, and the
/// registration is made against the code.
public struct MoonlightHotKey: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    /// `NSEvent.ModifierFlags` raw value, filtered to the device-independent
    /// modifiers Moonlight accepts.
    public let modifierFlags: UInt

    public init(keyCode: UInt32, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    public init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.acceptedModifiers)
        // A bare key would swallow typing everywhere; at least one modifier is
        // required, and modifier-only presses are not a shortcut.
        guard !flags.isEmpty, !Self.isModifierKey(event.keyCode) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifierFlags: flags.rawValue)
    }

    public static let acceptedModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift,
    ]

    public var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
            .intersection(Self.acceptedModifiers)
    }

    /// The Carbon modifier mask used by the hot key registration.
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    public var displayString: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    private static func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
             kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
             kVK_CapsLock, kVK_Function:
            true
        default:
            false
        }
    }

    /// Named keys are spelled out; everything else is read from the current
    /// keyboard layout, so the label matches what the user actually pressed.
    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: break
        }

        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return "Key \(keyCode)"
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
