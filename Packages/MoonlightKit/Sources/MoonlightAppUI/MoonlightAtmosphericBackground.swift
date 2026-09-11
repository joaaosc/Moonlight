import SwiftUI


public struct MoonlightAtmosphericBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sky gradient: Azure dawn to soft sakura rose
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [
                            Color(red: 0.06, green: 0.10, blue: 0.22),
                            Color(red: 0.12, green: 0.14, blue: 0.28),
                            Color(red: 0.25, green: 0.18, blue: 0.35),
                            Color(red: 0.40, green: 0.22, blue: 0.38)
                        ]
                        : [
                            Color(red: 0.28, green: 0.52, blue: 0.88),
                            Color(red: 0.45, green: 0.65, blue: 0.92),
                            Color(red: 0.82, green: 0.72, blue: 0.88),
                            Color(red: 0.98, green: 0.80, blue: 0.85)
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Radiant Sun / Moon Glow
                RadialGradient(
                    colors: [
                        colorScheme == .dark
                            ? Color(red: 0.95, green: 0.85, blue: 0.60).opacity(0.35)
                            : Color.white.opacity(0.70),
                        Color(red: 0.98, green: 0.75, blue: 0.85).opacity(0.20),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.65, y: 0.35),
                    startRadius: 0,
                    endRadius: 320
                )

                // Distant Mount Fuji Silhouette
                MountainSilhouette()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(red: 0.20, green: 0.18, blue: 0.35), Color(red: 0.12, green: 0.10, blue: 0.22)]
                                : [Color(red: 0.50, green: 0.55, blue: 0.75), Color(red: 0.35, green: 0.40, blue: 0.62)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geometry.size.height * 0.45)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 40)

                // Snowcap overlay on Mount Fuji
                MountainSnowCap()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.75 : 0.95),
                                Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.60)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geometry.size.height * 0.45)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 40)

                // Soft Sakura Cherry Blossom Clusters (Top and Bottom accents)
                SakuraAccents(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

/// Stylized geometric silhouette of Mount Fuji.
private struct MountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let peakX = width * 0.62
        let peakY = height * 0.15

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: height * 0.70))
        path.addCurve(
            to: CGPoint(x: peakX - width * 0.08, y: peakY + height * 0.05),
            control1: CGPoint(x: width * 0.25, y: height * 0.65),
            control2: CGPoint(x: peakX - width * 0.15, y: height * 0.30)
        )
        // Gentle crater peak
        path.addLine(to: CGPoint(x: peakX - width * 0.03, y: peakY))
        path.addLine(to: CGPoint(x: peakX + width * 0.03, y: peakY))
        path.addLine(to: CGPoint(x: peakX + width * 0.08, y: peakY + height * 0.05))
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.72),
            control1: CGPoint(x: peakX + width * 0.15, y: height * 0.30),
            control2: CGPoint(x: width * 0.85, y: height * 0.65)
        )
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

/// Symmetrical snowcap shape for the mountain summit.
private struct MountainSnowCap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let peakX = width * 0.62
        let peakY = height * 0.15

        path.move(to: CGPoint(x: peakX - width * 0.03, y: peakY))
        path.addLine(to: CGPoint(x: peakX + width * 0.03, y: peakY))
        path.addLine(to: CGPoint(x: peakX + width * 0.07, y: peakY + height * 0.08))
        // Jagged snow edge
        path.addLine(to: CGPoint(x: peakX + width * 0.04, y: peakY + height * 0.07))
        path.addLine(to: CGPoint(x: peakX + width * 0.02, y: peakY + height * 0.09))
        path.addLine(to: CGPoint(x: peakX, y: peakY + height * 0.075))
        path.addLine(to: CGPoint(x: peakX - width * 0.02, y: peakY + height * 0.09))
        path.addLine(to: CGPoint(x: peakX - width * 0.05, y: peakY + height * 0.07))
        path.addLine(to: CGPoint(x: peakX - width * 0.07, y: peakY + height * 0.08))
        path.closeSubpath()
        return path
    }
}

/// Soft sakura blossoms floating at the periphery (top-right and corners).
private struct SakuraAccents: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Top right blossom spray
            ZStack {
                ForEach(0..<8) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.78, blue: 0.86).opacity(0.85),
                                    Color(red: 0.95, green: 0.45, blue: 0.65).opacity(0.40),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 40 + CGFloat(index * 4), height: 40 + CGFloat(index * 4))
                        .offset(
                            x: CGFloat((index * 35) % 180) - 60,
                            y: CGFloat((index * 25) % 120) - 20
                        )
                }
            }
            .position(x: width * 0.88, y: height * 0.12)

            // Bottom left soft petals
            ZStack {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.75, blue: 0.85).opacity(0.75),
                                    Color(red: 0.90, green: 0.40, blue: 0.60).opacity(0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                        .frame(width: 32 + CGFloat(index * 5), height: 32 + CGFloat(index * 5))
                        .offset(
                            x: CGFloat(index * 28),
                            y: CGFloat(index * 18)
                        )
                }
            }
            .position(x: width * 0.10, y: height * 0.88)
        }
    }
}
