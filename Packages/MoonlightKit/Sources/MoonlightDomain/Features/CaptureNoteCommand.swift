import Foundation

extension CaptureNoteAction {
    public var presentation: CommandPresentation {
        CommandPresentation(
            alias: "note",
            symbolName: "note.text.badge.plus",
            inputKind: .text,
            destination: .result
        )
    }
}
