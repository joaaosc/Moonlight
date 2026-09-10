import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightInfrastructure

@Suite("Shortcut bindings store")
struct ShortcutBindingsStoreTests {
    private func makeStore() throws -> (store: ShortcutBindingsStore, fileURL: URL, directory: URL) {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightShortcutBindingsTests")
            .appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "shortcut-bindings-v1.json")
        return (try ShortcutBindingsStore(fileURL: fileURL), fileURL, directory)
    }

    private func binding(
        alias: String,
        externalID: String = UUID().uuidString,
        name: String = "Daily Note"
    ) -> ShortcutCommandBinding {
        ShortcutCommandBinding(
            externalID: externalID,
            cachedName: name,
            alias: alias
        )
    }

    @Test("A registered shortcut survives a new store over the same document")
    func persistsAcrossInstances() async throws {
        let (store, fileURL, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stored = binding(alias: "daily-note")

        try await store.add(stored)
        let reopened = try ShortcutBindingsStore(fileURL: fileURL)
        let bindings = try await reopened.bindings()

        #expect(bindings.count == 1)
        #expect(bindings.first?.id == stored.id)
        #expect(bindings.first?.externalID == stored.externalID)
    }

    @Test("Two commands cannot share an alias")
    func rejectsDuplicateAlias() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.add(binding(alias: "daily-note"))

        await #expect(throws: ShortcutBindingsStoreError.duplicateAlias("daily-note")) {
            try await store.add(binding(alias: "daily-note"))
        }
        #expect(try await store.bindings().count == 1)
    }

    @Test("Editing an alias keeps the binding identity")
    func updatesAlias() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var stored = binding(alias: "daily-note")
        try await store.add(stored)

        stored.alias = "note"
        try await store.update(stored)
        let bindings = try await store.bindings()

        #expect(bindings.count == 1)
        #expect(bindings.first?.id == stored.id)
        #expect(bindings.first?.alias == "note")
    }

    @Test("Removing a command deletes only the link")
    func removesBindingOnly() async throws {
        let (store, _, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = binding(alias: "daily-note")
        let second = binding(alias: "weekly-note")
        try await store.add(first)
        try await store.add(second)

        try await store.remove(id: first.id)
        let bindings = try await store.bindings()

        #expect(bindings.map(\.id) == [second.id])
        await #expect(throws: ShortcutBindingsStoreError.bindingNotFound(first.id)) {
            try await store.remove(id: first.id)
        }
    }

    @Test("A document from an unsupported version is refused, not discarded")
    func refusesUnsupportedVersion() async throws {
        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightShortcutBindingsTests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "shortcut-bindings-v1.json")
        try Data(#"{"version":99,"bindings":[]}"#.utf8).write(to: fileURL)

        #expect(throws: ShortcutBindingsStoreError.unsupportedVersion(99)) {
            _ = try ShortcutBindingsStore(fileURL: fileURL)
        }
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
