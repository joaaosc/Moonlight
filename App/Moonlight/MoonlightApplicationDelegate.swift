import AppKit
import MoonlightAppUI
import OSLog

@MainActor
final class MoonlightApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let showsDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        if !NSApplication.shared.setActivationPolicy(showsDockIcon ? .regular : .accessory) {
            Logger(subsystem: "com.joaocosta.Moonlight", category: "Application")
                .error("Unable to apply the saved Dock visibility preference")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // Foreground intents can reopen the process before their destination is
        // known. Only explicit commands present UI; never guess a palette here.
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
    static var dismissMenuBar: (@MainActor () -> Void)?
    static let paletteModel = MoonlightToolPaletteModel(onOpenColorPicker: {
        presentColorPicker(isolatingFromMainWindow: true)
    })

    static func presentPalette(
        preferredActionID: String? = nil,
        isolatingFromMainWindow: Bool
    ) {
        dismissMenuBar?()
        paletteModel.preparePresentation(preferredActionID: preferredActionID)
        MoonlightToolPalettePresenter.shared.present(
            model: paletteModel,
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

    static func presentColorPicker(isolatingFromMainWindow: Bool) {
        dismissMenuBar?()
        MoonlightToolPalettePresenter.shared.dismiss()
        MoonlightColorPanelPresenter.shared.present(
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

}
