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
