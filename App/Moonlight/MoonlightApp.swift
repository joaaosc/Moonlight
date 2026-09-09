import AppIntents
import AppKit
import MoonlightAppUI
import MoonlightIntents
import OSLog
import SwiftUI

struct MoonlightApplicationIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MoonlightIntentsPackage.self]
    }
}

@main
struct MoonlightApp: App {
    @NSApplicationDelegateAdaptor(MoonlightApplicationDelegate.self)
    private var applicationDelegate
    @Environment(\.openWindow) private var openWindow

    private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "Spotlight"
    )

    init() {
        AppDependencyManager.shared.add(
            dependency: MoonlightForegroundClient(
                presentColorPicker: {
                    MoonlightPresentationRoute.presentColorPicker(
                        isolatingFromMainWindow: true
                    )
                },
                presentToolPalette: { actionID in
                    MoonlightPresentationRoute.presentPalette(
                        preferredActionID: actionID,
                        isolatingFromMainWindow: true
                    )
                }
            )
        )

        let showsHistoryForTesting = MoonlightLaunchContext.showsHistoryForTesting
        guard !showsHistoryForTesting else {
            return
        }
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = true
        ProcessInfo.processInfo.disableAutomaticTermination(
            "Moonlight keeps Spotlight commands and its menu bar available"
        )
        Task {
            do {
                try await MoonlightToolSpotlightIndex.refresh()
            } catch {
                Self.logger.error(
                    "Failed to refresh the Moonlight tool index: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup("Moonlight", id: "main") {
            MoonlightRootView()
        }
        .defaultLaunchBehavior(MoonlightLaunchContext.showsHistoryForTesting ? .presented : .suppressed)
        .restorationBehavior(.disabled)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Tools") {
                Button("Open Moonlight Tools") {
                    MoonlightPresentationRoute.presentPalette(
                        isolatingFromMainWindow: false
                    )
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Open History") {
                    MoonlightToolPalettePresenter.shared.dismiss()
                    openWindow(id: "main")
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Open Color Picker") {
                    MoonlightPresentationRoute.presentColorPicker(
                        isolatingFromMainWindow: false
                    )
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            MoonlightSettingsView()
        }

        MenuBarExtra("Moonlight", systemImage: "moon.stars") {
            MoonlightMenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
