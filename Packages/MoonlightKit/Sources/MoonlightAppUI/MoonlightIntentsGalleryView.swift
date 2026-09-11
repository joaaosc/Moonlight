import MoonlightDomain
import SwiftUI

/// The intents gallery: one calm grid of cards on the content layer.
///
/// Deliberately plain. Apple's guidance is that Liquid Glass belongs to the
/// navigation layer — the sidebar and the toolbar own it here — and that colour
/// stays sparse so the cards read as a set rather than as twelve competing
/// badges. What's left is a grid with room to breathe.
public struct MoonlightIntentsGalleryView: View {
    @Bindable public var model: MoonlightModel
    public var notesModel: MoonlightNotesModel?

    @State private var searchText = ""
    @State private var selectedItemForRunner: MoonlightIntentItem?

    public init(
        model: MoonlightModel,
        notesModel: MoonlightNotesModel? = nil
    ) {
        self.model = model
        self.notesModel = notesModel
    }

    private var filteredIntents: [MoonlightIntentItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MoonlightIntentCatalog.allIntents }
        return MoonlightIntentCatalog.allIntents.filter {
            $0.title.localizedStandardContains(query) ||
            $0.subtitle.localizedStandardContains(query) ||
            $0.category.rawValue.localizedStandardContains(query)
        }
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(filteredIntents) { item in
                    MoonlightIntentCard(item: item) { selectedItemForRunner = $0 }
                }
            }
            // Generous margins are the point: the cards need empty space
            // around them, not another framed container.
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .scrollContentBackground(.hidden)
        .background(.background)
        .overlay {
            if filteredIntents.isEmpty {
                ContentUnavailableView.search
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search intents")
        .navigationTitle("Intents")
        .sheet(item: $selectedItemForRunner) { item in
            MoonlightIntentRunnerSheet(
                item: item,
                model: model,
                notesModel: notesModel
            ) {
                selectedItemForRunner = nil
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 20)]
    }
}
