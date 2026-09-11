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

    /// The launcher's state. Created on first use, then kept: reading the
    /// catalogue again on every presentation is fine, rebuilding the model is
    /// not — it would drop the page the user was on.
    public private(set) lazy var launcherModel = MoonlightLauncherModel()

    /// Requests aimed at the notes section of the main window.
    public let notesFocus = MoonlightNotesFocus()

    private let environment: Result<MoonlightEnvironment, MoonlightRuntimeError>
    private let palettePresenter: MoonlightToolPalettePresenter
    private let colorPanelPresenter: MoonlightColorPanelPresenter
    private let launcherPresenter: MoonlightLauncherPresenter
    private var menuBarToken: MenuBarToken?
    private var dismissMenuBar: (@MainActor () -> Void)?
    private var openMainWindow: (@MainActor () -> Void)?

    public init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment,
        palettePresenter: MoonlightToolPalettePresenter = .shared,
        colorPanelPresenter: MoonlightColorPanelPresenter = .shared,
        launcherPresenter: MoonlightLauncherPresenter = .shared
    ) {
        self.environment = environment
        self.palettePresenter = palettePresenter
        self.colorPanelPresenter = colorPanelPresenter
        self.launcherPresenter = launcherPresenter
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
        isolatingFromMainWindow: Bool,
        initialInput: String? = nil,
        initialQuery: String? = nil,
        activation: MoonlightToolPalettePresenter.Activation = .standard
    ) {
        // Read the origin before anything activates Moonlight.
        let sourceContext = MoonlightSourceContext.current()
        dismissMenuBar?()
        paletteModel.preparePresentation(
            preferredActionID: preferredActionID,
            sourceContext: sourceContext,
            initialInput: initialInput,
            initialQuery: initialQuery
        )
        palettePresenter.present(
            model: paletteModel,
            isolatingFromMainWindow: isolatingFromMainWindow,
            activation: activation
        )
    }

    /// Opens the Moonlight window and insists on the keyboard.
    ///
    /// The catalogue is reset first: a window asked for by name should not open
    /// on whatever half-typed search the previous invocation left behind.
    public func presentWindow(isolatingFromMainWindow: Bool) {
        presentPalette(
            isolatingFromMainWindow: isolatingFromMainWindow,
            initialQuery: "",
            activation: .forced
        )
    }

    /// Opens the palette on a command the user already started typing.
    ///
    /// The text lands in the search field rather than running: a command that
    /// Moonlight does not publish yet must stay visible and editable instead of
    /// disappearing into an error.
    public func presentCommandLine(text: String, isolatingFromMainWindow: Bool) {
        presentPalette(
            isolatingFromMainWindow: isolatingFromMainWindow,
            initialQuery: text
        )
    }

    /// Opens the launcher, or closes it when it is already up.
    ///
    /// Toggling rather than always presenting: the shortcut that opens a
    /// full-screen surface is the one the user reaches for to get rid of it.
    public func toggleLauncher() {
        dismissMenuBar?()
        palettePresenter.dismiss()
        launcherPresenter.toggle(model: launcherModel)
    }

    public func presentLauncher() {
        dismissMenuBar?()
        palettePresenter.dismiss()
        launcherPresenter.present(model: launcherModel)
    }

    public func dismissLauncher() {
        launcherPresenter.dismiss()
    }

    public func presentColorPicker(isolatingFromMainWindow: Bool) {
        dismissMenuBar?()
        palettePresenter.dismiss()
        colorPanelPresenter.present(
            isolatingFromMainWindow: isolatingFromMainWindow
        )
    }

    /// Registers how the host opens its main window. SwiftUI owns that action,
    /// so the coordinator asks for it instead of guessing at a window.
    public func registerMainWindowOpener(_ open: @escaping @MainActor () -> Void) {
        openMainWindow = open
    }

    /// Opens the notes section, optionally on a search or a specific note.
    public func presentNotes(searchText: String = "", noteID: UUID? = nil) {
        dismissMenuBar?()
        palettePresenter.dismiss()
        notesFocus.request(searchText: searchText, noteID: noteID)

        if let openMainWindow {
            openMainWindow()
        } else {
            // No opener registered yet: bring an existing window forward rather
            // than failing silently. A window that does not exist cannot be
            // created from here, and inventing one would be worse.
            NSApplication.shared.activate()
            NSApplication.shared.windows
                .first { $0.identifier?.rawValue == "main" }?
                .makeKeyAndOrderFront(nil)
        }
    }

    /// Prepares the palette embedded in the menu bar window.
    public func prepareMenuBarPalette() {
        let sourceContext = MoonlightSourceContext.current()
        palettePresenter.dismiss()
        paletteModel.preparePresentation(sourceContext: sourceContext)
    }

    public func dismissPalette() {
        palettePresenter.dismiss()
    }
}
