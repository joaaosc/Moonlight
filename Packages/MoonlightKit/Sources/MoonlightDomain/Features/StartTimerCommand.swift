import Foundation

/// Parses a typed duration and records a timer start.
///
/// The action is intentionally a parser plus a record, not a daemon: it
/// validates `25m`, `90s` or `1:30` into seconds and writes the start to the
/// execution history. The countdown itself runs in the UI (`MinimalTimerView`),
/// which is the only surface that can tick without inventing background work
/// the app does not do.
public struct StartTimerAction: ActionHandler {
    /// Longest countdown the tool accepts: 24 hours.
    public static let maximumDurationInSeconds = 86_400

    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.startTimer,
        title: "Start Timer",
        summary: "Parse a duration and start a minimal countdown",
        isIdempotent: false
    )

    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "timer",
            symbolName: "timer",
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
        guard request.input.utf8.count <= MoonlightToolLimits.maximumInputByteCount else {
            throw ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            )
        }

        let seconds = try Self.parseDuration(request.input)
        let detail = "Timer set for \(Self.formatted(seconds: seconds))"
        try Task.checkCancellation()
        return ActionOutput(
            summary: "Timer started",
            detail: detail,
            value: .text(detail)
        )
    }

    /// Parses `25`, `25m`, `90s`, `1:30`, `1:05:00` or `1h2m30s`.
    ///
    /// A bare number means minutes, the way the Clock app's minute field is
    /// what people reach for first. Units are case insensitive and may be
    /// separated by spaces (`25 min`, `1h 30m`). Throws `emptyInput` for blank
    /// text and `invalidDuration` for anything else, including zero and values
    /// past 24 hours.
    public static func parseDuration(_ input: String) throws -> Int {
        let text = input
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !text.isEmpty else {
            throw ActionError.emptyInput
        }
        if let seconds = parseColonSeparated(text) {
            return try validate(seconds)
        }
        if let seconds = parseSuffixed(text) {
            return try validate(seconds)
        }
        throw ToolActionError.invalidDuration
    }

    /// Formats seconds the Clock way: `M:SS` below an hour, `H:MM:SS` above.
    public static func formatted(seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let rest = seconds % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", rest))"
        }
        return "\(minutes):\(String(format: "%02d", rest))"
    }

    // MARK: - Parsing

    private static func validate(_ seconds: Int) throws -> Int {
        guard seconds >= 1, seconds <= maximumDurationInSeconds else {
            throw ToolActionError.invalidDuration
        }
        return seconds
    }

    private static func parseColonSeparated(_ text: String) -> Int? {
        guard text.contains(":"), text.allSatisfy({ $0.isNumber || $0 == ":" }) else {
            return nil
        }
        let parts = text.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let last = Int(parts.last ?? ""), last < 60
        else {
            return -1
        }
        var total = last
        var factor = 60
        for part in parts.dropLast().reversed() {
            guard let value = Int(part) else { return -1 }
            total += value * factor
            factor *= 60
        }
        return total
    }

    private static func parseSuffixed(_ text: String) -> Int? {
        // Tokenizer: runs of digits followed by an optional unit word.
        // `25min`, `25 min`, `1h30m` and `1 hour 30 minutes` all tokenize the
        // same way; anything else (stray letters, punctuation) fails.
        var total = 0
        var foundUnit = false
        var index = text.startIndex

        func skipSpaces() {
            while index < text.endIndex, text[index] == " " || text[index] == "\t" {
                index = text.index(after: index)
            }
        }

        skipSpaces()
        while index < text.endIndex {
            guard text[index].isNumber else { return -1 }
            var digits = ""
            while index < text.endIndex, text[index].isNumber {
                digits.append(text[index])
                index = text.index(after: index)
            }
            guard let value = Int(digits) else { return -1 }
            skipSpaces()
            var word = ""
            while index < text.endIndex, text[index].isLetter {
                word.append(text[index])
                index = text.index(after: index)
            }
            if word.isEmpty {
                // Bare trailing number: minutes, the Clock app's first field.
                // A bare number mid-stream (`25 30s`) has no meaning.
                skipSpaces()
                guard index >= text.endIndex else { return -1 }
                total += value * 60
            } else if word.hasPrefix("h") {
                total += value * 3_600
                foundUnit = true
            } else if word.hasPrefix("m") {
                // `m` vs `ms`: only the exact word `ms` is rejected; `min`,
                // `mins`, `minute`, `minutes` all start with `m` and are fine.
                guard word != "ms" else { return -1 }
                total += value * 60
                foundUnit = true
            } else if word.hasPrefix("s") {
                total += value
                foundUnit = true
            } else {
                return -1
            }
            skipSpaces()
        }
        guard foundUnit || total > 0 else { return nil }
        return total
    }
}
