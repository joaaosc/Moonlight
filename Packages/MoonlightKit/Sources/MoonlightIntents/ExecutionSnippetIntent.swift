import AppIntents
import MoonlightInfrastructure
import MoonlightSnippetUI
import SwiftUI

public struct ExecutionSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Show Moonlight Result"
    public static var isDiscoverable: Bool { false }
    public static var allowedExecutionTargets: IntentExecutionTargets { [.appIntentsExtension] }

    @Parameter(title: "Execution Identifier")
    public var executionID: String

    public init() {}

    public init(executionID: UUID) {
        self.executionID = executionID.uuidString
    }

    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        // The renderer only reads a stored result by ID. It never re-runs a
        // command: re-executing here would duplicate history and side effects.
        let storedExecution = try await MoonlightIntentExecutor.storedExecution(
            rawIdentifier: executionID
        )
        let view = await MainActor.run {
            ExecutionSnippetView(execution: storedExecution)
        }
        return .result(view: view)
    }
}
