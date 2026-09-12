import SwiftUI

/// A keyboard hint: the key cap, and what it does.
///
/// The cap alone was legible to no one — a row of unlabelled glyphs in a corner
/// is decoration, not a hint, and VoiceOver was the only place the meaning
/// existed. `label` is the short word shown beside the key; `description` is
/// the full sentence VoiceOver reads.
struct KeyHint: View {
    let symbol: String
    let label: String
    let description: String
    var isCompact = false

    init(symbol: String, label: String, description: String? = nil, isCompact: Bool = false) {
        self.symbol = symbol
        self.label = label
        self.description = description ?? label
        self.isCompact = isCompact
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .frame(width: 18, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
                )

            if !isCompact {
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
    }
}
