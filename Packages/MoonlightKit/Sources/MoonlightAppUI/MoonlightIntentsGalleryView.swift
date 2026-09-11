import MoonlightDomain
import SwiftUI

/// The flagship Liquid Glass Intents Gallery matching macOS 27 landmarks reference layout.
public struct MoonlightIntentsGalleryView: View {
    @Bindable public var model: MoonlightModel
    public var notesModel: MoonlightNotesModel?

    @State private var searchText = ""
    @State private var selectedItemForRunner: MoonlightIntentItem?
    @State private var featuredItem: MoonlightIntentItem = MoonlightIntentCatalog.featuredItem

    @Environment(\.colorScheme) private var colorScheme

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
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Gallery Top Header with Search Pill (matching reference image)
            topHeader
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 26) {
                    if searchText.isEmpty {
                        // Hero Featured Intent Card (Matching "Featured Landmark - Mount Fuji")
                        MoonlightFeaturedIntentHero(item: featuredItem) {
                            selectedItemForRunner = featuredItem
                        }

                        // Categorized Intent Sections (Matching "Asia", "Africa")
                        ForEach(MoonlightIntentCategory.allCases) { category in
                            let categoryItems = MoonlightIntentCatalog.items(for: category)
                            if !categoryItems.isEmpty {
                                categorySection(title: category.rawValue, subtitle: category.subtitle, items: categoryItems)
                            }
                        }
                    } else {
                        // Search Results Grid
                        searchResultsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
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

    private var topHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Moonlight Intents")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                Text("Liquid Glass · macOS 27")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.80))
            }

            Spacer()

            // Search Glass Pill (Matching "Search" pill button in the top right of reference)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                TextField("Search intents...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 140)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.20), radius: 6, y: 2)
        }
    }

    private func categorySection(
        title: String,
        subtitle: String,
        items: [MoonlightIntentItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header (Matching "Asia", "Africa")
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            // Horizontal Scroll of Intent Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        MoonlightIntentCard(item: item) { clickedItem in
                            selectedItemForRunner = clickedItem
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search Results (\(filteredIntents.count))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if filteredIntents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No intents found matching '\(searchText)'")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 230), spacing: 16)], spacing: 16) {
                    ForEach(filteredIntents) { item in
                        MoonlightIntentCard(item: item) { clickedItem in
                            selectedItemForRunner = clickedItem
                        }
                    }
                }
            }
        }
    }
}
