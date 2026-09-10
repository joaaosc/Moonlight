import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightInfrastructure

@Suite("Retention limits")
struct MoonlightRetentionTests {
    @Test("An absent preference keeps the defaults")
    func usesDefaults() {
        let preferences = UserDefaults(suiteName: "MoonlightRetention-\(UUID().uuidString)")!

        let retention = MoonlightRetention(preferences: preferences)

        #expect(retention.executionLimit == MoonlightRetention.defaultExecutionLimit)
        #expect(retention.noteLimit == MoonlightRetention.defaultNoteLimit)
    }

    @Test("An out-of-range preference is clamped, never rejected")
    func clampsStoredLimits() {
        let preferences = UserDefaults(suiteName: "MoonlightRetention-\(UUID().uuidString)")!
        preferences.set(1, forKey: MoonlightRetention.executionLimitKey)
        preferences.set(1_000_000, forKey: MoonlightRetention.noteLimitKey)

        let retention = MoonlightRetention(preferences: preferences)

        #expect(retention.executionLimit == MoonlightRetention.minimumLimit)
        #expect(retention.noteLimit == MoonlightRetention.maximumLimit)
    }

    @Test("The store keeps at most the configured number of notes")
    func appliesNoteLimit() async throws {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightRetentionTests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileNoteStore(
            fileURL: directory.appending(path: "notes-v1.json"),
            retentionLimit: 2
        )

        for index in 1...4 {
            try await store.save(MoonlightNote(text: "Note \(index)"))
        }

        let notes = try await store.notes(limit: 10)
        #expect(notes.count == 2)
        #expect(notes.map(\.text).contains("Note 4"))
    }
}

@Suite("Upgrade preserves stored data")
struct MoonlightUpgradeTests {
    /// Reopening every document with a fresh store is what an app upgrade does
    /// to the data it finds. Identifiers and content must survive it.
    @Test("Reopening every document preserves identifiers and content")
    func preservesDataAcrossReopen() async throws {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightUpgradeTests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executionsURL = directory.appending(path: "executions-v1.json")
        let bindingsURL = directory.appending(path: "shortcut-bindings-v1.json")
        let notesURL = directory.appending(path: "notes-v1.json")
        let quicklinksURL = directory.appending(path: "quicklinks-v1.json")

        let execution = Execution(
            id: UUID(),
            actionID: MoonlightActionID.cleanText,
            actionTitle: "Clean Text",
            input: "Moonlight",
            summary: "Text cleaned",
            detail: "Moonlight",
            status: .succeeded,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            output: ActionOutput(
                summary: "Text cleaned",
                detail: "Moonlight",
                value: .text("Moonlight")
            )
        )
        let binding = ShortcutCommandBinding(
            externalID: "external-1",
            cachedName: "Daily Note",
            alias: "daily-note",
            isSpotlightExposed: true
        )
        let note = MoonlightNote(text: "Buy milk")
        let quicklink = QuicklinkCommand(
            title: "Search",
            urlTemplate: "https://example.com/s?q={query}",
            alias: "search"
        )

        try await FileExecutionStore(fileURL: executionsURL).upsert(execution)
        try await ShortcutBindingsStore(fileURL: bindingsURL).add(binding)
        try await FileNoteStore(fileURL: notesURL).save(note)
        try await QuicklinkStore(fileURL: quicklinksURL).add(quicklink)

        // A new process opens the same documents.
        let reopenedExecutions = try await FileExecutionStore(fileURL: executionsURL).recent(limit: 10)
        let reopenedBindings = try await ShortcutBindingsStore(fileURL: bindingsURL).bindings()
        let reopenedNotes = try await FileNoteStore(fileURL: notesURL).notes(limit: 10)
        let reopenedQuicklinks = try await QuicklinkStore(fileURL: quicklinksURL).quicklinks()

        #expect(reopenedExecutions.first?.id == execution.id)
        #expect(reopenedExecutions.first?.resolvedOutput.value == .text("Moonlight"))
        #expect(reopenedBindings.first?.id == binding.id)
        #expect(reopenedBindings.first?.isSpotlightExposed == true)
        #expect(reopenedBindings.first?.commandID == binding.commandID)
        #expect(reopenedNotes.first?.id == note.id)
        #expect(reopenedQuicklinks.first?.id == quicklink.id)
        #expect(reopenedQuicklinks.first?.commandID == quicklink.commandID)
    }
}

@Suite("Installation location")
struct MoonlightInstallationTests {
    @Test("Only a copy inside the canonical directory counts as installed")
    func recognizesCanonicalLocation() {
        let installed = MoonlightDiagnostics.Installation(
            bundlePath: "/Applications/Moonlight.app",
            version: "0.1.0",
            build: "23"
        )
        let derived = MoonlightDiagnostics.Installation(
            bundlePath: "/Users/someone/Library/Developer/Xcode/DerivedData/Moonlight.app",
            version: "0.1.0",
            build: "23"
        )
        let lookalike = MoonlightDiagnostics.Installation(
            bundlePath: "/Users/someone/Applications-old/Moonlight.app",
            version: "0.1.0",
            build: "23"
        )

        #expect(installed.isCanonical)
        #expect(!derived.isCanonical)
        #expect(!lookalike.isCanonical)
    }
}
