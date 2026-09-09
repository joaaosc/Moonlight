import AppKit
import MoonlightAppUI

@MainActor
final class MoonlightApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !MoonlightLaunchContext.showsHistoryForTesting,
              notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true,
              !MoonlightPresentationRoute.hasPresentedTool else { return }
        MoonlightPresentationRoute.presentPalette(isolatingFromMainWindow: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !MoonlightLaunchContext.showsHistoryForTesting else { return true }
        MoonlightPresentationRoute.presentPalette(isolatingFromMainWindow: true)
        return false
    }
}

@MainActor
enum MoonlightLaunchContext {
    static var showsHistoryForTesting: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("--moonlight-testing-show-history")
            || processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

@MainActor
enum MoonlightPresentationRoute {
    static private(set) var hasPresentedTool = false

    static func presentPalette(
        preferredActionID: String? = nil,
        isolatingFromMainWindow: Bool
    ) {
        hasPresentedTool = true
        MoonlightToolPalettePresenter.shared.present(
            preferredActionID: preferredActionID,
            isolatingFromMainWindow: isolatingFromMainWindow,
            onOpenColorPicker: {
                MoonlightToolPalettePresenter.shared.dismiss()
                presentColorPicker(isolatingFromMainWindow: true)
            }
        )
    }

    static func presentColorPicker(isolatingFromMainWindow: Bool) {
        hasPresentedTool = true
        MoonlightToolPalettePresenter.shared.dismiss()
        MoonlightColorPanelPresenter.shared.present(
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

}
