import AppKit
import MoonlightAppUI
import SwiftUI

struct MoonlightMenuBarView: View {
    let coordinator: MoonlightPresentationCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var menuBarToken: MoonlightPresentationCoordinator.MenuBarToken?

    var body: some View {
        VStack(spacing: 0) {
            MoonlightToolPaletteView(
                model: coordinator.paletteModel,
                onDismiss: { dismiss() }
            )
            Divider()
            HStack {
                Button("Launcher", systemImage: "square.grid.3x3") {
                    dismiss()
                    coordinator.presentLauncher()
                }
                Button("Control Panel", systemImage: "sidebar.left") {
                    dismiss()
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                }
                Spacer()
                Button("Settings", systemImage: "gearshape") {
                    dismiss()
                    openSettings()
                    NSApplication.shared.activate()
                }
                .labelStyle(.iconOnly)
                .help("Settings")
                Button("Quit Moonlight", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
                .labelStyle(.iconOnly)
                .help("Quit Moonlight")
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .frame(width: 600, height: 570)
        .onAppear {
            coordinator.prepareMenuBarPalette()
            menuBarToken = coordinator.registerMenuBar(dismiss: { dismiss() })
        }
        .onDisappear {
            // A previous instance can disappear after a new one registered.
            // The token keeps it from clearing someone else's dismissal.
            if let menuBarToken {
                coordinator.unregisterMenuBar(menuBarToken)
            }
        }
    }
}
