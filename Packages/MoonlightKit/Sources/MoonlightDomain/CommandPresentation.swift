import Foundation

public struct CommandPresentation: Sendable, Equatable {
    public enum InputKind: String, Sendable, Equatable, Codable, CaseIterable {
        case none
        case text
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

    public init(
        alias: String,
        symbolName: String,
        inputKind: InputKind,
        destination: Destination = .result
    ) {
        self.alias = alias
        self.symbolName = symbolName
        self.inputKind = inputKind
        self.destination = destination
    }
}
