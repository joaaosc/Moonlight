import SwiftUI
import WidgetKit

@main
struct MoonlightWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoonlightFavoritesWidget()
        OpenMoonlightControl()
    }
}
