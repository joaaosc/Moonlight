import Foundation
import Observation

/// What the notes section should show after a request from outside the app.
///
/// Carries a search text and an optional note to select, so a request coming
/// from Spotlight, Shortcuts or visual search lands on real content instead of
/// reopening the window in whatever state it was left.
@MainActor
@Observable
public final class MoonlightNotesFocus {
    public private(set) var searchText = ""
    public private(set) var noteID: UUID?
    /// Changes on every request, so a repeated request is still observed.
    public private(set) var revision = UUID()

    public init() {}

    public func request(searchText: String = "", noteID: UUID? = nil) {
        self.searchText = searchText
        self.noteID = noteID
        revision = UUID()
    }
}
