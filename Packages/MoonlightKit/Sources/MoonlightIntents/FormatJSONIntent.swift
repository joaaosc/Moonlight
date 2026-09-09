import AppIntents
import MoonlightDomain
import MoonlightSnippetUI
import SwiftUI

public struct FormatJSONIntent: AppIntent {
    public static let title: LocalizedStringResource = "Format JSON"
    public static let description = IntentDescription(
        "Validates and formats a JSON object or array."
    )
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]
    public static let allowedExecutionTargets: IntentExecutionTargets = [
        .main,
        .appIntentsExtension,
    ]

    @Parameter(
        title: "JSON",
        requestValueDialog: "What JSON should Moonlight format?"
    )
    public var json: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Format \(\.$json) as JSON")
    }

    public init() {}

    public init(json: String) {
        self.json = json
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let execution = try await MoonlightIntentExecutor.execute(
            actionID: MoonlightActionID.formatJSON,
            input: json
        )

        let view = await MainActor.run {
            ExecutionSnippetView(execution: execution)
        }

        return .result(
            dialog: IntentDialog(
                full: "\(execution.detail)",
                systemImageName: "curlybraces"
            ),
            view: view
        )
    }
}
