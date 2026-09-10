import CoreServices
import Foundation
import MoonlightDomain
import ScriptingBridge

public extension ShortcutsEventsClient {
    /// Adapts this actor to the domain's run contract.
    ///
    /// Kept apart from `catalogClient()` so that a surface which only lists the
    /// library cannot reach execution by accident.
    nonisolated func runClient() -> ShortcutsRunClient {
        ShortcutsRunClient(run: { [self] externalID, input in
            try await run(externalID: externalID, input: input)
        })
    }

    /// Runs one shortcut through Shortcuts Events, without opening Shortcuts.
    ///
    /// A timeout is reported as such and never retried: the Apple Event giving
    /// up says nothing about whether the workflow stopped.
    func run(externalID: String, input: String?) throws -> ShortcutRunResult {
        try withBridge { application, delegate in
            guard let elements = application.shortcuts?() else {
                throw ShortcutsClientError.unavailable
            }
            guard
                let object = elements.object(withID: externalID) as? ShortcutsEventsRunnableShortcut
            else {
                throw ShortcutsClientError.shortcutNotFound(externalID: externalID)
            }
            if let error = delegate.lastError {
                throw Self.clientError(from: error, externalID: externalID)
            }

            let value = object.run?(withInput: input)
            if let error = delegate.lastError {
                throw Self.clientError(from: error, externalID: externalID)
            }

            return Self.result(from: value)
        }
    }

    /// Converts only the value types Moonlight can show. Anything else is
    /// reported as unsupported instead of being described as a string.
    internal static func result(from value: Any?) -> ShortcutRunResult {
        switch value {
        case nil, is NSNull:
            return .empty
        case let text as String:
            return text.isEmpty ? .empty : .text(text)
        case let number as NSNumber:
            return .text(number.stringValue)
        case let date as Date:
            return .text(date.formatted(.iso8601))
        case let url as URL:
            return .text(url.absoluteString)
        case let descriptor as NSAppleEventDescriptor:
            guard let text = descriptor.stringValue else {
                return .unsupportedOutput(typeDescription: "an Apple event descriptor")
            }
            return text.isEmpty ? .empty : .text(text)
        case let value?:
            return .unsupportedOutput(typeDescription: String(describing: type(of: value)))
        }
    }
}
