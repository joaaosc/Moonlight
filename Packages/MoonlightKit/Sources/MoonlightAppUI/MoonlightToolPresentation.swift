import MoonlightDomain

/// UI metadata for one tool. Domain actions stay platform agnostic; this is
/// the single adapter used by the palette, menu bar and future Spotlight UI.
public struct MoonlightToolPresentation: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let alias: String
    public let symbolName: String
    public let acceptsInput: Bool
    public let inputKind: CommandPresentation.InputKind
    public let destination: CommandPresentation.Destination

    public init(definition: CommandDefinition) {
        self.id = definition.descriptor.id
        self.title = definition.descriptor.title
        self.summary = definition.descriptor.summary
        self.alias = definition.presentation.alias
        self.symbolName = definition.presentation.symbolName
        self.inputKind = definition.presentation.inputKind
        self.destination = definition.presentation.destination
        self.acceptsInput = definition.presentation.inputKind != .none
    }

    public init(descriptor: ActionDescriptor) {
        let presentation = ActionRegistry.standard.definition(id: descriptor.id)?.presentation ?? CommandPresentation(
            alias: descriptor.id,
            symbolName: "command",
            inputKind: .text,
            destination: .result
        )
        self.init(definition: CommandDefinition(descriptor: descriptor, presentation: presentation))
    }
}
