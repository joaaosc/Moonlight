import SwiftUI

/// Makes a region drag its own window.
///
/// A panel with `isMovableByWindowBackground` only moves when the click lands
/// somewhere nothing else consumes it, and a palette is a list that fills the
/// window: on a large screen there was nowhere left to grab. This states the
/// grab area instead of hoping one survives, and `allowsWindowActivationEvents`
/// is what lets the drag start while another app still holds activation —
/// which is the state the palette is normally opened in.
struct MoonlightWindowDragArea: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            // Without a hit-testable shape the gesture only sees the glyphs,
            // not the empty run of header between them.
            .contentShape(.rect)
            .gesture(WindowDragGesture(), isEnabled: isEnabled)
            .allowsWindowActivationEvents(isEnabled)
    }
}

extension View {
    /// Lets this region drag the window it is in.
    func moonlightWindowDrag(isEnabled: Bool = true) -> some View {
        modifier(MoonlightWindowDragArea(isEnabled: isEnabled))
    }
}
