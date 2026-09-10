import SwiftUI

/// Shared geometry for Moonlight's floating surfaces. One value, so the panel
/// corner, the content clip and the border never drift apart by a point.
public enum MoonlightGlassMetrics {
    public static let cornerRadius: CGFloat = 18
    public static let contentPadding: CGFloat = 18

    public static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

/// The two lights Moonlight's glass surfaces are lit by. Named rather than
/// inlined so every surface warms to the same colour.
enum MoonlightGlassPalette {
    static let duskIndigo = Color(red: 0.33, green: 0.28, blue: 0.86)
    static let emberRose = Color(red: 0.66, green: 0.24, blue: 0.40)
}

/// The chrome Moonlight's floating windows share: one rounded Liquid Glass
/// slab, a soft colour wash and a hairline edge.
///
/// This is the controls layer, not a content background: it wraps a transient
/// launcher panel that floats over whatever the user was doing, which is the
/// case Liquid Glass is meant for. Regular content inside keeps its normal
/// materials.
public struct MoonlightGlassSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            // The glass is a background layer, not a wrapper. Applying
            // `.glassEffect` to the content itself hands the content the
            // material's own appearance, which resolves `.primary` to dark ink
            // and leaves the palette unreadable in dark mode.
            .background {
                MoonlightGlassMetrics.shape
                    .fill(.clear)
                    .glassEffect(.regular, in: MoonlightGlassMetrics.shape)
                    .overlay { wash.clipShape(MoonlightGlassMetrics.shape) }
            }
            .clipShape(MoonlightGlassMetrics.shape)
            .overlay {
                MoonlightGlassMetrics.shape
                    .strokeBorder(edge, lineWidth: 1)
            }
    }

    /// The colour behind the glass. Two diffuse pools rather than a linear
    /// ramp, so the panel reads as lit from its corners instead of as a
    /// gradient rectangle.
    ///
    /// With Reduce Transparency on, the wash becomes the panel's actual
    /// background: the system flattens the glass, and a nearly clear layer
    /// would leave the content sitting on bare desktop.
    private var wash: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            }

            RadialGradient(
                colors: [MoonlightGlassPalette.duskIndigo.opacity(indigoOpacity), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 620
            )

            RadialGradient(
                colors: [MoonlightGlassPalette.emberRose.opacity(roseOpacity), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 620
            )
        }
    }

    private var edge: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.30 : 0.60),
                .white.opacity(colorScheme == .dark ? 0.06 : 0.18),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Light mode gets a fainter wash: the same opacity that reads as depth over
    // a dark desktop reads as a stain over a bright one.
    private var indigoOpacity: Double {
        colorScheme == .dark ? 0.50 : 0.22
    }

    private var roseOpacity: Double {
        colorScheme == .dark ? 0.38 : 0.16
    }

}

extension View {
    /// Wraps the view in Moonlight's floating glass chrome.
    public func moonlightGlassSurface() -> some View {
        MoonlightGlassSurface { self }
    }
}
