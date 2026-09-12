import AppKit
import SwiftUI

/// A borderless panel sized to a whole screen.
///
/// Borderless, unlike ``MoonlightGlassPanel``: the palette is a window the user
/// moves and resizes, while the launcher covers a screen and is dismissed. A
/// borderless panel cannot become key on its own, so that is stated here — the
/// search field is the first thing the user types into.
public final class MoonlightLauncherPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        // Visible on every Space, like the launcher it replaces.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}

/// Puts the launcher on the screen the pointer is on.
@MainActor
public final class MoonlightLauncherPresenter {
    public static let shared = MoonlightLauncherPresenter()
    public static let panelIdentifier = "moonlight-launcher"

    private var panel: MoonlightLauncherPanel?
    private var model: MoonlightLauncherModel?

    private init() {}

    public var isPresented: Bool {
        panel?.isVisible == true
    }

    public func present(model: MoonlightLauncherModel) {
        self.model = model
        model.prepareForPresentation()

        let frame = Self.targetFrame()
        let panel = self.panel ?? makePanel(frame: frame)
        panel.setFrame(frame, display: false)
        panel.contentView = makeContentView(model: model)
        self.panel = panel

        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
        // Ordering front regardless is what reaches the screen when another app
        // holds activation; making it key afterwards is what puts the caret in
        // the search field.
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    public func dismiss() {
        panel?.orderOut(nil)
    }

    public func toggle(model: MoonlightLauncherModel) {
        if isPresented {
            dismiss()
        } else {
            present(model: model)
        }
    }

    private func makePanel(frame: NSRect) -> MoonlightLauncherPanel {
        let panel = MoonlightLauncherPanel(contentRect: frame)
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Launcher"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        return panel
    }

    /// The hosting view must not paint: the glass surface inside is the only
    /// thing that draws a background.
    private func makeContentView(model: MoonlightLauncherModel) -> NSView {
        let hostingView = NSHostingView(
            rootView: MoonlightLauncherView(model: model) { [weak self] in
                self?.dismiss()
            }
            // Denser than the palette: a full-screen surface at the palette's
            // transparency lets the desktop read straight through the icons.
            .moonlightGlassSurface(emphasis: .immersive)
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        return hostingView
    }

    /// How much of the screen the launcher takes, and the floor it keeps on a
    /// small display. A panel covering every pixel reads as a mode the user
    /// fell into; one inset from the edges reads as a panel over their work.
    private enum Metrics {
        static let screenFraction = CGSize(width: 0.74, height: 0.76)
        static let minimumSize = CGSize(width: 900, height: 620)
    }

    /// A centred panel on the screen under the pointer, falling back to the
    /// main one.
    ///
    /// `visibleFrame` rather than `frame`: covering the menu bar would need a
    /// window level that sits above the system's own UI, and a launcher is not
    /// worth taking the menu bar away from the user.
    private static func targetFrame() -> NSRect {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        // Never larger than the screen it sits on: the minimum is a floor for
        // big displays, not a size to force onto small ones.
        let width = min(
            visible.width,
            max(visible.width * Metrics.screenFraction.width, Metrics.minimumSize.width)
        )
        let height = min(
            visible.height,
            max(visible.height * Metrics.screenFraction.height, Metrics.minimumSize.height)
        )

        return NSRect(
            x: visible.midX - width / 2,
            y: visible.midY - height / 2,
            width: width,
            height: height
        ).integral
    }
}
