import AppKit
import Foundation
@testable import MoonlightAppUI
import MoonlightDomain
import MoonlightInfrastructure
import Testing

@Suite("Moonlight app model")
@MainActor
struct MoonlightModelTests {
    @Test("Successful capture clears input and refreshes history")
    func successfulCapture() async {
        let model = MoonlightModel(client: .inMemory())
        model.text = "App capture"

        let execution = await model.capture()

        #expect(model.text.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(model.executions.count == 1)
        #expect(model.executions[0].detail == "App capture")
        #expect(execution?.id == model.executions[0].id)
    }

    @Test("Runtime failure preserves user input and exposes the error")
    func failedCapture() async {
        let model = MoonlightModel(client: .init(
            descriptors: { [] },
            execute: { _ in throw ModelFixtureError.unavailable },
            execution: { _ in nil },
            recent: { _ in [] }
        ))
        model.text = "Keep this"

        await model.capture()

        #expect(model.text == "Keep this")
        #expect(model.errorMessage == ModelFixtureError.unavailable.localizedDescription)
    }

    @Test("Input validation controls capture availability")
    func inputValidation() {
        let model = MoonlightModel(client: .inMemory())

        model.text = "  \n "
        #expect(!model.canCapture)
        #expect(model.inputValidationMessage == nil)

        model.text = "Valid note"
        #expect(model.canCapture)
        #expect(model.inputCharacterCount == 10)

        model.text = String(
            repeating: "a",
            count: CaptureNoteAction.maximumCharacterCount + 1
        )
        #expect(!model.canCapture)
        #expect(model.inputValidationMessage != nil)
    }

    @Test("History preview collapses visual whitespace")
    func historyPreview() {
        let original = "🔎\n  emoji\tagain"

        #expect(ExecutionTextFormatter.preview(original) == "🔎 emoji again")
        #expect(original.contains("\n"))
    }

    @Test("Intent-driven color panel targets only the history window")
    func isolatedColorPanelSelection() {
        let historyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        historyWindow.identifier = NSUserInterfaceItemIdentifier("main")
        historyWindow.title = "Moonlight"

        let colorPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        colorPanel.identifier = NSUserInterfaceItemIdentifier(
            MoonlightColorPanelPresenter.panelIdentifier
        )
        let unrelatedWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        unrelatedWindow.title = "Preferences"

        let selectedWindows = MoonlightColorPanelPresenter.shared.mainWindows(
            in: [historyWindow, colorPanel, unrelatedWindow],
            excluding: colorPanel
        )

        #expect(selectedWindows.count == 1)
        #expect(selectedWindows.first === historyWindow)
    }
}

private enum ModelFixtureError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? { "Fixture runtime is unavailable." }
}
