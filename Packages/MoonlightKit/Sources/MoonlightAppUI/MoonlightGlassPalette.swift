import SwiftUI

/// The two lights Moonlight is lit by.
///
/// They no longer wash whole panels — a panel that pools indigo in one corner
/// and rose in the other reads as a different app from the window beside it.
/// Colour is spent where it carries meaning instead: the selected row, the
/// icon being chosen, a card's own accent. The background stays glass.
public enum MoonlightGlassPalette {
    public static let duskIndigo = Color(red: 0.36, green: 0.32, blue: 0.86)
    public static let emberRose = Color(red: 0.72, green: 0.30, blue: 0.48)

    /// The wash behind a floating panel: one faint tone, enough to warm the
    /// material and not enough to be read as a colour.
    static let tint = Color(red: 0.38, green: 0.36, blue: 0.74)

    /// The fill under whatever is currently selected. A gradient rather than a
    /// flat grey, so the selection belongs to Moonlight instead of to the
    /// system's default table highlight.
    public static func selection(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                duskIndigo.opacity(opacity),
                emberRose.opacity(opacity * 0.72),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The same two lights across an icon, for glyphs that stand for Moonlight
    /// itself rather than for one tool.
    public static var glyph: LinearGradient {
        LinearGradient(
            colors: [duskIndigo, emberRose],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
