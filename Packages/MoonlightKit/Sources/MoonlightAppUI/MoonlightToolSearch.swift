public struct MoonlightToolSearch: Sendable {
    public init() {}

    public func ranked(
        presentations: [MoonlightToolPresentation],
        query: String,
        favoriteIDs: Set<String>
    ) -> [MoonlightToolPresentation] {
        let text = normalized(query)
        let matches = presentations.compactMap { presentation -> (MoonlightToolPresentation, Int)? in
            let score = score(presentation, query: text)
            return score > 0 ? (presentation, score) : nil
        }
        return matches.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            let firstFavorite = favoriteIDs.contains($0.0.id)
            let secondFavorite = favoriteIDs.contains($1.0.id)
            if firstFavorite != secondFavorite { return firstFavorite }
            return $0.0.title < $1.0.title
        }.map(\.0)
    }

    private func normalized(_ query: String) -> String {
        var text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("\\") { text.removeFirst() }
        return text
    }

    private func score(_ presentation: MoonlightToolPresentation, query: String) -> Int {
        guard !query.isEmpty else { return 1 }
        if presentation.alias == query || presentation.title.lowercased() == query { return 4 }
        if presentation.alias.hasPrefix(query) || presentation.title.lowercased().hasPrefix(query) { return 3 }
        let searchable = "\(presentation.title) \(presentation.summary) \(presentation.alias)".lowercased()
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { searchable.contains($0) } ? 2 : 0
    }
}
