import AppKit
import MoonlightAppUI
import MoonlightDomain
import SwiftUI

/// The menu bar popover.
///
/// Deliberately not the tool palette. The palette is the floating surface, and
/// repeating it here made the two the same screen shown twice. What belongs in
/// a menu bar is what is true right now: the app in front and its shortcuts,
/// then the handful of tools the user marked, then the way into everything
/// else.
struct MoonlightMenuBarView: View {
    let coordinator: MoonlightPresentationCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var model = MoonlightMenuBarModel()
    @State private var menuBarToken: MoonlightPresentationCoordinator.MenuBarToken?

    private var favorites: [MenuBarFavorite] {
        model.favorites(in: coordinator.paletteModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: MoonlightGlassMetrics.contentSpacing) {
                    MenuBarActiveAppSection(model: model)
                    MenuBarFavoritesSection(favorites: favorites) { favorite in
                        dismiss()
                        coordinator.presentPalette(
                            preferredActionID: favorite.id,
                            isolatingFromMainWindow: true
                        )
                    }
                }
                .padding(MoonlightGlassMetrics.contentPadding)
            }
            .scrollIndicators(.hidden)

            Divider()
            footer
        }
        // The same width as the floating palette, so the two surfaces line up;
        // the height is the popover's own, which a short list should not fill.
        .frame(
            width: MoonlightGlassMetrics.paletteSize.width,
            height: MoonlightGlassMetrics.menuBarHeight
        )
        .onAppear {
            // Before anything activates Moonlight: afterwards the app in front
            // is Moonlight itself and the origin is lost.
            model.capture()
            coordinator.prepareMenuBarPalette()
            menuBarToken = coordinator.registerMenuBar(dismiss: { dismiss() })
        }
        .task {
            await model.load()
        }
        .onDisappear {
            // A previous instance can disappear after a new one registered.
            // The token keeps it from clearing someone else's dismissal.
            if let menuBarToken {
                coordinator.unregisterMenuBar(menuBarToken)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Tools", systemImage: "command") {
                dismiss()
                coordinator.presentPalette(isolatingFromMainWindow: true)
            }
            .help("Open the Moonlight tool palette")

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
        .padding(MoonlightGlassMetrics.contentPadding)
    }
}
