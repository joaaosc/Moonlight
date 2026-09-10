import AppIntents
import CoreTransferable
import Foundation
import MoonlightDomain
import UniformTypeIdentifiers

/// Reads a stored result and hands it to the pasteboard.
///
/// Works from an execution identifier, so using it never runs the original
/// command again and never adds a second record to the history.
public struct CopyExecutionResultIntent: AppIntent {
    public static let title: LocalizedStringResource = "Copy Moonlight Result"
    public static let description = IntentDescription(
        "Copies the result of a Moonlight execution to the clipboard."
    )
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]
    /// The pasteboard is only reachable from the app process.
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Parameter(title: "Execution Identifier")
    public var executionID: String

    @Dependency private var foregroundClient: MoonlightForegroundClient

    public init() {}

    public init(executionID: UUID) {
        self.executionID = executionID.uuidString
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let execution = try await MoonlightIntentExecutor.storedExecution(
            rawIdentifier: executionID
        )
        guard let text = execution.resolvedOutput.value.text, !text.isEmpty else {
            throw ExecutionIntentError.resultHasNoValue(execution.actionTitle)
        }

        await foregroundClient.copyToPasteboard(text)
        return .result(value: text)
    }
}

/// Hands a stored result to Shortcuts as a file, letting the shortcut decide
/// where it goes. Moonlight does not choose a destination on the user's behalf.
public struct SaveExecutionResultIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Moonlight Result as File"
    public static let description = IntentDescription(
        "Returns the result of a Moonlight execution as a file."
    )
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(title: "Execution Identifier")
    public var executionID: String

    public init() {}

    public init(executionID: UUID) {
        self.executionID = executionID.uuidString
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let execution = try await MoonlightIntentExecutor.storedExecution(
            rawIdentifier: executionID
        )
        let output = execution.resolvedOutput
        guard let text = output.value.text, !text.isEmpty else {
            throw ExecutionIntentError.resultHasNoValue(execution.actionTitle)
        }

        let isJSON: Bool
        if case .json = output.value {
            isJSON = true
        } else {
            isJSON = false
        }

        let file = IntentFile(
            data: Data(text.utf8),
            filename: isJSON ? "moonlight-result.json" : "moonlight-result.txt",
            type: isJSON ? .json : .plainText
        )
        return .result(value: file)
    }
}
