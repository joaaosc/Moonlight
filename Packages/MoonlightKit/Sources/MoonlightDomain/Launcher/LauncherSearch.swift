import Foundation

/// Ranks installed apps against what the user typed.
///
/// Searching reaches apps inside folders too: a folder is an arrangement
/// choice, and having to remember which one an app was filed under would make
/// search worse than the grid it is meant to shortcut.
public struct LauncherSearch: Sendable {
    /// How well one app answered the query. Ordering is by rank first, then by
    /// name, so the same query always produces the same list.
    public enum Rank: Int, Sendable, Comparable {
        case subsequence = 1
        case initials = 2
        case wordPrefix = 3
        case prefix = 4
        case exact = 5

        public static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public struct Match: Sendable, Equatable, Identifiable {
        public let app: InstalledApp
        public let rank: Rank

        public var id: String { app.id }

        public init(app: InstalledApp, rank: Rank) {
            self.app = app
            self.rank = rank
        }
    }

    public init() {}

    /// Returns the apps that answer `query`, best first.
    ///
    /// An empty query returns nothing rather than everything: with no text
    /// typed there is no search, and the caller shows the arrangement instead.
    public func matches(for query: String, in catalog: [InstalledApp]) -> [Match] {
        let needle = Self.fold(query)
        guard !needle.isEmpty else { return [] }

        return catalog
            .compactMap { app in
                rank(app.name, against: needle).map { Match(app: app, rank: $0) }
            }
            .sorted { first, second in
                if first.rank != second.rank { return first.rank > second.rank }
                return first.app.name.localizedCaseInsensitiveCompare(second.app.name)
                    == .orderedAscending
            }
    }

    public func apps(for query: String, in catalog: [InstalledApp]) -> [InstalledApp] {
        matches(for: query, in: catalog).map(\.app)
    }

    /// How well one name answers a query, without running the whole
    /// catalogue. The query is folded here, so callers never have to know that
    /// matching happens on a normalized form.
    public func rank(name: String, for query: String) -> Rank? {
        let needle = Self.fold(query)
        guard !needle.isEmpty else { return nil }
        return rank(name, against: needle)
    }

    private func rank(_ name: String, against needle: String) -> Rank? {
        let haystack = Self.fold(name)
        guard !haystack.isEmpty else { return nil }

        if haystack == needle { return .exact }
        if haystack.hasPrefix(needle) { return .prefix }

        let words = haystack.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
        if words.dropFirst().contains(where: { $0.hasPrefix(needle) }) { return .wordPrefix }

        // "am" for Activity Monitor. Only worth trying when the query is short:
        // a long string of initials is not something anyone types.
        if needle.count >= 2, needle.count <= words.count {
            let initials = String(words.compactMap(\.first))
            if initials.hasPrefix(needle) { return .initials }
        }

        if isSubsequence(needle, of: haystack) { return .subsequence }
        return nil
    }

    /// Every character of `needle`, in order, somewhere in `haystack`.
    private func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = Substring(haystack)
        for character in needle {
            guard let index = remaining.firstIndex(of: character) else { return false }
            remaining = remaining[remaining.index(after: index)...]
        }
        return true
    }

    /// Lowercased and stripped of diacritics, so "cafe" finds "Café" and the
    /// ranking does not depend on how the user's keyboard is set up.
    static func fold(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
