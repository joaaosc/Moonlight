import Foundation

/// A note the user chose to keep.
///
/// Durable on purpose and separate from executions: the history is a log of
/// what ran and can be cleared, while a note is content the user wrote and
/// expects to find later.
public struct MoonlightNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var updatedAt: Date
    /// The execution that captured it, when it came from a command. Kept as a
    /// reference only: deleting history never deletes the note.
    public let originExecutionID: UUID?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        originExecutionID: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.originExecutionID = originExecutionID
    }

    /// The first line, for lists and previews.
    public var title: String {
        text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

/// Stores notes durably. Separate from `ExecutionStore` so that clearing one
/// cannot clear the other.
public protocol NoteStore: Sendable {
    func save(_ note: MoonlightNote) async throws
    func notes(limit: Int) async throws -> [MoonlightNote]
    func delete(id: UUID) async throws
}

/// Records a note as a side effect of a command.
public struct NoteRecorder: Sendable {
    public var record: @Sendable (_ text: String, _ executionID: UUID?) async throws -> Void

    public init(
        record: @escaping @Sendable (_ text: String, _ executionID: UUID?) async throws -> Void
    ) {
        self.record = record
    }

    /// Records nothing. Used where a durable store is not composed, so a
    /// command still runs instead of failing.
    public static let none = NoteRecorder(record: { _, _ in })
}

