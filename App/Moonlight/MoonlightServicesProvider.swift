import AppKit
import MoonlightAppUI

/// Receives text selected in another app through the macOS Services menu.
///
/// The selection arrives as data on a pasteboard the system owns; Moonlight
/// reads it once and opens the palette with it, so the user never retypes what
/// they already selected.
@MainActor
final class MoonlightServicesProvider: NSObject {
    private let coordinator: MoonlightPresentationCoordinator

    init(coordinator: MoonlightPresentationCoordinator) {
        self.coordinator = coordinator
    }

    /// Registers the provider. `NSUpdateDynamicServices` makes the entry appear
    /// without a logout during development.
    func install() {
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc
    func sendTextToMoonlight(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "Moonlight received no text." as NSString
            return
        }

        coordinator.presentPalette(
            isolatingFromMainWindow: true,
            initialInput: text
        )
    }
}
