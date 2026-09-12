import SwiftUI

/// The chrome Moonlight's floating windows share: one rounded Liquid Glass
/// slab, a faint tint and a hairline edge.
///
/// This is the controls layer, not a content background: it wraps transient
/// panels that float over whatever the user was doing, which is the case
/// Liquid Glass is meant for. Regular content inside keeps its own materials.
public struct MoonlightGlassSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let emphasis: MoonlightGlassEmphasis
    private let content: Content

    public init(
        emphasis: MoonlightGlassEmphasis = .floating,
        @ViewBuilder content: () -> Content
    ) {
        self.emphasis = emphasis
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

    /// What sits between the desktop and the content: a neutral scrim to hold
    /// the content legible, then one flat tint to warm the material. Flat
    /// rather than a gradient — a directional wash is what made these panels
    /// read as a different app from the window next to them.
    private var wash: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else if emphasis.scrimOpacity > 0 {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(emphasis.scrimOpacity)
            }

            MoonlightGlassPalette.tint.opacity(tintOpacity)
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

    // Light mode gets a fainter tint: the same opacity that reads as depth over
    // a dark desktop reads as a stain over a bright one.
    private var tintOpacity: Double {
        colorScheme == .dark ? emphasis.tintOpacity.dark : emphasis.tintOpacity.light
    }
}

extension View {
    /// Wraps the view in Moonlight's floating glass chrome.
    public func moonlightGlassSurface(
        emphasis: MoonlightGlassEmphasis = .floating
    ) -> some View {
        MoonlightGlassSurface(emphasis: emphasis) { self }
    }
}
