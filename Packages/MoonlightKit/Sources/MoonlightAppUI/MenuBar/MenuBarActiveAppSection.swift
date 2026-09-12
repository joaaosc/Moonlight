import SwiftUI

/// The app the user was in, and the shortcuts it publishes.
///
/// The prominent half of the popover: what is on screen behind Moonlight is
/// the thing the user is actually doing, so it leads.
public struct MenuBarActiveAppSection: View {
    private let model: MoonlightMenuBarModel

    public init(model: MoonlightMenuBarModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if model.activeApp == nil {
                caption("Moonlight was in front, so there is no app to read.")
            } else if !model.isPermittedToReadShortcuts {
                permissionRequest
            } else if model.isReadingShortcuts {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.shortcuts.isEmpty {
                caption("This app publishes no keyboard shortcuts.")
            } else {
                ForEach(model.shortcuts) { shortcut in
                    MenuBarShortcutRow(shortcut: shortcut)
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.activeAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "macwindow")
                    .foregroundStyle(MoonlightGlassPalette.glyph)
                    .accessibilityHidden(true)
            }

            Text(model.activeApp?.name ?? "Moonlight")
                .font(.headline)
        }
    }

    /// Both ways in, because neither one works every time.
    ///
    /// macOS shows the accessibility prompt once per app. After the user has
    /// answered it, asking again is silent — the button looked broken — so the
    /// Settings pane is offered next to it rather than hidden behind a second
    /// press.
    private var permissionRequest: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption("Moonlight needs accessibility access to read this app's shortcuts. Switch Moonlight on under Privacy & Security › Accessibility.")
            HStack(spacing: 12) {
                Button("Allow Access") {
                    model.requestShortcutsPermission()
                }
                .help("Ask macOS for accessibility access")

                Button("Open System Settings") {
                    model.openShortcutsPermissionSettings()
                }
                .help("Open Privacy & Security › Accessibility")
            }
            .buttonStyle(.link)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
