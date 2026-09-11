import SwiftUI

/// A keyboard hint drawn as its key, not spelled out.
///
/// The footer used to be a sentence — "↑↓ Select · Tab Complete" — which is
/// three ideas competing with the list above it for the same attention. A key
/// cap says the same thing at a glance and costs a fraction of the width.
struct KeyHint: View {
    let symbol: String
    let action: String

    var body: some View {
        Image(systemName: symbol)
            .font(.caption)
            .frame(width: 18, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
            )
            .foregroundStyle(.secondary)
            .accessibilityLabel(action)
    }
}

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
