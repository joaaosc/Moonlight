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
