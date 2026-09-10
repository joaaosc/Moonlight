import MoonlightDomain
import SwiftUI

struct NotesListView: View {
    let notes: [MoonlightNote]
    let isLoading: Bool
    @Binding var selection: MoonlightNote.ID?

    var body: some View {
        List(notes, selection: $selection) { note in
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled note" : note.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(note.updatedAt, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .tag(note.id)
        }
        .overlay {
            if notes.isEmpty, !isLoading {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Capture a note to keep it here. Clearing history does not remove notes.")
                )
            }
        }
        .navigationTitle("Notes")
        .accessibilityIdentifier("notes-list")
    }
}

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
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete Note", systemImage: "trash", role: .destructive, action: onDelete)
                    .help("Delete this note")
            }
        }
    }
}
