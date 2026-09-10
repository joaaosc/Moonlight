import Foundation
import MoonlightDomain

public enum FileNoteStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument
    case unsupportedVersion(Int)
    case sharedContainerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The saved notes are not a valid Moonlight document."
        case let .unsupportedVersion(version):
            "Saved notes version \(version) is not supported."
        case let .sharedContainerUnavailable(identifier):
            "The shared container \(identifier) is unavailable."
        }
    }
}

/// Keeps notes in their own document inside the App Group.
///
/// A separate file from the execution history, so the two lifecycles never
/// touch: clearing what ran cannot remove what the user wrote.
public actor FileNoteStore: NoteStore {
    private struct Document: Codable {
        let version: Int
        let notes: [MoonlightNote]
    }

    private static let currentVersion = 1

    public let fileURL: URL
    private let retentionLimit: Int

    public init(fileURL: URL? = nil, retentionLimit: Int = 1_000) throws {
        self.fileURL = try fileURL ?? Self.defaultFileURL()
        self.retentionLimit = max(1, retentionLimit)
        try Self.ensureDocumentExists(at: self.fileURL)
        _ = try Self.readNotes(at: self.fileURL)
    }

    public func save(_ note: MoonlightNote) throws {
        try mutate { notes in
            notes.removeAll { $0.id == note.id }
            notes.insert(note, at: 0)
            if notes.count > retentionLimit {
                notes.removeLast(notes.count - retentionLimit)
            }
        }
    }

    public func notes(limit: Int) throws -> [MoonlightNote] {
        guard limit > 0 else { return [] }
        return try Self.readNotes(at: fileURL)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func delete(id: UUID) throws {
        try mutate { notes in
            notes.removeAll { $0.id == id }
        }
    }

    /// Adapts the store to the recorder a command uses.
    public nonisolated func recorder() -> NoteRecorder {
        NoteRecorder(record: { [self] text, executionID in
            try await save(
                MoonlightNote(text: text, originExecutionID: executionID)
            )
        })
    }

    private func mutate(_ body: (inout [MoonlightNote]) throws -> Void) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var operationResult: Result<Void, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                var notes = try Self.readNotesWithoutCoordination(at: coordinatedURL)
                try body(&notes)
                try Self.writeNotesWithoutCoordination(notes, to: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileWriteUnknown)
        }
        try operationResult.get()
        MoonlightStorage.postNotesDidChange()
    }

    public static func defaultFileURL(
        groupContainerResolver: (String) -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    ) throws -> URL {
        guard let containerURL = groupContainerResolver(MoonlightStorage.appGroupIdentifier) else {
            throw FileNoteStoreError.sharedContainerUnavailable(
                MoonlightStorage.appGroupIdentifier
            )
        }
        return containerURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Moonlight")
            .appending(path: "notes-v1.json")
    }

    private static func readNotes(at fileURL: URL) throws -> [MoonlightNote] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        var coordinationError: NSError?
        var operationResult: Result<[MoonlightNote], Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try readNotesWithoutCoordination(at: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileReadUnknown)
        }
        return try operationResult.get()
    }

    private static func ensureDocumentExists(at fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try writeNotesWithoutCoordination([], to: fileURL)
    }

    private static func readNotesWithoutCoordination(at fileURL: URL) throws -> [MoonlightNote] {
        guard let data = FileManager.default.contents(atPath: fileURL.path), !data.isEmpty else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw FileNoteStoreError.invalidDocument
        }
        guard document.version == currentVersion else {
            throw FileNoteStoreError.unsupportedVersion(document.version)
        }
        return document.notes
    }

    private static func writeNotesWithoutCoordination(
        _ notes: [MoonlightNote],
        to fileURL: URL
    ) throws {
        let document = Document(version: currentVersion, notes: notes)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }
}
