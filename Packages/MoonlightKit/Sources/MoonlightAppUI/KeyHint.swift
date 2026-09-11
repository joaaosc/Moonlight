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
