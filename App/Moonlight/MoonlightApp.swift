import AppIntents
import AppKit
import MoonlightAppUI
import MoonlightInfrastructure
import MoonlightIntents
import MoonlightShortcuts
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
    /// Moonlight's own system-wide shortcut. Registered with macOS; unrelated
    /// to Spotlight and never announced as a Spotlight feature.
    private let hotKeyCenter = GlobalHotKeyCenter()

    private static let logger = Logger(
        subsystem: "com.joaocosta.Moonlight",
        category: "Spotlight"
    )

    init() {
        // The host process composes its dependencies once and hands them to
        // the surfaces below. The App Intents extension composes its own, and
        // only this process gets the Apple Events client: extensions may not
        // send them.
        let environment = MoonlightProcess.install(Self.composeEnvironment())
        let coordinator = MoonlightPresentationCoordinator(environment: environment)
        self.coordinator = coordinator
        hotKeyCenter.start {
            coordinator.presentPalette(isolatingFromMainWindow: true)
        }

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
                },
                copyToPasteboard: { text in
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
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

    private static func composeEnvironment() -> Result<MoonlightEnvironment, MoonlightRuntimeError> {
        do {
            let shortcuts = ShortcutsEventsClient()
            return .success(
                try MoonlightEnvironment.live(
                    shortcuts: shortcuts.catalogClient(),
                    shortcutRunner: shortcuts.runClient()
                )
            )
        } catch {
            return .failure(.initializationFailed(error.localizedDescription))
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
            MoonlightSettingsView(hotKeyCenter: hotKeyCenter)
        }

        MenuBarExtra("Moonlight", systemImage: "moon.stars") {
            MoonlightMenuBarView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
