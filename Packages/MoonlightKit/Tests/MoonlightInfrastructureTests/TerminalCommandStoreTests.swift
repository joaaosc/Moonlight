import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightInfrastructure

@Suite("Terminal command store")
struct TerminalCommandStoreTests {
    private func makeStore() throws -> (store: TerminalCommandStore, fileURL: URL, directory: URL) {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightTerminalCommandTests")
            .appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "terminal-commands-v1.json")
        return (try TerminalCommandStore(fileURL: fileURL), fileURL, directory)
    }

    private func command(
        alias: String,
        lines: [String] = ["echo hello"],
        title: String = "Greet"
    ) -> TerminalCommand {
        TerminalCommand(title: title, lines: lines, alias: alias)
    }

    @Test("A saved command survives a new store over the same document")
    func persistsAcrossInstances() async throws {
        let (store, fileURL, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stored = command(alias: "greet")

        try await store.add(stored)
        let reopened = try TerminalCommandStore(fileURL: fileURL)
        let commands = try await reopened.commands()

        #expect(commands.count == 1)
        #expect(commands.first?.id == stored.id)
        #expect(commands.first?.lines == ["echo hello"])
    }

    @Test("Two commands cannot share an alias")
    func rejectsDuplicateAlias() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.add(command(alias: "greet"))

        await #expect(throws: TerminalCommandStoreError.duplicateAlias("greet")) {
            try await store.add(command(alias: "greet"))
        }
        #expect(try await store.commands().count == 1)
    }

    @Test("An alias owned by a built-in tool is refused")
    func rejectsReservedAlias() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        // "note" belongs to the built-in Capture Note tool.
        await #expect(throws: TerminalCommandStoreError.reservedAlias("note")) {
            try await store.add(command(alias: "note"))
        }
        #expect(try await store.commands().isEmpty)
    }

    @Test("A command with no runnable line is refused at save time")
    func rejectsBlankScript() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(throws: TerminalCommandStoreError.emptyScript) {
            try await store.add(command(alias: "greet", lines: ["   ", ""]))
        }
        #expect(try await store.commands().isEmpty)
    }

    @Test("Editing a script keeps the command identity")
    func updatesScript() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var stored = command(alias: "greet")
        try await store.add(stored)

        stored.lines = ["echo hello", "uptime"]
        try await store.update(stored)
        let commands = try await store.commands()

        #expect(commands.count == 1)
        #expect(commands.first?.id == stored.id)
        #expect(commands.first?.lines == ["echo hello", "uptime"])
    }

    @Test("Removing a command deletes only the saved script")
    func removesCommandOnly() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = command(alias: "greet")
        let second = command(alias: "status", lines: ["uptime"])
        try await store.add(first)
        try await store.add(second)

        try await store.remove(id: first.id)
        let commands = try await store.commands()

        #expect(commands.count == 1)
        #expect(commands.first?.id == second.id)
    }
}
