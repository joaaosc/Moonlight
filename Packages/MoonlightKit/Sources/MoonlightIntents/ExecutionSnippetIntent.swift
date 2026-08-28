import AppIntents
import MoonlightInfrastructure
import MoonlightSnippetUI
import SwiftUI

public struct ExecutionSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Show Moonlight Result"
    public static var isDiscoverable: Bool { false }
    public static var supportedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Execution")
    public var execution: ExecutionEntity

    public init() {}

    public init(execution: ExecutionEntity) {
        self.execution = execution
    }

    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let client = try MoonlightRuntime.client()
        guard let storedExecution = try await client.execution(execution.id) else {
            throw ExecutionIntentError.executionNotFound(execution.id)
        }
        let view = await MainActor.run {
            ExecutionSnippetView(execution: storedExecution)
        }
        return .result(view: view)
    }
}
