import AppKit

/// A floating panel with no visible chrome, so the SwiftUI surface inside owns
/// the whole shape.
///
/// `.titled` and `.fullSizeContentView` are kept rather than dropping to
/// `.borderless`: they are what keeps the panel able to become key and
/// resizable by its edges, and the titlebar is hidden instead of absent. The
/// title itself stays set, because the Window menu and VoiceOver still read it.
public final class MoonlightGlassPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // The traffic lights would sit on top of the glass with nothing to
        // anchor them; Escape and the palette's own controls close the panel.
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
            .forEach { standardWindowButton($0)?.isHidden = true }
    }

    /// A titled panel can already be key. Stated explicitly because the panel
    /// is the app's primary input surface and must never silently lose it.
    public override var canBecomeKey: Bool { true }
}
