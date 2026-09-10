import Foundation

public struct CommandDefinition: Sendable, Equatable, Identifiable {
    public let descriptor: ActionDescriptor
    public let presentation: CommandPresentation

    public var id: String {
        descriptor.id
    }

    public init(
        descriptor: ActionDescriptor,
        presentation: CommandPresentation
    ) {
        self.descriptor = descriptor
        self.presentation = presentation
    }
}
