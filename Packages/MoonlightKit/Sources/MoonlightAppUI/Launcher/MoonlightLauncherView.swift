import AppKit
import MoonlightDomain
import SwiftUI

/// The launcher: every installed app, arranged, searchable, one page at a time.
///
/// Glass belongs to the panel behind this view, not to the grid. The project's
/// rule is that Liquid Glass is the transient controls layer; a wall of icons is
/// content, and giving it its own material would put glass on glass.
public struct MoonlightLauncherView: View {
    @Bindable private var model: MoonlightLauncherModel
    @FocusState private var isSearchFocused: Bool
    private let onDismiss: () -> Void

    public init(model: MoonlightLauncherModel, onDismiss: @escaping () -> Void = {}) {
        self.model = model
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 18) {
            searchField

            if let failure = model.failure {
                message(failure, symbol: "exclamationmark.triangle")
            } else if model.isLoading, model.apps.isEmpty {
                message("Reading your applications…", symbol: "hourglass")
            } else if model.isSearching {
                searchResults
            } else {
                page
            }

            footer
        }
        .padding(MoonlightGlassMetrics.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if let folder = model.openFolder {
                folderOverlay(folder)
            }
        }
        .onKeyPress(.escape) {
            if model.openFolder != nil {
                model.openFolder = nil
            } else if model.isSearching {
                model.query = ""
            } else {
                onDismiss()
            }
            return .handled
        }
        .onKeyPress(.return) {
            Task { await launchSelection() }
            return .handled
        }
        .onKeyPress(.leftArrow) { move(by: -1) }
        .onKeyPress(.rightArrow) { move(by: 1) }
        .onKeyPress(.upArrow) { move(by: -columns) }
        .onKeyPress(.downArrow) { move(by: columns) }
        .onKeyPress(.tab) {
            model.goToNextPage()
            return .handled
        }
        .task {
            await model.load()
            isSearchFocused = true
        }
    }

    private var columns: Int { model.layout.grid.columns }

    private var gridColumns: [GridItem] {
        gridColumns(count: columns)
    }

    /// The arrangement always reserves a full row, because an empty slot is
    /// part of it. A result list does not: six results should read as six
    /// centred icons, not as six icons and a gap where the seventh would be.
    private func gridColumns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(LauncherMetrics.tileWidth),
                spacing: LauncherMetrics.tileSpacing
            ),
            count: max(1, min(count, columns))
        )
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onSubmit { Task { await launchSelection() } }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .moonlightFieldBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous),
            isGlass: true
        )
        .frame(maxWidth: 520)
    }

    private var page: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            centered {
                LazyVGrid(columns: gridColumns, spacing: LauncherMetrics.tileSpacing) {
                    ForEach(model.items(onPage: model.currentPage)) { item in
                        tile(for: item)
                    }
                }
            }

            if model.pageCount > 1 {
                pageIndicator
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Centres a fixed-width grid in whatever space the screen gives it.
    private func centered(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func tile(for item: LauncherItem) -> some View {
        switch item {
        case .empty:
            LauncherEmptyTile()
        case let .app(identifier):
            if let app = model.app(for: identifier) {
                LauncherAppTile(
                    app: app,
                    icon: model.icon(for: app),
                    isSelected: model.selection == identifier
                )
                .onTapGesture { Task { await launch(app) } }
                .contextMenu { appMenu(app) }
            }
        case let .folder(folder):
            LauncherFolderTile(
                folder: folder,
                icons: folder.appIdentifiers.compactMap { model.app(for: $0) }.map { model.icon(for: $0) },
                isSelected: false
            )
            .onTapGesture { model.openFolder = folder }
        }
    }

    private var searchResults: some View {
        ScrollView {
            centered {
                LazyVGrid(
                    columns: gridColumns(count: model.searchResults.count),
                    spacing: LauncherMetrics.tileSpacing
                ) {
                    ForEach(model.searchResults) { app in
                        LauncherAppTile(
                            app: app,
                            icon: model.icon(for: app),
                            isSelected: model.selection == app.bundleIdentifier
                        )
                        .onTapGesture { Task { await launch(app) } }
                        .contextMenu { appMenu(app) }
                    }
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.never)
        .overlay {
            if model.searchResults.isEmpty {
                message("No apps match “\(model.query)”.", symbol: "magnifyingglass")
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< model.pageCount, id: \.self) { index in
                dot(for: index)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Split out of `pageIndicator`: the ternary between two shape styles was
    /// enough to defeat type inference inside the ForEach.
    private func dot(for index: Int) -> some View {
        let opacity: Double = index == model.currentPage ? 0.65 : 0.20
        return Circle()
            .fill(Color.primary.opacity(opacity))
            .frame(width: 7, height: 7)
            .onTapGesture { model.currentPage = index }
            .accessibilityLabel("Page \(index + 1)")
    }

    /// Centred rather than pinned to a corner: on a full screen the corner is
    /// nowhere near anything the user is looking at.
    private var footer: some View {
        HStack(spacing: 10) {
            KeyHint(symbol: "arrow.up.and.down.and.arrow.left.and.right", action: "Select")
            KeyHint(symbol: "return", action: "Open")
            if model.pageCount > 1 {
                KeyHint(symbol: "arrow.right.to.line", action: "Next page")
            }
            KeyHint(symbol: "escape", action: "Close")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func appMenu(_ app: InstalledApp) -> some View {
        Button("Open") { Task { await launch(app) } }
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([app.url])
            onDismiss()
        }
        Divider()
        Button("Hide from Launcher") { model.hide(app) }
    }

    private func folderOverlay(_ folder: LauncherFolder) -> some View {
        VStack(spacing: 14) {
            Text(folder.name)
                .font(.headline)

            LazyVGrid(
                columns: gridColumns(count: folder.appIdentifiers.count),
                spacing: LauncherMetrics.tileSpacing
            ) {
                ForEach(folder.appIdentifiers, id: \.self) { identifier in
                    if let app = model.app(for: identifier) {
                        LauncherAppTile(
                            app: app,
                            icon: model.icon(for: app),
                            isSelected: model.selection == identifier
                        )
                        .onTapGesture { Task { await launch(app) } }
                    }
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
        .padding(40)
        // Tapping outside closes it, the way a folder on a launcher behaves.
        .background {
            Color.black.opacity(0.001)
                .onTapGesture { model.openFolder = nil }
        }
    }

    private func message(_ text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func move(by offset: Int) -> KeyPress.Result {
        model.moveSelection(by: offset)
        return .handled
    }

    private func launch(_ app: InstalledApp) async {
        await model.open(app)
        onDismiss()
    }

    private func launchSelection() async {
        if await model.openSelection() {
            onDismiss()
        }
    }
}
