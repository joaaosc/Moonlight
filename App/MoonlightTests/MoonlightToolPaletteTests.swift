import AppKit
import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Testing
@testable import MoonlightAppUI

@Suite("Moonlight tool palette")
@MainActor
struct MoonlightToolPaletteTests {
    @Test("Preserves a tool selected by a Spotlight entity")
    func preservesPreferredTool() {
        let model = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferredActionID: MoonlightActionID.formatJSON
        )

        #expect(model.preferredActionID == MoonlightActionID.formatJSON)
        #expect(model.filteredDescriptors.contains { $0.id == model.preferredActionID })
    }

    @Test("Executes Base64 using the selected operation parameters")
    func executesBase64WithOperation() async throws {
        let store = InMemoryExecutionStore()
        let model = MoonlightToolPaletteModel(client: .inMemory(store: store))
        let descriptor = ActionDescriptor(
            id: MoonlightActionID.base64Text,
            title: "Base64",
            summary: "Transform text"
        )
        model.selectedID = MoonlightActionID.base64Text
        model.input = "Moonlight"
        // The operation is a declared option, not a field the palette knows.
        let option = try #require(
            model.presentation(for: descriptor).options.first
        )
        model.setOptionValue(Base64TextOperation.encode.rawValue, for: option)

        await model.execute(descriptor)

        #expect(model.errorMessage == nil)
        #expect(model.result?.detail == "TW9vbmxpZ2h0")
        #expect(model.result?.parameters?[TransformBase64Action.operationParameterName] == "encode")
    }

    @Test("Persists color picker execution before routing its presentation")
    func routesColorPicker() async {
        var wasOpened = false
        let probe = PaletteExecutionProbe()
        let client = MoonlightRuntimeClient(
            descriptors: { [] },
            execute: { request in
                await probe.record(actionID: request.actionID)
                return Execution(
                    id: UUID(),
                    actionID: request.actionID,
                    actionTitle: "Open Color Picker",
                    input: request.input,
                    parameters: request.parameters,
                    summary: "Color picker opened",
                    detail: "Moonlight continued in the foreground.",
                    status: .succeeded,
                    createdAt: Date()
                )
            },
            execution: { _ in nil },
            recent: { _ in [] }
        )
        let model = MoonlightToolPaletteModel(
            client: client,
            onOpenColorPicker: { wasOpened = true }
        )

        // The palette only executes the tool it currently presents.
        model.selectedID = MoonlightActionID.openColorPicker
        await model.execute(ActionDescriptor(
            id: MoonlightActionID.openColorPicker,
            title: "Open Color Picker",
            summary: "Choose a color"
        ))

        #expect(wasOpened)
        #expect(await probe.actionID() == MoonlightActionID.openColorPicker)
        #expect(model.result?.status == .succeeded)
    }

    @Test("A result from a closed presentation never controls the current one")
    func discardsResultFromSupersededPresentation() async {
        let gate = ExecutionGate()
        let model = MoonlightToolPaletteModel(client: .gated(gate, detail: "stale"))
        let descriptor = ActionDescriptor(
            id: MoonlightActionID.cleanText,
            title: "Clean Text",
            summary: "Normalize text"
        )
        model.selectedID = descriptor.id

        async let execution: Void = model.execute(descriptor)
        await gate.waitUntilStarted()
        // Closing and reopening the palette while the command runs.
        model.preparePresentation()
        await gate.release()
        await execution

        #expect(model.result == nil)
        #expect(model.errorMessage == nil)
        #expect(!model.isWorking)
    }

    @Test("A result reaching a different selection stays in its own draft")
    func keepsResultWithItsOwnTool() async {
        let gate = ExecutionGate()
        let model = MoonlightToolPaletteModel(client: .gated(gate, detail: "done"))
        let descriptor = ActionDescriptor(
            id: MoonlightActionID.cleanText,
            title: "Clean Text",
            summary: "Normalize text"
        )
        model.selectedID = descriptor.id

        async let execution: Void = model.execute(descriptor)
        await gate.waitUntilStarted()
        model.selectedID = MoonlightActionID.generateUUID
        await gate.release()
        await execution

        #expect(model.result == nil)
        model.selectedID = descriptor.id
        #expect(model.result?.detail == "done")
    }

    @Test("A disappearing menu bar instance keeps a newer dismissal registered")
    func menuBarTokenSurvivesStaleDisappearance() {
        let coordinator = MoonlightPresentationCoordinator()
        let staleToken = coordinator.registerMenuBar(dismiss: {})
        let currentToken = coordinator.registerMenuBar(dismiss: {})

        coordinator.unregisterMenuBar(staleToken)
        #expect(coordinator.isMenuBarRegistered)

        coordinator.unregisterMenuBar(currentToken)
        #expect(!coordinator.isMenuBarRegistered)
    }

    @Test("Isolated palette targets only the history window")
    func isolatedWindowSelection() {
        let historyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        historyWindow.identifier = NSUserInterfaceItemIdentifier("main")
        historyWindow.title = "Moonlight"

        let palette = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        palette.identifier = NSUserInterfaceItemIdentifier(
            MoonlightToolPalettePresenter.panelIdentifier
        )

        let unrelatedWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        unrelatedWindow.title = "Preferences"

        let selectedWindows = MoonlightToolPalettePresenter.shared.mainWindows(
            in: [historyWindow, palette, unrelatedWindow],
            excluding: palette
        )

        #expect(selectedWindows.count == 1)
        #expect(selectedWindows.first === historyWindow)
    }
}

private actor PaletteExecutionProbe {
    private var storedActionID: String?

    func record(actionID: String) {
        storedActionID = actionID
    }

    func actionID() -> String? {
        storedActionID
    }
}

private extension MoonlightRuntimeClient {
    /// A client that reports when execution started and waits to be released,
    /// so a test can change the presentation while a command is in flight.
    static func gated(_ gate: ExecutionGate, detail: String) -> MoonlightRuntimeClient {
        MoonlightRuntimeClient(
            descriptors: { [] },
            execute: { request in
                await gate.signalStartAndWait()
                return Execution(
                    id: UUID(),
                    actionID: request.actionID,
                    actionTitle: request.actionID,
                    input: request.input,
                    parameters: request.parameters,
                    summary: "Completed",
                    detail: detail,
                    status: .succeeded,
                    createdAt: Date()
                )
            },
            execution: { _ in nil },
            recent: { _ in [] }
        )
    }
}

private actor ExecutionGate {
    private var hasStarted = false
    private var isReleased = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func signalStartAndWait() async {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        guard !isReleased else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@Suite("Undoable palette actions")
@MainActor
struct MoonlightUndoTests {
    @Test("Undo restores the favorites that existed before the change")
    func undoRestoresPreviousFavorites() {
        let preferences = UserDefaults(suiteName: "MoonlightUndoTests-\(UUID().uuidString)")!
        let model = MoonlightToolPaletteModel(
            client: .inMemory(store: InMemoryExecutionStore()),
            preferences: preferences
        )
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let json = ActionDescriptor(id: MoonlightActionID.formatJSON, title: "Format JSON", summary: "")
        let uuid = ActionDescriptor(id: MoonlightActionID.generateUUID, title: "Generate UUID", summary: "")

        // With grouping by event disabled, each change is its own group.
        for descriptor in [json, uuid] {
            undoManager.beginUndoGrouping()
            model.toggleFavorite(descriptor, undoManager: undoManager)
            undoManager.endUndoGrouping()
        }
        #expect(model.favoriteIDs == [json.id, uuid.id])

        undoManager.undo()
        #expect(model.favoriteIDs == [json.id])

        undoManager.undo()
        #expect(model.favoriteIDs.isEmpty)

        undoManager.redo()
        #expect(model.favoriteIDs == [json.id])
    }

    @Test("A result with no value cannot be transferred")
    func transferRequiresValue() {
        let empty = Execution(
            id: UUID(),
            actionID: MoonlightActionID.openColorPicker,
            actionTitle: "Open Color Picker",
            input: "",
            summary: "Color picker opened",
            detail: "Moonlight continued in the foreground.",
            status: .succeeded,
            createdAt: Date(),
            output: ActionOutput(
                summary: "Color picker opened",
                detail: "Moonlight continued in the foreground.",
                value: ActionOutputValue.none
            )
        )
        let text = Execution(
            id: UUID(),
            actionID: MoonlightActionID.formatJSON,
            actionTitle: "Format JSON",
            input: "{}",
            summary: "JSON formatted",
            detail: "{}",
            status: .succeeded,
            createdAt: Date(),
            output: ActionOutput(summary: "JSON formatted", detail: "{}", value: .json("{}"))
        )

        #expect(ExecutionResultTransfer(execution: empty) == nil)
        #expect(ExecutionResultTransfer(execution: text)?.suggestedFileName.hasSuffix(".json") == true)
    }
}

@Suite("Loading the shortcuts library")
@MainActor
struct MoonlightShortcutsLoadingTests {
    @Test("The library is requested even when permission is undecided")
    func listsWithoutPreflightGate() async {
        let summaries = [
            ShortcutSummary(externalID: "A", name: "Daily Note"),
            ShortcutSummary(externalID: "B", name: "Resize Window"),
        ]
        // `notDetermined` is what a machine reports while the helper is not
        // running; the request must go out anyway.
        let model = MoonlightShortcutsModel(
            shortcuts: .stub(summaries, status: .notDetermined),
            store: nil,
            cache: ShortcutBindingsCache()
        )

        await model.loadLibrary()

        #expect(model.library.map(\.externalID) == ["A", "B"])
        #expect(model.hasLoadedLibrary)
        #expect(model.errorMessage == nil)
        #expect(model.authorization == .authorized)
    }

    @Test("A refusal is reported as a permission problem")
    func reportsDenial() async {
        let model = MoonlightShortcutsModel(
            shortcuts: .failing(.notAuthorized, status: .denied),
            store: nil,
            cache: ShortcutBindingsCache()
        )

        await model.loadLibrary()

        #expect(model.library.isEmpty)
        #expect(!model.hasLoadedLibrary)
        #expect(model.authorization == .denied)
        #expect(model.errorMessage?.contains("Automation") == true)
    }

    @Test("Any other failure keeps the error the request returned")
    func keepsUnderlyingError() async {
        let model = MoonlightShortcutsModel(
            shortcuts: .failing(.timedOut, status: .notDetermined),
            store: nil,
            cache: ShortcutBindingsCache()
        )

        await model.loadLibrary()

        #expect(model.errorMessage == ShortcutsClientError.timedOut.localizedDescription)
        #expect(model.errorMessage?.contains("did not answer in time") == true)
    }
}

@Suite("Moonlight command line in the palette")
@MainActor
struct MoonlightPaletteCommandLineTests {
    @Test("Plain text is a search, not a command")
    func plainTextIsNotACommand() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.query = "json"

        #expect(model.commandLineState == nil)
    }

    @Test("A well formed command with no implementation is reported as unpublished")
    func unpublishedCommand() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        // Not `/note`: that alias belongs to Capture Note, and a command the
        // catalogue answers to is no longer unpublished.
        model.query = "/nosuchcommand Buy milk"

        #expect(
            model.commandLineState
                == .unpublished(SlashCommand(name: "nosuchcommand", arguments: "Buy milk"))
        )
    }

    @Test("A malformed command is reported as invalid rather than as no results")
    func invalidCommand() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.query = "/no+te"

        guard case .invalid = model.commandLineState else {
            Issue.record("Expected an invalid command, got \(String(describing: model.commandLineState))")
            return
        }
    }

    @Test("Opening the window by name clears a command left behind")
    func windowPresentationResetsTheField() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.preparePresentation(initialQuery: "/note Buy milk")

        // What `presentWindow` asks the model for: a window requested by name
        // must not open on the previous invocation's half-typed search.
        model.preparePresentation(initialQuery: "")

        #expect(model.query.isEmpty)
        #expect(model.commandLineState == nil)
    }

    @Test("A command arrives in the palette with its text intact")
    func seedsTheSearchField() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))

        model.preparePresentation(initialQuery: "/note Buy milk")

        #expect(model.query == "/note Buy milk")
        #expect(!model.isEditing)
    }
}

@Suite("The command prefix is the same everywhere")
@MainActor
struct MoonlightCommandPrefixTests {
    @Test("A tool's own alias typed as a command reaches the tool")
    func aliasTypedAsCommandFindsTheTool() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.query = "/note"

        // The catalogue and the command line share one field, so they must
        // share one namespace: reporting "no /note command" while Capture Note
        // sits in the list under the alias `note` is the bug this covers.
        #expect(model.commandLineState == nil)
        #expect(model.filteredDescriptors.contains { $0.id == MoonlightActionID.captureNote })
    }

    @Test("A name no tool answers to is still reported as unpublished")
    func unknownCommandStaysUnpublished() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.query = "/nosuchcommand"

        #expect(model.commandLineState == .unpublished(SlashCommand(name: "nosuchcommand")))
    }

    @Test("Completion writes the slash the field accepts")
    func completionUsesTheSlash() {
        let model = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        model.query = "js"
        model.selectedID = MoonlightActionID.formatJSON

        #expect(model.completeSelection())
        #expect(model.query == "/json")
    }
}

@Suite("Active app shortcuts")
struct ActiveAppShortcutsTests {
    @Test("Command is implied unless the mask says otherwise")
    func impliedCommand() {
        #expect(ActiveAppShortcutsReader.keyEquivalent(character: "n", modifiers: 0) == "⌘N")
    }

    @Test("Modifiers render in the order macOS writes them")
    func modifierOrder() {
        // Control, Option, Shift, then Command — the order the menu bar uses.
        #expect(
            ActiveAppShortcutsReader.keyEquivalent(character: "a", modifiers: 0x01 | 0x02 | 0x04)
                == "⌃⌥⇧⌘A"
        )
    }

    @Test("Bit 3 drops Command instead of adding a modifier")
    func commandlessShortcut() {
        #expect(ActiveAppShortcutsReader.keyEquivalent(character: "f", modifiers: 0x08) == "F")
        #expect(
            ActiveAppShortcutsReader.keyEquivalent(character: "f", modifiers: 0x08 | 0x01) == "⇧F"
        )
    }
}

@Suite("Menu bar favourites")
@MainActor
struct MoonlightMenuBarModelTests {
    @Test("Favourites carry the tool's alias, not its identifier")
    func favoritesCarryAlias() {
        let palette = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))
        let descriptor = try? #require(
            palette.descriptors.first { $0.id == MoonlightActionID.formatJSON }
        )
        palette.toggleFavorite(try! #require(descriptor))

        let favorites = MoonlightMenuBarModel().favorites(in: palette)

        #expect(favorites.map(\.id) == [MoonlightActionID.formatJSON])
        // `json`, not `format-json`: the alias is what the user types.
        #expect(favorites.first?.alias == "json")
    }

    @Test("Nothing starred means nothing listed")
    func noFavorites() {
        let palette = MoonlightToolPaletteModel(client: .inMemory(store: InMemoryExecutionStore()))

        #expect(MoonlightMenuBarModel().favorites(in: palette).isEmpty)
    }

    @Test("Moonlight in front leaves no app to read")
    func moonlightInFrontHasNoActiveApp() {
        let model = MoonlightMenuBarModel()

        model.capture(frontmostApplication: nil, ownBundleIdentifier: "com.joaocosta.Moonlight")

        #expect(model.activeApp == nil)
        #expect(model.shortcuts.isEmpty)
    }
}
