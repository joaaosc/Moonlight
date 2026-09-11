import SwiftUI

/// The abstract Liquid Glass backdrop behind the Control Panel: a dark base,
/// two or three softly blurred colour pools that drift, and a slow metallic
/// sheen sweeping across everything. No literal scenery — the panel's own
/// glass cards are what should read as content.
public struct MoonlightAtmosphericBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        ZStack {
            base
            GeometryReader { proxy in
                ZStack {
                    blob(
                        color: MoonlightGlassPalette.duskIndigo,
                        size: proxy.size.width * 0.62,
                        start: UnitPoint(x: 0.10, y: 0.08),
                        end: UnitPoint(x: 0.22, y: 0.20),
                        in: proxy.size,
                        duration: 16
                    )
                    blob(
                        color: MoonlightGlassPalette.emberRose,
                        size: proxy.size.width * 0.55,
                        start: UnitPoint(x: 0.92, y: 0.85),
                        end: UnitPoint(x: 0.78, y: 0.70),
                        in: proxy.size,
                        duration: 20
                    )
                    blob(
                        color: Color(red: 0.20, green: 0.62, blue: 0.98),
                        size: proxy.size.width * 0.40,
                        start: UnitPoint(x: 0.82, y: 0.15),
                        end: UnitPoint(x: 0.68, y: 0.30),
                        in: proxy.size,
                        duration: 24
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            metalSheen
        }
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
    }

    private var base: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.05, green: 0.05, blue: 0.10),
                    Color(red: 0.08, green: 0.07, blue: 0.14),
                    Color(red: 0.06, green: 0.06, blue: 0.12)
                ]
                : [
                    Color(red: 0.30, green: 0.42, blue: 0.72),
                    Color(red: 0.44, green: 0.44, blue: 0.74),
                    Color(red: 0.52, green: 0.40, blue: 0.66)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func blob(
        color: Color,
        size: CGFloat,
        start: UnitPoint,
        end: UnitPoint,
        in containerSize: CGSize,
        duration: Double
    ) -> some View {
        Circle()
            .fill(color.opacity(colorScheme == .dark ? 0.55 : 0.30))
            .frame(width: size, height: size)
            .blur(radius: size * 0.35)
            .position(
                x: (isAnimating ? end.x : start.x) * containerSize.width,
                y: (isAnimating ? end.y : start.y) * containerSize.height
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isAnimating
            )
    }

    /// A slow-rotating conic highlight standing in for brushed metal — a
    /// hint of specular movement rather than a literal light source.
    private var metalSheen: some View {
        AngularGradient(
            colors: [
                .clear,
                .white.opacity(colorScheme == .dark ? 0.10 : 0.16),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.05 : 0.08),
                .clear
            ],
            center: .center
        )
        .rotationEffect(.degrees(isAnimating ? 360 : 0))
        .animation(
            reduceMotion ? nil : .linear(duration: 48).repeatForever(autoreverses: false),
            value: isAnimating
        )
        .blendMode(.plusLighter)
        .opacity(colorScheme == .dark ? 0.5 : 0.3)
    }
}
