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
    /// What the sections actually take, measured rather than assumed: the list
    /// is one app's shortcuts and a few favourites, and its length changes with
    /// whatever is in front.
    @State private var contentHeight: CGFloat = MoonlightGlassMetrics.menuBarMinimumHeight

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
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: scrollHeight)

            Divider()
            footer
        }
        // The same width as the floating palette, so the two surfaces line up.
        // The height is the content's, between a floor and a ceiling: a fixed
        // one left most of the panel empty, because what it lists is short.
        .frame(width: MoonlightGlassMetrics.paletteSize.width)
        .onAppear {
            // Reads the remembered origin, not the live frontmost application:
            // clicking the status item activated Moonlight before this content
            // existed, so asking the workspace now would only name Moonlight.
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

    /// The scroll area's height: the content's, clamped.
    private var scrollHeight: CGFloat {
        min(
            max(contentHeight, MoonlightGlassMetrics.menuBarMinimumHeight),
            MoonlightGlassMetrics.menuBarHeight
        )
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
