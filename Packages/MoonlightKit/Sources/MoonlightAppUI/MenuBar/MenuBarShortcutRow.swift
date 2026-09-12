import SwiftUI

/// One shortcut belonging to the app in front.
///
/// Not a button: Moonlight reads these, it does not perform them. Making the
/// row look pressable would promise something the popover cannot deliver.
struct MenuBarShortcutRow: View {
    let shortcut: ActiveAppShortcut

    var body: some View {
        HStack(spacing: 10) {
            Text(shortcut.title)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(shortcut.keys)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .moonlightFieldBackground(MoonlightGlassMetrics.fieldShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.title), \(shortcut.menuTitle) menu, \(shortcut.keys)")
    }
}
