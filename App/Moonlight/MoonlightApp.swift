import MoonlightAppUI
import MoonlightIntents
import SwiftUI

@main
struct MoonlightApp: App {
    var body: some Scene {
        WindowGroup {
            MoonlightRootView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
    }
}
