import MoonlightAppUI
import SwiftUI

@main
struct MoonlightApp: App {
    var body: some Scene {
        Window("Moonlight", id: "main") {
            MoonlightRootView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
