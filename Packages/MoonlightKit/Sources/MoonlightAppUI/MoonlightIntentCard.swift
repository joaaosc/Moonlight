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
                    .background(item.accentColor.opacity(0.12), in: ConcentricRectangle())
                    .containerShape(shape)

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background.secondary, in: shape)
            .overlay {
                shape.strokeBorder(.separator, lineWidth: 1)
            }
            .containerShape(shape)
        }
        .buttonStyle(.plain)
        .help(item.subtitle)
        .onHover { isHovered = $0 }
        .brightness(isHovered ? 0.03 : 0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    /// A restrained radius: a 12pt corner reads as a card, a 22pt one reads as
    /// a pill. Nested shapes derive from it via `ConcentricRectangle`.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
}
