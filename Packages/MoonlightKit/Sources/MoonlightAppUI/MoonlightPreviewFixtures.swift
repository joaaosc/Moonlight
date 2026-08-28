#if DEBUG
import Foundation
import MoonlightDomain
import MoonlightInfrastructure

@MainActor
enum MoonlightPreviewFixtures {
    static let executions = [
        Execution(
            id: UUID(uuidString: "A66215E9-9440-45ED-82C8-62B3A81C5EA5") ?? UUID(),
            actionID: MoonlightActionID.captureNote,
            actionTitle: "Capture Note",
            input: "Review the Spotlight interaction after the next build.",
            summary: "Note captured",
            detail: "Review the Spotlight interaction after the next build.",
            status: .succeeded,
            createdAt: Date(timeIntervalSinceReferenceDate: 808_200_000)
        ),
        Execution(
            id: UUID(uuidString: "DB47C735-C533-43D4-9548-CFA63BC77F72") ?? UUID(),
            actionID: MoonlightActionID.captureNote,
            actionTitle: "Capture Note",
            input: "A longer note\nwith multiple lines to verify compact history rows.",
            summary: "Note captured",
            detail: "A longer note\nwith multiple lines to verify compact history rows.",
            status: .succeeded,
            createdAt: Date(timeIntervalSinceReferenceDate: 808_196_400)
        ),
    ]

    static func model(executions: [Execution] = executions) -> MoonlightModel {
        MoonlightModel(client: client(executions: executions))
    }

    static var errorModel: MoonlightModel {
        let error = MoonlightRuntimeError.initializationFailed("Preview history unavailable.")
        return MoonlightModel(
            client: MoonlightRuntimeClient(
                descriptors: { ActionRegistry.standard.descriptors },
                execute: { _ in throw error },
                execution: { _ in throw error },
                recent: { _ in throw error }
            )
        )
    }

    private static func client(executions: [Execution]) -> MoonlightRuntimeClient {
        MoonlightRuntimeClient(
            descriptors: { ActionRegistry.standard.descriptors },
            execute: { request in
                Execution(
                    id: UUID(),
                    actionID: request.actionID,
                    actionTitle: "Capture Note",
                    input: request.input,
                    summary: "Note captured",
                    detail: request.input,
                    status: .succeeded,
                    createdAt: .now
                )
            },
            execution: { identifier in
                executions.first { $0.id == identifier }
            },
            recent: { limit in
                Array(executions.prefix(max(0, limit)))
            }
        )
    }
}
#endif
