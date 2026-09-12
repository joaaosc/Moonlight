import SwiftUI

/// Shared geometry and type for Moonlight's surfaces.
///
/// One place, so the panel corner, the content clip, the border and every
/// field inside them never drift apart by a point — and so the menu bar
/// popover, the floating palette and the launcher read as the same app rather
/// than as three that happen to ship together.
public enum MoonlightGlassMetrics {
    /// The corner of a floating panel.
    public static let cornerRadius: CGFloat = 18
    /// The inset every Moonlight surface keeps from its own edge.
    public static let contentPadding: CGFloat = 18
    /// The corner of a container drawn *inside* a panel — an input, a result
    /// slab, a selected row. Smaller than the panel's, so nested shapes read
    /// as nested.
    public static let fieldCornerRadius: CGFloat = 12
    /// The gap between a surface's stacked sections.
    public static let contentSpacing: CGFloat = 12
    /// The height of the strip at the top of a panel that drags its window.
    public static let dragHandleHeight: CGFloat = 28
    /// The one ramp every search field in Moonlight is set in.
    public static let searchFont: Font = .title3
    /// The size a floating palette opens at, and the floor it may shrink to.
    public static let paletteSize = CGSize(width: 640, height: 560)
    public static let paletteMinimumSize = CGSize(width: 480, height: 420)
    /// The menu bar popover: the palette's width, so the two surfaces line up,
    /// but shorter — it lists what is true right now, not a whole catalogue.
    ///
    /// A ceiling rather than a height. What the popover lists is short and
    /// varies — one app's shortcuts and a handful of favourites — so a fixed
    /// height left the panel mostly empty; it grows with its content up to
    /// here and scrolls past it.
    public static let menuBarHeight: CGFloat = 420
    /// The floor, so a nearly empty popover is still a panel and not a sliver.
    public static let menuBarMinimumHeight: CGFloat = 120

    public static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    public static var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fieldCornerRadius)
    }
}
