import Foundation
import ScriptingBridge

/// The slice of the Shortcuts scripting dictionary Moonlight reads.
///
/// Declared by hand instead of generating a header: only these members are
/// used, and every one of them is read-only. The `run` command is deliberately
/// absent — listing must not be able to start a workflow.
@objc protocol ShortcutsEventsApplication: NSObjectProtocol {
    @objc optional func shortcuts() -> SBElementArray
}

@objc protocol ShortcutsEventsShortcut: NSObjectProtocol {
    @objc optional var name: String { get }
    @objc optional var subtitle: String { get }
    @objc optional var id: String { get }
    @objc optional var acceptsInput: Bool { get }
    @objc optional var actionCount: Int { get }
}

extension SBApplication: ShortcutsEventsApplication {}
extension SBObject: ShortcutsEventsShortcut {}

/// Captures the error Apple event instead of letting Scripting Bridge raise an
/// Objective-C exception, which Swift could not catch.
final class ShortcutsEventsBridgeDelegate: NSObject, SBApplicationDelegate {
    private(set) var lastError: NSError?

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: any Error) -> Any? {
        lastError = error as NSError
        return nil
    }
}
