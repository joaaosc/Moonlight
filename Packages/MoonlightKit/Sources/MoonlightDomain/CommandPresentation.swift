import Foundation

public struct CommandPresentation: Sendable, Equatable {
    public enum InputKind: String, Sendable, Equatable, Codable, CaseIterable {
        case none
        case text
        /// Kept for records written before options existed. New commands use
        /// `.text` plus a declared option instead.
        case base64
    }

    public enum Destination: String, Sendable, Equatable, Codable, CaseIterable {
        case result
        case colorPicker
    }

    public let alias: String
    public let symbolName: String
    public let inputKind: InputKind
    public let destination: Destination
    /// Choices the command offers, declared by its own feature file.
    public let options: [CommandOption]

    public init(
        alias: String,
        symbolName: String,
        inputKind: InputKind,
        destination: Destination = .result,
        options: [CommandOption] = []
    ) {
        self.alias = alias
        self.symbolName = symbolName
        self.inputKind = inputKind
        self.destination = destination
        self.options = options
    }
}
