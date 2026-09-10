import AppKit
import SwiftUI

@MainActor
public final class MoonlightToolPalettePresenter {
    public static let shared = MoonlightToolPalettePresenter()
    public static let panelIdentifier = "moonlight-tool-palette"

    private var panel: MoonlightGlassPanel?
    private var model: MoonlightToolPaletteModel?

    private init() {}

    public func present(
        model: MoonlightToolPaletteModel,
        isolatingFromMainWindow: Bool = true
    ) {
        let replacingModel = self.model !== model
        self.model = model
        if let panel {
            if replacingModel {
                panel.contentView = Self.makeContentView(model: model)
            }
            if isolatingFromMainWindow {
                hideMainWindow(excluding: panel)
            }
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let panel = MoonlightGlassPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520)
        )
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Tools"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(width: 480, height: 420)
        panel.contentView = Self.makeContentView(model: model)
        panel.center()
        panel.setFrameAutosaveName("MoonlightToolPalette")
        self.panel = panel
        NSApplication.shared.activate()
        if isolatingFromMainWindow {
            hideMainWindow(excluding: panel)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    /// The hosting view must not paint: the glass surface inside is the only
    /// thing that draws a background, and an opaque host would square off the
    /// panel's rounded corners.
    private static func makeContentView(model: MoonlightToolPaletteModel) -> NSView {
        let hostingView = NSHostingView(
            rootView: MoonlightToolPaletteView(model: model, appearance: .glassPanel)
                .moonlightGlassSurface()
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        return hostingView
    }

    public func dismiss() {
        panel?.orderOut(nil)
    }

    func hideMainWindow(excluding panel: NSPanel) {
        mainWindows(in: NSApplication.shared.windows, excluding: panel)
            .forEach { $0.orderOut(nil) }
    }

    func mainWindows(in windows: [NSWindow], excluding panel: NSPanel) -> [NSWindow] {
        windows.filter { window in
            window !== panel
                && (window.identifier?.rawValue == "main" || window.title == "Moonlight")
        }
    }
}
