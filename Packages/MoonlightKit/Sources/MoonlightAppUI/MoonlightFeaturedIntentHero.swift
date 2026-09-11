import SwiftUI

/// Hero featured card at the top of the Liquid Glass Control Panel matching "Featured Landmark - Mount Fuji".
public struct MoonlightFeaturedIntentHero: View {
    public let item: MoonlightIntentItem
    public let onRun: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    public init(
        item: MoonlightIntentItem,
        onRun: @escaping () -> Void
    ) {
        self.item = item
        self.onRun = onRun
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Scenic hero gradient background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                Color(red: 0.14, green: 0.16, blue: 0.38),
                                Color(red: 0.28, green: 0.20, blue: 0.48),
                                Color(red: 0.55, green: 0.22, blue: 0.42),
                                Color(red: 0.75, green: 0.38, blue: 0.35)
                            ]
                            : [
                                Color(red: 0.25, green: 0.45, blue: 0.85),
                                Color(red: 0.42, green: 0.48, blue: 0.88),
                                Color(red: 0.82, green: 0.45, blue: 0.65),
                                Color(red: 0.98, green: 0.65, blue: 0.45)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Radiant sunrise glow behind mountain
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.82, blue: 0.55).opacity(colorScheme == .dark ? 0.35 : 0.60),
                    Color(red: 1.0, green: 0.50, blue: 0.60).opacity(0.20),
                    .clear
                ],
                center: UnitPoint(x: 0.78, y: 0.38),
                startRadius: 0,
                endRadius: 280
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Mountain silhouette inside hero card
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let peakX = w * 0.76
                    let peakY = h * 0.25

                    path.move(to: CGPoint(x: w * 0.35, y: h))
                    path.addCurve(
                        to: CGPoint(x: peakX, y: peakY),
                        control1: CGPoint(x: w * 0.50, y: h * 0.85),
                        control2: CGPoint(x: peakX - w * 0.12, y: h * 0.45)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.90),
                        control1: CGPoint(x: peakX + w * 0.10, y: h * 0.45),
                        control2: CGPoint(x: w * 0.92, y: h * 0.80)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.40),
                            Color(red: 0.18, green: 0.12, blue: 0.30).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Dark gradient scrim overlay at the bottom for typography contrast
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.25),
                    .black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Foreground Content
            VStack(alignment: .leading, spacing: 12) {
                // Featured Intent Tag Badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("FEATURED INTENT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.4), lineWidth: 0.8)
                        }
                }

                // Title and Subtitle
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                    Text(item.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .frame(maxWidth: 480, alignment: .leading)
                }

                Spacer()

                // "Run Intent" Liquid Glass pill button (matching "Learn More" in reference)
                Button {
                    onRun()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 14, weight: .bold))
                        Text("Run \(item.title)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .fill(item.accentColor.opacity(0.35))
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(.white.opacity(0.55), lineWidth: 1.2)
                            }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(26)
        }
        .frame(height: 195)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.65), .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, y: 8)
    }
}
