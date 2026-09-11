import SwiftUI

/// Hero featured card at the top of the Control Panel gallery: an abstract
/// gradient slab, one icon badge, a title, and an icon-only run button — no
/// paragraph of sales copy competing with the cards below it.
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

            abstractShapes

            // Dark gradient scrim overlay at the bottom for typography contrast
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.20),
                    .black.opacity(0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Foreground Content
            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    // Featured badge — sparkle only, the position at the top
                    // of the gallery already says what it means.
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.8)
                                }
                        }
                        .accessibilityLabel("Featured intent")

                    Text(item.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }

                Spacer()

                // Run button — the icon is the verb.
                Button {
                    onRun()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay { Circle().fill(item.accentColor.opacity(0.40)) }
                                .overlay { Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.2) }
                        }
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .scaleEffect(isHovered ? 1.06 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Run \(item.title)")
                .accessibilityLabel("Run \(item.title)")
                .onHover { isHovered = $0 }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            }
            .padding(24)
        }
        .frame(height: 150)
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

    /// Abstract blurred discs standing in for the scenic illustration —
    /// texture without a literal scene.
    private var abstractShapes: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.55).opacity(colorScheme == .dark ? 0.30 : 0.45))
                    .frame(width: proxy.size.height * 1.4)
                    .blur(radius: 40)
                    .position(x: proxy.size.width * 0.82, y: proxy.size.height * 0.30)

                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.18))
                    .frame(width: proxy.size.height * 0.9)
                    .blur(radius: 30)
                    .position(x: proxy.size.width * 0.62, y: proxy.size.height * 0.85)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
