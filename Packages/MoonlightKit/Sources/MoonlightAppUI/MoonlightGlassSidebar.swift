import SwiftUI

/// Floating Liquid Glass sidebar matching the macOS 27 navigation panel in the reference image.
public struct MoonlightGlassSidebar<Selection: Hashable>: View {
    public struct Item: Identifiable {
        public let id: Selection
        public let title: String
        public let symbolName: String
        public let badgeCount: Int?

        public init(
            id: Selection,
            title: String,
            symbolName: String,
            badgeCount: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.symbolName = symbolName
            self.badgeCount = badgeCount
        }
    }

    @Binding public var selection: Selection
    public let items: [Item]
    public let onToggleSidebar: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        selection: Binding<Selection>,
        items: [Item],
        onToggleSidebar: @escaping () -> Void
    ) {
        self._selection = selection
        self.items = items
        self.onToggleSidebar = onToggleSidebar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Sidebar Header (Logo and Collapse Button matching top-right toggle in reference)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Moonlight")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Collapse sidebar button
                Button {
                    onToggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(.white.opacity(0.12))
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.30), lineWidth: 0.8)
                                }
                        }
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar")
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            // Navigation Items (Matching "Landmarks", "Map", "Collections" layout)
            VStack(spacing: 6) {
                ForEach(items) { item in
                    SidebarRow(
                        item: item,
                        isSelected: selection == item.id
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                            selection = item.id
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bottom System Status / macOS 27 Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)

                Text("Liquid Glass Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Text("macOS 27")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.60))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background {
            // Liquid Glass Material Surface
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    // Subtle dynamic wash
                    RadialGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 260
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            // Specular border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.45 : 0.70),
                            .white.opacity(colorScheme == .dark ? 0.12 : 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 16, x: 4, y: 4)
    }
}

private struct SidebarRow<Selection: Hashable>: View {
    let item: MoonlightGlassSidebar<Selection>.Item
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                    .frame(width: 24)

                Text(item.title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.90))

                Spacer()

                if let count = item.badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.40), lineWidth: 1)
                        }
                        .shadow(color: .white.opacity(0.15), radius: 4)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.10))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
