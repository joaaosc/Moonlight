import SwiftUI

/// The fill under the row the user is on.
///
/// A gradient in Moonlight's own two lights rather than the system's flat
/// table highlight: the selected row is the one place in the palette where
/// colour carries meaning, so it is the one place that spends it. Faint enough
/// that the title on top keeps full contrast.
struct MoonlightSelectionBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MoonlightGlassMetrics.fieldShape
            .fill(MoonlightGlassPalette.selection(opacity: colorScheme == .dark ? 0.42 : 0.22))
            .overlay {
                MoonlightGlassMetrics.fieldShape
                    .strokeBorder(
                        MoonlightGlassPalette.duskIndigo.opacity(colorScheme == .dark ? 0.45 : 0.28),
                        lineWidth: 1
                    )
            }
    }
}
