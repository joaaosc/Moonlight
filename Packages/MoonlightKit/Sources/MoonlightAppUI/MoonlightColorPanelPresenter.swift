import AppKit

@MainActor
public final class MoonlightColorPanelPresenter {
    public static let shared = MoonlightColorPanelPresenter()
    public static let panelIdentifier = "moonlight-color-picker"

    private init() {}

    public func present(isolatingFromMainWindow: Bool = false) {
        let panel = NSColorPanel.shared
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Color Picker"
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.setFrameAutosaveName("MoonlightColorPanel")

        NSApplication.shared.activate()
        if isolatingFromMainWindow {
            hideMainWindow(excluding: panel)
        }
        panel.makeKeyAndOrderFront(nil)
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
