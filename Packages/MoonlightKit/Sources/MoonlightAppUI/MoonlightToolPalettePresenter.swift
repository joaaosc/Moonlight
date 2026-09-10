import AppKit
import SwiftUI

@MainActor
public final class MoonlightToolPalettePresenter {
    public static let shared = MoonlightToolPalettePresenter()
    public static let panelIdentifier = "moonlight-tool-palette"

    private var panel: NSPanel?
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
                panel.contentView = NSHostingView(rootView: MoonlightToolPaletteView(model: model))
            }
            if isolatingFromMainWindow {
                hideMainWindow(excluding: panel)
            }
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Tools"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(width: 480, height: 420)
        panel.contentView = NSHostingView(rootView: MoonlightToolPaletteView(model: model))
        panel.center()
        panel.setFrameAutosaveName("MoonlightToolPalette")
        self.panel = panel
        NSApplication.shared.activate()
        if isolatingFromMainWindow {
            hideMainWindow(excluding: panel)
        }
        panel.makeKeyAndOrderFront(nil)
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
