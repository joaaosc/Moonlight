import AppIntents
import MoonlightAppUI
import MoonlightIntents
import SwiftUI

@main
struct MoonlightApp: App {
    init() {
        AppDependencyManager.shared.add(
            dependency: MoonlightForegroundClient {
                MoonlightColorPanelPresenter.shared.present(
                    isolatingFromMainWindow: true
                )
            }
        )
    }

    var body: some Scene {
        Window("Moonlight", id: "main") {
            MoonlightRootView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Tools") {
                Button("Open Color Picker") {
                    MoonlightColorPanelPresenter.shared.present()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}
