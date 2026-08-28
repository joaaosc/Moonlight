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
        guard let identifier = UUID(uuidString: executionID) else {
            throw ExecutionIntentError.invalidExecutionIdentifier(executionID)
        }
        let client = try MoonlightRuntime.client()
        guard let storedExecution = try await client.execution(identifier) else {
            throw ExecutionIntentError.executionNotFound(identifier)
        }
        let view = await MainActor.run {
            ExecutionSnippetView(execution: storedExecution)
        }
        return .result(view: view)
    }
}
