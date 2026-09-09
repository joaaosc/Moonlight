import AppKit
import SwiftUI

@MainActor
public final class MoonlightToolPalettePresenter {
    public static let shared = MoonlightToolPalettePresenter()
    public static let panelIdentifier = "moonlight-tool-palette"

    private var panel: NSPanel?

    private init() {}

    public func present(
        preferredActionID: String? = nil,
        isolatingFromMainWindow: Bool = true,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        let model = MoonlightToolPaletteModel(
            preferredActionID: preferredActionID,
            onOpenColorPicker: onOpenColorPicker
        )
        present(model: model, isolatingFromMainWindow: isolatingFromMainWindow)
    }

    public func present(
        model: MoonlightToolPaletteModel,
        isolatingFromMainWindow: Bool = true
    ) {
        if let panel {
            panel.contentView = NSHostingView(rootView: MoonlightToolPaletteView(model: model))
            if isolatingFromMainWindow {
                hideMainWindow(excluding: panel)
            }
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Tools"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: MoonlightToolPaletteView(model: model))
        panel.center()
        self.panel = panel
        NSApplication.shared.activate(ignoringOtherApps: true)
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
