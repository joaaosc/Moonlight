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

    /// Writes a shell script to a `.command` file and opens it in Terminal.
    ///
    /// Opening through Launch Services keeps this working inside the App
    /// Sandbox: the sandboxed process asks for the open instead of spawning a
    /// shell, the same shape as `AppLauncher`.
    /// - Returns: a message to show when the script could not be opened.
    @discardableResult
    public func runTerminalScript(_ script: String) -> String? {
        do {
            let url = try writeCommandFile(script: script)
            guard NSWorkspace.shared.open(url) else {
                return "No application opened the terminal script."
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func writeCommandFile(script: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Moonlight", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "moonlight-\(UUID().uuidString).command")
        try "#!/bin/zsh\n\(script)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        return url
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
