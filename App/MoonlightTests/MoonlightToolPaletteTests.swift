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
    func executesBase64WithOperation() async {
        let store = InMemoryExecutionStore()
        let model = MoonlightToolPaletteModel(client: .inMemory(store: store))
        let descriptor = ActionDescriptor(
            id: MoonlightActionID.base64Text,
            title: "Base64",
            summary: "Transform text"
        )
        model.input = "Moonlight"
        model.base64Operation = .encode

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

        await model.execute(ActionDescriptor(
            id: MoonlightActionID.openColorPicker,
            title: "Open Color Picker",
            summary: "Choose a color"
        ))

        #expect(wasOpened)
        #expect(await probe.actionID() == MoonlightActionID.openColorPicker)
        #expect(model.result?.status == .succeeded)
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
