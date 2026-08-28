import AppIntents
import MoonlightDomain

public struct ActionEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Moonlight Action"
    )
    public static let defaultQuery = ActionQuery()

    public let id: String

    @Property(title: "Name")
    public var name: String

    @Property(title: "Summary")
    public var summary: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    public init(id: String, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }

    init(descriptor: ActionDescriptor) {
        self.init(
            id: descriptor.id,
            name: descriptor.title,
            summary: descriptor.summary
        )
    }
}
