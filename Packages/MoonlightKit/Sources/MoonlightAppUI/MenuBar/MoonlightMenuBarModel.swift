import AppKit
import MoonlightDomain
import Observation

/// What the menu bar popover shows: the app the user was in, its own
/// shortcuts, and Moonlight's favourites under them.
///
/// The frontmost application has to be read before Moonlight activates —
/// afterwards the app in front is Moonlight — so `capture()` is called by the
/// coordinator at invocation time and `load()` only uses what it kept.
@MainActor
@Observable
public final class MoonlightMenuBarModel {
    public private(set) var activeApp: MoonlightSourceContext?
    public private(set) var activeAppIcon: NSImage?
    public private(set) var shortcuts: [ActiveAppShortcut] = []
    public private(set) var isReadingShortcuts = false
    /// Whether macOS has granted the accessibility permission the menu bar
    /// section depends on. Read rather than assumed: it can be revoked at any
    /// time from System Settings.
    public private(set) var isPermittedToReadShortcuts = ActiveAppShortcutsReader.isPermitted

    private var capturedProcessIdentifier: pid_t?
    private let reader: ActiveAppShortcutsReader

    public init(reader: ActiveAppShortcutsReader = ActiveAppShortcutsReader()) {
        self.reader = reader
    }

    /// A model holding fixed content, for snapshots and tests.
    ///
    /// The real one reads another app's menu bar, which depends on which app
    /// is in front and on a permission the renderer does not have: the image
    /// has to be the same wherever it is drawn.
    public init(activeAppName: String, shortcuts: [ActiveAppShortcut]) {
        reader = ActiveAppShortcutsReader()
        activeApp = MoonlightSourceContext(bundleIdentifier: nil, name: activeAppName)
        self.shortcuts = shortcuts
        isPermittedToReadShortcuts = true
    }

    /// Records which app was in front. Call before Moonlight takes activation.
    public func capture(
        frontmostApplication: NSRunningApplication? = NSWorkspace.shared.frontmostApplication,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        activeApp = MoonlightSourceContext.current(
            ownBundleIdentifier: ownBundleIdentifier,
            frontmostApplication: frontmostApplication
        )
        guard activeApp != nil else {
            capturedProcessIdentifier = nil
            activeAppIcon = nil
            return
        }
        capturedProcessIdentifier = frontmostApplication?.processIdentifier
        activeAppIcon = frontmostApplication?.icon
    }

    /// Reads the captured app's shortcuts.
    ///
    /// Off the main actor: walking another app's menu bar is a synchronous
    /// round trip per attribute, and a popover must not wait on it.
    public func load() async {
        isPermittedToReadShortcuts = ActiveAppShortcutsReader.isPermitted
        guard isPermittedToReadShortcuts, let capturedProcessIdentifier else {
            shortcuts = []
            return
        }

        isReadingShortcuts = true
        defer { isReadingShortcuts = false }

        let reader = reader
        shortcuts = await Task.detached {
            reader.shortcuts(forProcessIdentifier: capturedProcessIdentifier)
        }.value
    }

    public func requestShortcutsPermission() {
        ActiveAppShortcutsReader.requestPermission()
    }

    /// The favourites, resolved against the catalogue and ordered by title.
    public func favorites(in palette: MoonlightToolPaletteModel) -> [MenuBarFavorite] {
        palette.descriptors
            .filter { palette.favoriteIDs.contains($0.id) }
            .sorted { $0.title < $1.title }
            .map { descriptor in
                MenuBarFavorite(
                    id: descriptor.id,
                    title: descriptor.title,
                    summary: descriptor.summary,
                    alias: palette.alias(for: descriptor)
                )
            }
    }
}
