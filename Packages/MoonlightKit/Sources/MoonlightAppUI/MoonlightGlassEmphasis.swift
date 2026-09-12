import Foundation

/// How much a glass surface asks of the desktop behind it.
///
/// A palette is a small window over a working screen and stays light. The
/// launcher covers the whole screen: at the palette's transparency the desktop
/// reads straight through a wall of icons, so it takes a denser tint and a
/// scrim. Same material, same colour — one parameter, not two designs.
public enum MoonlightGlassEmphasis: Sendable {
    case floating
    case immersive

    var tintOpacity: (dark: Double, light: Double) {
        switch self {
        case .floating: (0.10, 0.06)
        case .immersive: (0.24, 0.16)
        }
    }

    var scrimOpacity: Double {
        switch self {
        case .floating: 0
        case .immersive: 0.18
        }
    }
}
