import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Testing

@Suite("File execution store")
struct FileExecutionStoreTests {
    @Test("Round-trips executions and updates an existing identifier")
    func roundTripAndUpsert() async throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        let identifier = UUID()
        let original = makeExecution(id: identifier, detail: "original", seconds: 1)
        let replacement = makeExecution(id: identifier, detail: "replacement", seconds: 2)

        let store = try FileExecutionStore(fileURL: fixture.fileURL)
        try await store.upsert(original)
        try await store.upsert(replacement)

        let reopened = try FileExecutionStore(fileURL: fixture.fileURL)
        #expect(await reopened.execution(id: identifier) == replacement)
        #expect(await reopened.recent(limit: 10) == [replacement])
    }

    @Test("Rejects invalid JSON without replacing the file")
    func rejectsInvalidJSON() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        let original = Data("not-json".utf8)
        try original.write(to: fixture.fileURL)

        #expect(throws: FileExecutionStoreError.invalidDocument) {
            _ = try FileExecutionStore(fileURL: fixture.fileURL)
        }
        #expect(try Data(contentsOf: fixture.fileURL) == original)
    }

    @Test("Rejects an unsupported document version")
    func rejectsUnsupportedVersion() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        try encode(FixtureDocument(version: 2, executions: []), to: fixture.fileURL)

        #expect(throws: FileExecutionStoreError.unsupportedVersion(2)) {
            _ = try FileExecutionStore(fileURL: fixture.fileURL)
        }
    }

    @Test("Rejects duplicate execution identifiers")
    func rejectsDuplicateIdentifiers() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        let identifier = UUID()
        try encode(
            FixtureDocument(
                version: 1,
                executions: [
                    makeExecution(id: identifier, detail: "first", seconds: 1),
                    makeExecution(id: identifier, detail: "second", seconds: 2),
                ]
            ),
            to: fixture.fileURL
        )

        #expect(throws: FileExecutionStoreError.duplicateExecutionID(identifier)) {
            _ = try FileExecutionStore(fileURL: fixture.fileURL)
        }
    }

    @Test("Retains only the newest configured number of executions")
    func enforcesRetentionLimit() async throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        let store = try FileExecutionStore(fileURL: fixture.fileURL, retentionLimit: 3)

        for seconds in 1...4 {
            try await store.upsert(
                makeExecution(id: UUID(), detail: "\(seconds)", seconds: seconds)
            )
        }

        let recent = await store.recent(limit: 10)
        #expect(recent.count == 3)
        #expect(recent.map(\.detail) == ["4", "3", "2"])
    }

    @Test("Preserves insertion order for equal timestamps after reopening")
    func preservesEqualTimestampOrder() async throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.remove() }
        let store = try FileExecutionStore(fileURL: fixture.fileURL, retentionLimit: 3)

        for detail in ["first", "second", "third"] {
            try await store.upsert(
                makeExecution(id: UUID(), detail: detail, seconds: 1)
            )
        }

        let reopened = try FileExecutionStore(fileURL: fixture.fileURL, retentionLimit: 3)
        try await reopened.upsert(
            makeExecution(id: UUID(), detail: "fourth", seconds: 1)
        )

        #expect(await reopened.recent(limit: 10).map(\.detail) == [
            "fourth",
            "third",
            "second",
        ])
    }

    @Test("Uses an isolated temporary store for a valid App Intents test session")
    func isolatedAppIntentsTestStore() {
        let sessionID = UUID()
        let temporaryDirectory = URL(fileURLWithPath: "/tmp/moonlight-tests", isDirectory: true)

        let fileURL = FileExecutionStore.defaultFileURL(
            environment: [
                "MOONLIGHT_APP_INTENTS_TEST_SESSION_ID": sessionID.uuidString,
            ],
            temporaryDirectory: temporaryDirectory
        )

        #expect(fileURL == temporaryDirectory
            .appending(path: "MoonlightAppIntentsTests")
            .appending(path: sessionID.uuidString)
            .appending(path: "executions-v1.json"))
    }

    private func makeExecution(
        id: UUID,
        detail: String,
        seconds: Int
    ) -> Execution {
        Execution(
            id: id,
            actionID: MoonlightActionID.captureNote,
            actionTitle: "Capture Note",
            input: detail,
            summary: "Note captured",
            detail: detail,
            status: .succeeded,
            createdAt: Date(timeIntervalSince1970: TimeInterval(seconds))
        )
    }

    private func encode(_ document: FixtureDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(document).write(to: url)
    }
}

private struct FixtureDocument: Encodable {
    let version: Int
    let executions: [Execution]
}

private struct TemporaryStoreFixture {
    let directoryURL: URL
    let fileURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoonlightTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("executions.json")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
