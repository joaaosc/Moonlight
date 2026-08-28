import AppIntents
import Foundation
import MoonlightDomain

public struct ExecutionEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Moonlight Execution"
    )
    public static let defaultQuery = ExecutionQuery()

    public let id: UUID

    @Property(title: "Action")
    public var actionTitle: String

    @Property(title: "Summary")
    public var summary: String

    @Property(title: "Detail")
    public var detail: String

    @Property(title: "Status")
    public var status: String

    @Property(title: "Created")
    public var createdAt: Date

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(summary)", subtitle: "\(detail)")
    }

    public init(
        id: UUID,
        actionTitle: String,
        summary: String,
        detail: String,
        status: String,
        createdAt: Date
    ) {
        self.id = id
        self.actionTitle = actionTitle
        self.summary = summary
        self.detail = detail
        self.status = status
        self.createdAt = createdAt
    }

    init(execution: Execution) {
        self.init(
            id: execution.id,
            actionTitle: execution.actionTitle,
            summary: execution.summary,
            detail: execution.detail,
            status: execution.status.rawValue,
            createdAt: execution.createdAt
        )
    }
}
