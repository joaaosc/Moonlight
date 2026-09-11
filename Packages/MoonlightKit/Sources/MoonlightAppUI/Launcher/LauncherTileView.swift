import AppKit
import MoonlightDomain
import SwiftUI

/// Geometry the launcher grid and its tiles agree on.
enum LauncherMetrics {
    static let iconSize: CGFloat = 64
    static let tileWidth: CGFloat = 112
    static let tileSpacing: CGFloat = 16
    static let selectionRadius: CGFloat = 12
}

/// One app in the grid: its icon, its name, and nothing else.
///
/// The name is allowed two lines and then truncates. Apps with long names are
/// common enough that one line would leave a column of ellipses, and three
/// would make the rows uneven.
struct LauncherAppTile: View {
    let app: InstalledApp
    let icon: NSImage
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: LauncherMetrics.iconSize, height: LauncherMetrics.iconSize)

            Text(app.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: LauncherMetrics.tileWidth)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: LauncherMetrics.selectionRadius, style: .continuous)
                    .fill(.primary.opacity(0.10))
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
    }
}

/// A folder in the grid, drawn as the small grid of what it holds.
///
/// The miniature is the only reliable way to tell two folders apart at a
/// glance: the name sits below at the same size as an app's, so a generic
/// folder glyph would make every folder look alike.
struct LauncherFolderTile: View {
    let folder: LauncherFolder
    let icons: [NSImage]
    let isSelected: Bool

    private var preview: [NSImage] { Array(icons.prefix(4)) }

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(22), spacing: 4), count: 2),
                spacing: 4
            ) {
                ForEach(Array(preview.enumerated()), id: \.offset) { _, icon in
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                }
            }
            .frame(width: LauncherMetrics.iconSize, height: LauncherMetrics.iconSize)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.primary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            }

            Text(folder.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: LauncherMetrics.tileWidth)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: LauncherMetrics.selectionRadius, style: .continuous)
                    .fill(.primary.opacity(0.10))
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.name), \(folder.appIdentifiers.count) apps")
        .accessibilityAddTraits(.isButton)
    }
}

/// The empty slot. It occupies space and draws nothing, which is the whole
/// point: a hole keeps the apps around it where the user left them.
struct LauncherEmptyTile: View {
    var body: some View {
        Color.clear
            .frame(width: LauncherMetrics.tileWidth, height: LauncherMetrics.iconSize + 48)
            .accessibilityHidden(true)
    }
}
