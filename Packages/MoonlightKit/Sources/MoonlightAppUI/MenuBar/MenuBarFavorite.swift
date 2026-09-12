import Foundation

/// One favourite tool as the menu bar shows it.
///
/// Carries its own alias rather than deriving one from the identifier: a
/// tool's command name is its presentation, and a personal command's alias is
/// nothing like its ID.
public struct MenuBarFavorite: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let alias: String

    public init(id: String, title: String, summary: String, alias: String) {
        self.id = id
        self.title = title
        self.summary = summary
        self.alias = alias
    }
}
