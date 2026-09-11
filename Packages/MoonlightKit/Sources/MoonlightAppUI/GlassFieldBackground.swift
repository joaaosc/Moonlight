import SwiftUI

/// The translucent field the launcher uses for text.
///
/// Every input inside the panel shares it, so a text field and a multi-line
/// editor read as the same material rather than as two unrelated controls.
/// Notably it is *not* `.textBackgroundColor`: that is an opaque system colour,
/// and filling half the panel with it cancels the glass behind it.
struct GlassFieldBackground<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(.primary.opacity(0.05))
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

extension View {
    /// Applies the launcher's field treatment, or the plain system one when the
    /// palette is embedded in the menu bar popover and has no glass to match.
    @ViewBuilder
    func moonlightFieldBackground<S: InsettableShape>(
        _ shape: S,
        isGlass: Bool
    ) -> some View {
        if isGlass {
            background { GlassFieldBackground(shape: shape) }
        } else {
            background { shape.fill(.quinary) }
        }
    }
}
