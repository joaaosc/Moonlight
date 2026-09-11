import AppIntents
import MoonlightDomain
import MoonlightIntents
import SwiftUI

struct NoteDetailView: View {
    let note: MoonlightNote
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(note.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                LabeledContent("Created") {
                    Text(note.createdAt, format: .dateTime)
                }
                LabeledContent("Updated") {
                    Text(note.updatedAt, format: .dateTime)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Tells the system which note is on screen, so "this note" refers to
        // what the user is actually looking at.
        .appEntityIdentifier(
            EntityIdentifier(for: MoonlightNoteEntity.self, identifier: note.id)
        )
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete Note", systemImage: "trash", role: .destructive, action: onDelete)
                    .help("Delete this note")
            }
        }
    }
}
