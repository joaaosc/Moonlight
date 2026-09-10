import Foundation

/// What can be done with a result, decided from its typed value.
///
/// Availability is a property of the result, not of the tool: a command that
/// returned nothing offers nothing to copy, and only a value that really parses
/// as a web URL offers to open. Surfaces render this list; they do not invent
/// their own rules per tool.
public enum ExecutionResultAction: Equatable, Identifiable, Sendable {
    case copy(String)
    case save(text: String, suggestedFileName: String)
    case open(URL)

    public var id: String {
        switch self {
        case .copy: "copy"
        case .save: "save"
        case .open: "open"
        }
    }

    public var title: String {
        switch self {
        case .copy: "Copy Result"
        case .save: "Save Result…"
        case .open: "Open Link"
        }
    }

    public var symbolName: String {
        switch self {
        case .copy: "doc.on.doc"
        case .save: "square.and.arrow.down"
        case .open: "arrow.up.right.square"
        }
    }
}

public extension Execution {
    /// The actions this result supports, most direct first.
    var resultActions: [ExecutionResultAction] {
        guard status == .succeeded else { return [] }
        let output = resolvedOutput
        guard let text = output.value.text, !text.isEmpty else { return [] }

        var actions: [ExecutionResultAction] = [
            .copy(text),
            .save(text: text, suggestedFileName: Self.suggestedFileName(for: output)),
        ]
        if let url = Self.webURL(in: text) {
            actions.append(.open(url))
        }
        return actions
    }

    private static func suggestedFileName(for output: ActionOutput) -> String {
        switch output.value {
        case .json: "moonlight-result.json"
        case .identifier, .text, .none: "moonlight-result.txt"
        }
    }

    /// Only a single, complete http(s) URL counts. A body of text that merely
    /// contains a link is not an openable result.
    private static func webURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return nil }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host()?.isEmpty == false
        else {
            return nil
        }
        return url
    }
}
