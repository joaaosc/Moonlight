import AppKit

@MainActor
public final class MoonlightColorPanelPresenter {
    public static let shared = MoonlightColorPanelPresenter()
    public static let panelIdentifier = "moonlight-color-picker"

    private init() {}

    public func present() {
        let panel = NSColorPanel.shared
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Color Picker"
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.setFrameAutosaveName("MoonlightColorPanel")

        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }
}
