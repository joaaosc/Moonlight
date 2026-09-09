import AppKit
import MoonlightAppUI
import SwiftUI

struct MoonlightMenuBarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            MoonlightToolPaletteView(
                model: MoonlightPresentationRoute.paletteModel,
                onDismiss: { dismiss() }
            )
            Divider()
            HStack {
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
            MoonlightToolPalettePresenter.shared.dismiss()
            MoonlightPresentationRoute.paletteModel.preparePresentation()
            MoonlightPresentationRoute.dismissMenuBar = { dismiss() }
        }
        .onDisappear {
            MoonlightPresentationRoute.dismissMenuBar = nil
        }
    }
}
