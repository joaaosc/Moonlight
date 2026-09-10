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
