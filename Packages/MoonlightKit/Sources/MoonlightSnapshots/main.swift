import AppKit
import MoonlightAppUI
import MoonlightDomain
import MoonlightInfrastructure
import MoonlightSnippetUI
import SwiftUI

/// Renders Moonlight's screens to PNG files.
///
/// Exists so the interface can be inspected without launching the app and
/// without anyone watching a screen: the renderer draws the same SwiftUI views
/// the app uses, from fixtures, and writes them to disk.
/// Carries a value across the detached task that produces it. Safe here
/// because the semaphore makes the two accesses strictly ordered.
private final class UncheckedBox<Value>: @unchecked Sendable {
    var value: Value?
}

@MainActor
enum MoonlightSnapshots {
    static func run() {
        // A plain ImageRenderer cannot draw AppKit-backed controls such as
        // List and TextField; they come out as the missing-content placeholder.
        // Hosting the view in an offscreen window renders what the app renders.
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()

        let outputDirectory = URL(
            filePath: CommandLine.arguments.count > 1
                ? CommandLine.arguments[1]
                : FileManager.default.currentDirectoryPath
        )
        try? FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for (name, size, view) in screens() {
            render(view, named: name, size: size, in: outputDirectory)
        }
    }

    /// Drains an immediate async answer on the current run loop. Only sound
    /// for the stub catalogue, which never actually suspends.
    private static func awaitApps(_ catalog: StubAppCatalog) throws -> [InstalledApp] {
        let box = UncheckedBox<[InstalledApp]>()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            box.value = try? await catalog.apps()
            semaphore.signal()
        }
        semaphore.wait()
        return box.value ?? []
    }

    private static func screens() -> [(String, CGSize, AnyView)] {
        let paletteModel = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferences: nil
        )

        let editingModel = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferredActionID: MoonlightActionID.base64Text,
            preferences: nil
        )

        let launcherModel = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferences: nil
        )

        let launcherEditingModel = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferredActionID: MoonlightActionID.base64Text,
            preferences: nil
        )

        let commandModel = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferences: nil
        )
        commandModel.preparePresentation(initialQuery: "/note Buy milk and bread")

        let shortcutsModel = MoonlightShortcutsModel(
            shortcuts: .stub([
                ShortcutSummary(
                    externalID: "A",
                    name: "Daily Note",
                    subtitle: "Notes",
                    acceptsInput: true,
                    actionCount: 4
                ),
                ShortcutSummary(externalID: "B", name: "Daily Note", actionCount: 2),
                ShortcutSummary(externalID: "C", name: "Resize Window", actionCount: 7),
            ]),
            store: nil,
            cache: ShortcutBindingsCache()
        )

        // The launcher draws whatever the catalogue reports, so the snapshot
        // seeds one rather than reading this machine's /Applications: the image
        // has to be the same wherever it is rendered.
        let appNames = [
            "Activity Monitor", "Automator", "Books", "Calculator", "Calendar",
            "Chess", "Clock", "Contacts", "Dictionary", "FaceTime",
            "Find My", "Font Book", "Freeform", "Home", "Image Playground",
            "Journal", "Keychain Access", "Mail", "Maps", "Messages",
            "Music", "News", "Notes", "Passwords", "Photos",
            "Podcasts", "Preview", "Reminders", "Safari", "Shortcuts",
            "Stocks", "System Settings", "Terminal", "TextEdit", "Weather",
        ]
        let installedApps = StubAppCatalog.named(appNames)
        let launcherGridModel = MoonlightLauncherModel(
            catalog: installedApps,
            store: nil
        )
        launcherGridModel.preload(apps: (try? awaitApps(installedApps)) ?? [])

        let launcherSearchModel = MoonlightLauncherModel(
            catalog: installedApps,
            store: nil
        )
        launcherSearchModel.preload(apps: (try? awaitApps(installedApps)) ?? [])
        launcherSearchModel.query = "ca"

        let quicklinksModel = MoonlightQuicklinksModel(
            store: nil,
            cache: QuicklinkCache(quicklinks: [
                QuicklinkCommand(
                    title: "Search the web",
                    urlTemplate: "https://duckduckgo.com/?q={query}",
                    alias: "search"
                ),
            ])
        )

        return [
            ("palette-catalog", CGSize(width: 640, height: 520), AnyView(
                MoonlightToolPaletteView(model: paletteModel, onDismiss: {})
            )),
            ("palette-editor", CGSize(width: 640, height: 520), AnyView(
                MoonlightToolPaletteView(model: editingModel, onDismiss: {})
            )),
            // The launcher renders with its own chrome: the panel it lives in
            // draws nothing, so the snapshot has to include the glass surface
            // to show what the user actually sees.
            ("launcher-catalog", CGSize(width: 640, height: 520), AnyView(
                MoonlightToolPaletteView(
                    model: launcherModel,
                    appearance: .glassPanel,
                    onDismiss: {}
                )
                .moonlightGlassSurface()
            )),
            ("launcher-editor", CGSize(width: 640, height: 520), AnyView(
                MoonlightToolPaletteView(
                    model: launcherEditingModel,
                    appearance: .glassPanel,
                    onDismiss: {}
                )
                .moonlightGlassSurface()
            )),
            ("launcher-command", CGSize(width: 640, height: 520), AnyView(
                MoonlightToolPaletteView(
                    model: commandModel,
                    appearance: .glassPanel,
                    onDismiss: {}
                )
                .moonlightGlassSurface()
            )),
            ("app-launcher-grid", CGSize(width: 1100, height: 720), AnyView(
                MoonlightLauncherView(model: launcherGridModel)
                    .moonlightGlassSurface()
            )),
            ("app-launcher-search", CGSize(width: 1100, height: 720), AnyView(
                MoonlightLauncherView(model: launcherSearchModel)
                    .moonlightGlassSurface()
            )),
            ("settings-shortcuts", CGSize(width: 560, height: 460), AnyView(
                ShortcutBindingsView(model: shortcutsModel)
            )),
            ("settings-quicklinks", CGSize(width: 560, height: 460), AnyView(
                QuicklinksView(model: quicklinksModel)
            )),
            ("snippet-success", CGSize(width: 420, height: 260), AnyView(
                ExecutionSnippetView(execution: successfulExecution)
            )),
            ("snippet-failure", CGSize(width: 420, height: 220), AnyView(
                ExecutionSnippetView(execution: failedExecution)
            )),
        ]
    }

    private static var successfulExecution: Execution {
        Execution(
            id: UUID(),
            actionID: MoonlightActionID.formatJSON,
            actionTitle: "Format JSON",
            input: #"{"b":2,"a":1}"#,
            summary: "JSON formatted",
            detail: "{\n  \"a\" : 1,\n  \"b\" : 2\n}",
            status: .succeeded,
            createdAt: Date(timeIntervalSinceReferenceDate: 808_200_000),
            output: ActionOutput(
                summary: "JSON formatted",
                detail: "{\n  \"a\" : 1,\n  \"b\" : 2\n}",
                value: .json("{\n  \"a\" : 1,\n  \"b\" : 2\n}")
            )
        )
    }

    private static var failedExecution: Execution {
        Execution(
            id: UUID(),
            actionID: MoonlightActionID.formatJSON,
            actionTitle: "Format JSON",
            input: "{",
            summary: "Action failed",
            detail: "Enter valid JSON.",
            status: .failed,
            createdAt: Date(timeIntervalSinceReferenceDate: 808_200_000),
            failure: ExecutionFailure(code: "invalid-json", message: "Enter valid JSON.")
        )
    }

    private static func render(
        _ view: AnyView,
        named name: String,
        size: CGSize,
        in directory: URL
    ) {
        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = CGRect(origin: .zero, size: size)
            hostingView.appearance = NSAppearance(named: appearanceName)

            // Borderless and painted with the window background: the palette
            // and the settings panes take their background from their host, so
            // a transparent capture would misreport contrast.
            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: appearanceName)
            window.contentView = hostingView
            hostingView.wantsLayer = true
            NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
                hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            window.layoutIfNeeded()
            // Let SwiftUI settle its layout and any onAppear work before the
            // snapshot; a frame captured too early shows placeholders.
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))

            guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            ) else {
                FileHandle.standardError.write(Data("Failed to render \(name)\n".utf8))
                continue
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write(Data("Failed to encode \(name)\n".utf8))
                continue
            }

            let suffix = appearanceName == .aqua ? "light" : "dark"
            let url = directory.appending(path: "\(name)-\(suffix).png")
            do {
                try data.write(to: url)
                print(url.path)
            } catch {
                FileHandle.standardError.write(
                    Data("Failed to write \(name): \(error.localizedDescription)\n".utf8)
                )
            }
        }
    }
}

MoonlightSnapshots.run()
