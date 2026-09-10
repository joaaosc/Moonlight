import Foundation

/// Converts between a Unix timestamp and an ISO-8601 date.
///
/// The direction is inferred from the input, because that is what the user
/// means in both cases: a number is an instant, an ISO date is a date.
public struct ConvertTimestampAction: ActionHandler {
    public let descriptor = ActionDescriptor(
        id: MoonlightActionID.convertTimestamp,
        title: "Convert Timestamp",
        summary: "Convert between a Unix timestamp and an ISO-8601 date",
        isIdempotent: true
    )

    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "date",
            symbolName: "clock.arrow.2.circlepath",
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

        let text = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ActionError.emptyInput
        }

        // Seconds since 1970 are locale independent; parsing them with a
        // formatter would depend on the user's decimal separator.
        if let seconds = Double(text) {
            let date = Date(timeIntervalSince1970: seconds)
            let formatted = date.formatted(.iso8601)
            return ActionOutput(
                summary: "Timestamp converted",
                detail: formatted,
                value: .text(formatted)
            )
        }

        guard let date = try? Date(text, strategy: .iso8601) else {
            throw ToolActionError.invalidTimestamp
        }
        let seconds = date.timeIntervalSince1970
        let formatted = seconds == seconds.rounded()
            ? String(Int(seconds))
            : String(seconds)

        try Task.checkCancellation()
        return ActionOutput(
            summary: "Date converted",
            detail: formatted,
            value: .identifier(formatted)
        )
    }
}
