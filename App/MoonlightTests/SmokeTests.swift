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

@Suite("Moonlight Control Panel and Intent Catalog")
@MainActor
struct MoonlightControlPanelTests {
    @Test("Intent catalog contains core intents with symbols and gradients")
    func catalogContent() {
        let all = MoonlightIntentCatalog.allIntents
        #expect(!all.isEmpty)
        #expect(all.contains { $0.id == MoonlightActionID.captureNote })
        #expect(all.contains { $0.id == MoonlightActionID.cleanText })
        #expect(all.contains { $0.id == MoonlightActionID.formatJSON })
        #expect(all.contains { $0.id == MoonlightActionID.generateUUID })
        #expect(all.contains { $0.id == MoonlightActionID.base64Text })
        #expect(all.contains { $0.id == MoonlightActionID.hashText })

        for item in all {
            #expect(!item.title.isEmpty)
            #expect(!item.symbolName.isEmpty)
            #expect(!item.gradientColors.isEmpty)
        }
    }

    @Test("Categories partition the catalog cleanly")
    func categoryFiltering() {
        let coreItems = MoonlightIntentCatalog.items(for: .core)
        let transformItems = MoonlightIntentCatalog.items(for: .transforms)
        let systemItems = MoonlightIntentCatalog.items(for: .system)

        #expect(!coreItems.isEmpty)
        #expect(!transformItems.isEmpty)
        #expect(!systemItems.isEmpty)
        #expect(coreItems.count + transformItems.count + systemItems.count == MoonlightIntentCatalog.allIntents.count)
    }

    @Test("Featured intent is capture note")
    func featuredIntent() {
        let featured = MoonlightIntentCatalog.featuredItem
        #expect(featured.id == MoonlightActionID.captureNote)
        #expect(featured.isFeatured)
    }

    @Test("Model generic execute executes and records in history")
    func modelExecute() async {
        let model = MoonlightModel(client: .inMemory())
        let execution = await model.execute(
            actionID: MoonlightActionID.generateUUID,
            input: ""
        )

        #expect(execution != nil)
        #expect(execution?.status == .succeeded)
        #expect(model.executions.count == 1)
        #expect(model.errorMessage == nil)
    }
}

private enum ModelFixtureError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? { "Fixture runtime is unavailable." }
}
