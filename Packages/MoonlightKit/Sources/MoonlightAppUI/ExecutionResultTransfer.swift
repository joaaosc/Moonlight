import CoreTransferable
import MoonlightDomain
import UniformTypeIdentifiers

/// A result prepared for dragging or sharing.
///
/// Only results with a value can be transferred; a command that produced
/// nothing has nothing to hand to another app.
public struct ExecutionResultTransfer: Transferable, Sendable {
    public let text: String
    public let isJSON: Bool

    public init?(execution: Execution) {
        guard execution.status == .succeeded else { return nil }
        let output = execution.resolvedOutput
        guard let text = output.value.text, !text.isEmpty else { return nil }

        self.text = text
        if case .json = output.value {
            isJSON = true
        } else {
            isJSON = false
        }
    }

    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.text)
    }

    public var suggestedFileName: String {
        isJSON ? "moonlight-result.json" : "moonlight-result.txt"
    }
}
