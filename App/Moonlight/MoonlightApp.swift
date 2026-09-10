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

    /// The host owns presentation. Surfaces receive this instance explicitly
    /// instead of reaching for a global route.
    private let coordinator: MoonlightPresentationCoordinator

    private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "Spotlight"
    )

    init() {
        let coordinator = MoonlightPresentationCoordinator()
        self.coordinator = coordinator

        AppDependencyManager.shared.add(
            dependency: MoonlightForegroundClient(
                presentColorPicker: {
                    coordinator.presentColorPicker(
                        isolatingFromMainWindow: true
                    )
                },
                presentToolPalette: { actionID in
                    coordinator.presentPalette(
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
                    coordinator.presentPalette(
                        isolatingFromMainWindow: false
                    )
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Open History") {
                    coordinator.dismissPalette()
                    openWindow(id: "main")
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Open Color Picker") {
                    coordinator.presentColorPicker(
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
            MoonlightMenuBarView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
