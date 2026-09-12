import SwiftUI

/// The translucent field every Moonlight input sits on.
///
/// One treatment for all of them, on glass or on the menu bar's own material:
/// a search field, a multi-line editor and a result slab read as the same
/// surface rather than as three unrelated controls. Notably it is *not*
/// `.textBackgroundColor`: that is an opaque system colour, and filling half a
/// panel with it cancels the glass behind it.
struct GlassFieldBackground<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(.primary.opacity(0.05))
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

extension View {
    /// Applies Moonlight's field treatment.
    func moonlightFieldBackground(_ shape: some InsettableShape) -> some View {
        background { GlassFieldBackground(shape: shape) }
    }
}
