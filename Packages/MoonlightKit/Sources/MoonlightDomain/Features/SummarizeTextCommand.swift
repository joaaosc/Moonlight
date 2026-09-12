import Foundation

/// Shortens text to its opening sentences.
///
/// Extractive and local: the summary is made of sentences the input already
/// contains, in the order it contains them. Nothing is generated, so there is
/// nothing to be wrong about, and the result is the same on every machine and
/// every run — which is what makes it testable and what keeps the tool honest
/// about being a trimmer rather than a writer.
public struct SummarizeTextAction: ActionHandler {
    /// Where the summary stops. Long enough to carry a paragraph's point,
    /// short enough that the result is not the input again.
    public static let defaultLimit = 280

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.summarizeText,
        title: "Summarize Text",
        summary: "Shorten text to its opening sentences",
        isIdempotent: true
    )

    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "summarize",
            symbolName: "text.quote",
            inputKind: .text,
            destination: .result
        )
    }

    public init() {}

    public func perform(request: ActionRequest) async throws -> ActionOutput {
        try Task.checkCancellation()
        guard request.parameters.values.isEmpty else {
            throw ToolActionError.unexpectedParameters
        }

        let summary = Self.extractiveSummary(of: request.input)
        guard !summary.isEmpty else {
            throw ActionError.emptyInput
        }

        try Task.checkCancellation()
        return ActionOutput(
            summary: "Text summarized",
            detail: summary,
            value: .text(summary)
        )
    }

    /// The opening sentences that fit within `limit`.
    ///
    /// Sentences are cut on terminators rather than by a linguistic tagger:
    /// the tagger's answer varies by locale, and a summary that changes with
    /// the user's language settings cannot be asserted in a test.
    public static func extractiveSummary(
        of input: String,
        limit: Int = SummarizeTextAction.defaultLimit
    ) -> String {
        let normalized = input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let sentences = normalized
            .split(omittingEmptySubsequences: false) { ".!?\n".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result = ""
        for sentence in sentences {
            let candidate = result.isEmpty ? sentence : result + ". " + sentence
            if candidate.count > limit { break }
            result = candidate
        }

        // A single sentence longer than the limit still has to answer with
        // something: the opening of it, cut to length.
        if result.isEmpty {
            result = String(normalized.prefix(limit))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}
