import Foundation
import MoonlightDomain
import Testing

private func app(_ name: String) -> InstalledApp {
    InstalledApp(
        bundleIdentifier: "com.example.\(name.replacingOccurrences(of: " ", with: ""))",
        url: URL(fileURLWithPath: "/Applications/\(name).app"),
        name: name
    )
}

@Suite("Launcher search")
struct LauncherSearchTests {
    private let search = LauncherSearch()
    private let catalog = [
        app("Activity Monitor"),
        app("Calculator"),
        app("Calendar"),
        app("Café"),
        app("System Settings"),
        app("Xcode"),
    ]

    @Test("An empty query searches for nothing")
    func emptyQueryReturnsNothing() {
        #expect(search.matches(for: "", in: catalog).isEmpty)
        #expect(search.matches(for: "   ", in: catalog).isEmpty)
    }

    @Test("A full name outranks a prefix of it")
    func exactOutranksPrefix() {
        let names = search.apps(for: "calculator", in: catalog).map(\.name)

        #expect(names.first == "Calculator")
    }

    @Test("A prefix matches and ties break alphabetically")
    func prefixIsStable() {
        let names = search.apps(for: "cal", in: catalog).map(\.name)

        #expect(names.prefix(2) == ["Calculator", "Calendar"])
    }

    @Test("A later word can carry the match")
    func wordPrefixMatches() {
        #expect(search.rank(name: "Activity Monitor", for: "mon") == .wordPrefix)
    }

    @Test("Initials reach a two-word name")
    func initialsMatch() {
        let names = search.apps(for: "am", in: catalog).map(\.name)

        #expect(names.contains("Activity Monitor"))
    }

    @Test("Scattered letters still match, but rank last")
    func subsequenceRanksLast() {
        #expect(search.rank(name: "Xcode", for: "xd") == .subsequence)
    }

    @Test("Accents are ignored in both directions")
    func diacriticsAreFolded() {
        let unaccented = search.apps(for: "cafe", in: catalog).map(\.name)
        let accented = search.apps(for: "café", in: catalog).map(\.name)

        #expect(unaccented.contains("Café"))
        #expect(accented.contains("Café"))
    }

    @Test("Case is ignored")
    func caseIsIgnored() {
        #expect(search.rank(name: "Xcode", for: "  XCODE ") == .exact)
    }

    @Test("An unrelated query matches nothing")
    func noMatch() {
        #expect(search.matches(for: "zzzz", in: catalog).isEmpty)
    }

    @Test("Better ranks come first")
    func ranksAreOrdered() {
        let matches = search.matches(for: "ca", in: catalog)

        let ranks = matches.map(\.rank)
        let descending = ranks.sorted(by: >)

        #expect(matches.first?.rank == .prefix)
        #expect(ranks == descending)
    }
}
