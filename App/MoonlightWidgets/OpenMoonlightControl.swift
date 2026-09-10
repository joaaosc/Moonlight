import AppIntents
import MoonlightIntents
import SwiftUI
import WidgetKit

/// A Control Center button that opens the Moonlight palette.
///
/// Controls are available on macOS 26 and later; the app targets macOS 27.
struct OpenMoonlightControl: ControlWidget {
    static let kind = "MoonlightOpenPalette"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenMoonlightIntent()) {
                Label("Moonlight", systemImage: "moon.stars")
            }
        }
        .displayName("Open Moonlight")
        .description("Opens the Moonlight command palette.")
    }
}
