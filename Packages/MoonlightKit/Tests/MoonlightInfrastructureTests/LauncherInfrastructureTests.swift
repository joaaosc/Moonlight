import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Testing

/// Builds a directory tree of minimal application bundles, so the catalogue is
/// exercised against a known set instead of against whatever this machine has
/// installed.
private struct FakeApplicationsDirectory {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "moonlight-launcher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult
    func addApp(
        named name: String,
        identifier: String?,
        inSubdirectory subdirectory: String? = nil
    ) throws -> URL {
        var directory = root
        if let subdirectory {
            directory = directory.appending(path: subdirectory, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let bundle = directory.appending(path: "\(name).app", directoryHint: .isDirectory)
        let contents = bundle.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        var plist: [String: Any] = ["CFBundlePackageType": "APPL"]
        if let identifier { plist["CFBundleIdentifier"] = identifier }
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appending(path: "Info.plist"))
        return bundle
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Suite("Directory app catalogue")
struct DirectoryAppCatalogTests {
    @Test("Finds the bundles in a directory")
    func findsApps() async throws {
        let directory = try FakeApplicationsDirectory()
        defer { directory.remove() }
        try directory.addApp(named: "Alpha", identifier: "com.example.alpha")
        try directory.addApp(named: "Beta", identifier: "com.example.beta")

        let catalog = DirectoryAppCatalog(directories: [directory.root])
        let apps = try await catalog.apps()

        let identifiers = apps.map(\.bundleIdentifier).sorted()
        #expect(identifiers == ["com.example.alpha", "com.example.beta"])
    }

    @Test("Descends one level, which is what reaches Utilities")
    func findsNestedApps() async throws {
        let directory = try FakeApplicationsDirectory()
        defer { directory.remove() }
        try directory.addApp(named: "Nested", identifier: "com.example.nested", inSubdirectory: "Utilities")

        let catalog = DirectoryAppCatalog(directories: [directory.root])
        let apps = try await catalog.apps()

        #expect(apps.map(\.bundleIdentifier) == ["com.example.nested"])
    }

    @Test("Stops at the configured depth")
    func respectsDepth() async throws {
        let directory = try FakeApplicationsDirectory()
        defer { directory.remove() }
        try directory.addApp(named: "Deep", identifier: "com.example.deep", inSubdirectory: "One/Two")

        let catalog = DirectoryAppCatalog(directories: [directory.root], maximumDepth: 2)
        let apps = try await catalog.apps()

        #expect(apps.isEmpty)
    }

    @Test("A bundle with no identifier is skipped")
    func skipsBundlesWithoutIdentifier() async throws {
        let directory = try FakeApplicationsDirectory()
        defer { directory.remove() }
        try directory.addApp(named: "Anonymous", identifier: nil)
        try directory.addApp(named: "Named", identifier: "com.example.named")

        let catalog = DirectoryAppCatalog(directories: [directory.root])
        let apps = try await catalog.apps()

        #expect(apps.map(\.bundleIdentifier) == ["com.example.named"])
    }

    @Test("The same identifier in two places is reported once")
    func deduplicates() async throws {
        let first = try FakeApplicationsDirectory()
        let second = try FakeApplicationsDirectory()
        defer { first.remove(); second.remove() }
        try first.addApp(named: "Duplicate", identifier: "com.example.duplicate")
        try second.addApp(named: "Duplicate", identifier: "com.example.duplicate")

        let catalog = DirectoryAppCatalog(directories: [first.root, second.root])
        let apps = try await catalog.apps()

        // Symlinks are resolved on both sides: the temporary directory is
        // reached through /var, and directory enumeration answers with the
        // /private/var it actually points at.
        let winner = apps.first?.url.resolvingSymlinksInPath().path
        let expected = first.root.resolvingSymlinksInPath().path

        #expect(apps.count == 1)
        #expect(winner?.hasPrefix(expected) == true)
    }

    @Test("A directory that does not exist is not an error")
    func missingDirectoryIsIgnored() async throws {
        let catalog = DirectoryAppCatalog(
            directories: [URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")]
        )

        let apps = try await catalog.apps()

        #expect(apps.isEmpty)
    }
}

@Suite("Launcher layout store")
struct LauncherLayoutStoreTests {
    private func makeStore() throws -> (LauncherLayoutStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "moonlight-layout-\(UUID().uuidString)")
            .appending(path: "launcher-layout-v1.json")
        return (try LauncherLayoutStore(fileURL: url), url)
    }

    @Test("An arrangement survives being saved and read back")
    func roundTrip() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var layout = LauncherLayout(
            grid: LauncherGrid(columns: 3, rows: 2),
            pages: [[.app("com.example.alpha")]],
            hiddenAppIdentifiers: ["com.example.hidden"]
        )
        layout.normalize()

        try await store.save(layout)
        let loaded = await store.layout()

        #expect(loaded == layout)
    }

    @Test("Nothing saved yet reads as an empty arrangement")
    func missingDocumentIsEmpty() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let loaded = await store.layout()

        #expect(loaded == .empty)
    }

    @Test("A damaged document starts over rather than refusing to open")
    func damagedDocumentIsEmpty() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: url)

        let loaded = await store.layout()

        #expect(loaded == .empty)
    }

    @Test("The strict read reports what the forgiving one hides")
    func strictReadThrows() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: url)

        await #expect(throws: LauncherLayoutStoreError.invalidDocument) {
            try await store.strictLayout()
        }
    }

    @Test("A future document version is refused instead of misread")
    func futureVersionIsRefused() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let document = #"{"version":99,"layout":{"grid":{"columns":7,"rows":5},"pages":[],"hiddenAppIdentifiers":[]}}"#
        try Data(document.utf8).write(to: url)

        await #expect(throws: LauncherLayoutStoreError.unsupportedVersion(99)) {
            try await store.strictLayout()
        }
    }
}
