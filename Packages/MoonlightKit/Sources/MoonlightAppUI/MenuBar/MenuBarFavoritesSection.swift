import MoonlightDomain
import SwiftUI

/// The tools the user marked, under the active app's own shortcuts.
///
/// The quieter half: a caption header and plain rows. These are always the
/// same, so they should not compete with the section that changes with
/// whatever app is in front.
public struct MenuBarFavoritesSection: View {
    private let favorites: [MenuBarFavorite]
    private let onSelect: (MenuBarFavorite) -> Void

    public init(
        favorites: [MenuBarFavorite],
        onSelect: @escaping (MenuBarFavorite) -> Void
    ) {
        self.favorites = favorites
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Favorites")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if favorites.isEmpty {
                Text("Star a tool in the palette to keep it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(favorites) { favorite in
                    Button {
                        onSelect(favorite)
                    } label: {
                        HStack(spacing: 10) {
                            Text(favorite.title)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(String(SlashCommand.prefix) + favorite.alias)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help(favorite.summary)
                }
            }
        }
    }
}
