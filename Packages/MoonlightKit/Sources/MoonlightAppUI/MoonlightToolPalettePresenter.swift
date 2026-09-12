import AppKit
import SwiftUI

@MainActor
public final class MoonlightToolPalettePresenter {
    public static let shared = MoonlightToolPalettePresenter()
    public static let panelIdentifier = "moonlight-tool-palette"

    /// How hard the presentation insists on the keyboard.
    public enum Activation: Sendable {
        /// Ask for activation and order the panel front. Enough when the
        /// request already came from Moonlight or from a system surface that
        /// hands activation over.
        case standard
        /// Also order the panel front regardless of which app is active.
        /// `NSApplication.activate()` is a request, not a guarantee: another
        /// app can still hold activation, leaving the panel visible but not
        /// typed into.
        case forced
    }

    private var panel: MoonlightGlassPanel?
    private var model: MoonlightToolPaletteModel?

    private init() {}

    public func present(
        model: MoonlightToolPaletteModel,
        isolatingFromMainWindow: Bool = true,
        activation: Activation = .standard
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
            NSApplication.shared.activate()
            panel.makeKeyAndOrderFront(nil)
            focus(panel, activation: activation)
            return
        }

        let panel = MoonlightGlassPanel(
            contentRect: NSRect(
                origin: .zero,
                size: MoonlightGlassMetrics.paletteSize
            )
        )
        panel.identifier = NSUserInterfaceItemIdentifier(Self.panelIdentifier)
        panel.title = "Moonlight Tools"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(
            width: MoonlightGlassMetrics.paletteMinimumSize.width,
            height: MoonlightGlassMetrics.paletteMinimumSize.height
        )
        panel.contentView = Self.makeContentView(model: model)
        panel.center()
        panel.setFrameAutosaveName("MoonlightToolPalette")
        self.panel = panel
        NSApplication.shared.activate()
        if isolatingFromMainWindow {
            hideMainWindow(excluding: panel)
        }
        panel.makeKeyAndOrderFront(nil)
        focus(panel, activation: activation)
    }

    /// The extra step `.forced` adds. Ordering front regardless is what makes
    /// the panel reachable when Moonlight did not get activation; making it key
    /// afterwards is what puts the caret in the search field.
    private func focus(_ panel: MoonlightGlassPanel, activation: Activation) {
        guard activation == .forced else { return }
        panel.orderFrontRegardless()
        panel.makeKey()
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
