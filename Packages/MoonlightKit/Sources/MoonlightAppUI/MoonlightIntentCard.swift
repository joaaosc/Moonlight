import MoonlightDomain
import SwiftUI

/// One intent in the gallery grid.
///
/// A neutral card on the content layer. Apple's colour guidance is to keep
/// colour sparse and reserve it for what needs emphasis, so the accent lives
/// on the icon alone rather than flooding the whole card — twelve saturated
/// gradients side by side is the pattern the guidance calls out as incorrect.
public struct MoonlightIntentCard: View {
    public let item: MoonlightIntentItem
    public let onSelect: (MoonlightIntentItem) -> Void

    @State private var isHovered = false

    public init(
        item: MoonlightIntentItem,
        onSelect: @escaping (MoonlightIntentItem) -> Void
    ) {
        self.item = item
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            onSelect(item)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: item.symbolName)
                    .font(.title3)
                    .foregroundStyle(item.accentColor)
                    .frame(width: 36, height: 36)
                    // A wash rather than a flat tile: the accent is the one
                    // thing telling twelve otherwise identical cards apart, so
                    // it gets depth instead of a single opacity step.
                    .background(iconWash, in: ConcentricRectangle())
                    .containerShape(shape)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // The summary was reachable only by hovering for a tooltip.
                    // On a card with room for it, that is a line of the answer
                    // hidden behind a gesture.
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background.secondary, in: shape)
            // The accent reaches the card itself, faintly, so the grid reads as
            // a set of distinct tools rather than as one grey wall.
            .background(item.accentColor.opacity(isHovered ? 0.10 : 0.05), in: shape)
            .overlay {
                shape.strokeBorder(
                    item.accentColor.opacity(isHovered ? 0.45 : 0.18),
                    lineWidth: 1
                )
            }
            .containerShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    /// The accent, lit from the corner the icon sits in.
    private var iconWash: LinearGradient {
        LinearGradient(
            colors: [
                item.accentColor.opacity(0.28),
                item.accentColor.opacity(0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A restrained radius: a 12pt corner reads as a card, a 22pt one reads as
    /// a pill. Nested shapes derive from it via `ConcentricRectangle`.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
}
