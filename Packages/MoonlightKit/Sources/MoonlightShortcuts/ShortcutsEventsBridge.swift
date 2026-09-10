import Foundation
import ScriptingBridge

/// The slice of the Shortcuts scripting dictionary Moonlight reads.
///
/// Declared by hand instead of generating a header: only these members are
/// used. Reading and running are separate protocols so the listing path has no
/// way to start a workflow.
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

/// The `run` command from the Shortcuts suite. Separated from the read-only
/// protocol so that reaching it is always a deliberate choice in the code.
@objc protocol ShortcutsEventsRunnableShortcut: NSObjectProtocol {
    @objc optional func run(withInput input: Any?) -> Any?
}

extension SBApplication: ShortcutsEventsApplication {}
extension SBObject: ShortcutsEventsShortcut {}
extension SBObject: ShortcutsEventsRunnableShortcut {}

/// Captures the error Apple event instead of letting Scripting Bridge raise an
/// Objective-C exception, which Swift could not catch.
final class ShortcutsEventsBridgeDelegate: NSObject, SBApplicationDelegate {
    private(set) var lastError: NSError?

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: any Error) -> Any? {
        lastError = error as NSError
        return nil
    }
}
