import Foundation

/// How much history and how many notes Moonlight keeps.
///
/// Retention is a user decision with a real consequence — records past the
/// limit are dropped on the next write — so the limits are explicit values
/// read at composition time rather than constants buried in a store.
public struct MoonlightRetention: Sendable, Equatable {
    public static let executionLimitKey = "executionRetentionLimit"
    public static let noteLimitKey = "noteRetentionLimit"

    public static let defaultExecutionLimit = 500
    public static let defaultNoteLimit = 1_000
    /// Below this, an ordinary session would already be discarding results.
    public static let minimumLimit = 50
    public static let maximumLimit = 10_000

    public let executionLimit: Int
    public let noteLimit: Int

    public init(
        executionLimit: Int = defaultExecutionLimit,
        noteLimit: Int = defaultNoteLimit
    ) {
        self.executionLimit = Self.clamp(executionLimit)
        self.noteLimit = Self.clamp(noteLimit)
    }

    /// Reads the stored limits, falling back to the defaults. An out-of-range
    /// value is clamped instead of rejected, so a bad preference cannot leave
    /// the app unable to compose.
    public init(preferences: UserDefaults) {
        let storedExecutions = preferences.object(forKey: Self.executionLimitKey) as? Int
        let storedNotes = preferences.object(forKey: Self.noteLimitKey) as? Int
        self.init(
            executionLimit: storedExecutions ?? Self.defaultExecutionLimit,
            noteLimit: storedNotes ?? Self.defaultNoteLimit
        )
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, minimumLimit), maximumLimit)
    }
}
