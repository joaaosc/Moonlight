import AppKit
import MoonlightDomain
import MoonlightInfrastructure

/// Owns palette and color picker presentation for one host process.
///
/// Replaces the previous global route: the app creates and holds the single
/// instance and hands it to the surfaces that need it, so presentation state
/// is explicit ownership instead of ambient statics.
@MainActor
public final class MoonlightPresentationCoordinator {
    /// Identifies one menu bar registration. A disappearing instance may only
    /// clear the callback it registered; SwiftUI can deliver the old view's
    /// disappearance after a new one already registered its own dismissal.
    public struct MenuBarToken: Hashable, Sendable {
        fileprivate let value: UUID

        fileprivate init() {
            value = UUID()
        }
    }

    public private(set) lazy var paletteModel = MoonlightToolPaletteModel(
        environment: environment,
        onOpenColorPicker: { [weak self] in
            self?.presentColorPicker(isolatingFromMainWindow: true)
        }
    )

    private let environment: Result<MoonlightEnvironment, MoonlightRuntimeError>
    private let palettePresenter: MoonlightToolPalettePresenter
    private let colorPanelPresenter: MoonlightColorPanelPresenter
    private var menuBarToken: MenuBarToken?
    private var dismissMenuBar: (@MainActor () -> Void)?

    public init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment,
        palettePresenter: MoonlightToolPalettePresenter = .shared,
        colorPanelPresenter: MoonlightColorPanelPresenter = .shared
    ) {
        self.environment = environment
        self.palettePresenter = palettePresenter
        self.colorPanelPresenter = colorPanelPresenter
    }

    /// Registers the dismissal of the menu bar window currently on screen.
    @discardableResult
    public func registerMenuBar(dismiss: @escaping @MainActor () -> Void) -> MenuBarToken {
        let token = MenuBarToken()
        menuBarToken = token
        dismissMenuBar = dismiss
        return token
    }

    /// Clears the registration only when `token` is still the active one.
    public func unregisterMenuBar(_ token: MenuBarToken) {
        guard menuBarToken == token else { return }
        menuBarToken = nil
        dismissMenuBar = nil
    }

    public var isMenuBarRegistered: Bool {
        dismissMenuBar != nil
    }

    public func presentPalette(
        preferredActionID: String? = nil,
        isolatingFromMainWindow: Bool
    ) {
        dismissMenuBar?()
        paletteModel.preparePresentation(preferredActionID: preferredActionID)
        palettePresenter.present(
            model: paletteModel,
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

    public func presentColorPicker(isolatingFromMainWindow: Bool) {
        dismissMenuBar?()
        palettePresenter.dismiss()
        colorPanelPresenter.present(
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

    /// Prepares the palette embedded in the menu bar window.
    public func prepareMenuBarPalette() {
        palettePresenter.dismiss()
        paletteModel.preparePresentation()
    }

    public func dismissPalette() {
        palettePresenter.dismiss()
    }
}
