import AppKit
import MoonlightDomain
import UniformTypeIdentifiers

/// Carries out a result action. The policy of what is offered lives in the
/// domain; this type only performs the AppKit side of it.
@MainActor
public struct ExecutionResultActionPerformer {
    public init() {}

    /// - Returns: a message to show when the action could not complete.
    @discardableResult
    public func perform(_ action: ExecutionResultAction) -> String? {
        switch action {
        case let .copy(text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return nil

        case let .save(text, suggestedFileName):
            return save(text: text, suggestedFileName: suggestedFileName)

        case let .open(url):
            guard NSWorkspace.shared.open(url) else {
                return "No application opened \(url.absoluteString)."
            }
            return nil
        }
    }

    private func save(text: String, suggestedFileName: String) -> String? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if suggestedFileName.hasSuffix(".json") {
            panel.allowedContentTypes = [.json]
        } else {
            panel.allowedContentTypes = [.plainText]
        }

        // Saving is a user decision; a cancelled panel is not a failure.
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
