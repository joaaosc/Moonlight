import MoonlightDomain
import SwiftUI

/// An individual Intent card for the Liquid Glass Control Panel matching the macOS 27 gallery design.
public struct MoonlightIntentCard: View {
    public let item: MoonlightIntentItem
    public let onSelect: (MoonlightIntentItem) -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

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
            ZStack(alignment: .bottomLeading) {
                // Vibrant Gradient Card Background
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Ambient lighting sheen
                RadialGradient(
                    colors: [.white.opacity(isHovered ? 0.30 : 0.12), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 180
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Card Top Controls (SF Symbol disc & Glass badge)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        // Glass SF Symbol Badge
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.20))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.40), lineWidth: 1)
                                }

                            Image(systemName: item.symbolName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        }

                        Spacer()

                        // Mode badge — icon only. "Input" vs "Instant" is a
                        // state a symbol can carry without spelling it out.
                        Image(systemName: item.requiresInput ? "arrow.right.circle.fill" : "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 26, height: 26)
                            .background {
                                Circle()
                                    .fill(.black.opacity(0.22))
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
                                    }
                            }
                            .accessibilityLabel(item.requiresInput ? "Requires input" : "Runs instantly")
                    }
                    .padding(14)

                    Spacer()
                }

                // Dark Gradient Scrim for crisp text readability
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.30),
                        .black.opacity(0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18
                    )
                )

                // Title — the icon badge and mode symbol already carry the rest.
                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.30), radius: 2, y: 1)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .frame(width: 210, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                // Specular Glass Border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.70 : 0.35),
                                .white.opacity(isHovered ? 0.30 : 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            }
            .shadow(
                color: (item.gradientColors.first ?? .blue).opacity(isHovered ? 0.50 : 0.22),
                radius: isHovered ? 16 : 8,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isHovered ? 1.035 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(item.subtitle)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
