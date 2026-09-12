import Testing
@testable import MoonlightDomain

@Suite("Moonlight Spotlight surfaces")
struct MoonlightSurfaceTests {
    @Test("Publishes the tools surface under the omt alias")
    func publishesToolsAlias() throws {
        let surface = try #require(MoonlightSurfaceRegistry.surface(alias: "omt"))

        #expect(surface.id == MoonlightSurfaceID.tools)
        #expect(surface.alias == "omt")
    }

    @Test("Resolves an alias regardless of case and padding")
    func resolvesAliasLoosely() {
        #expect(MoonlightSurfaceRegistry.surface(alias: "  OMT ")?.id == MoonlightSurfaceID.tools)
        #expect(MoonlightSurfaceRegistry.surface(alias: "om") == nil)
        #expect(MoonlightSurfaceRegistry.surface(alias: "") == nil)
    }

    @Test("Every surface carries its alias and the app name as keywords")
    func keywordsIncludeAliasAndAppName() {
        for surface in MoonlightSurfaceRegistry.standard {
            #expect(surface.searchKeywords.contains(surface.alias))
            #expect(surface.searchKeywords.contains("moonlight"))
        }
    }

    @Test("Keywords are normalized and free of duplicates")
    func keywordsAreUnique() {
        let surface = MoonlightSurface(
            id: "test",
            alias: "xy",
            title: "Tools",
            summary: "",
            symbolName: "moon",
            additionalKeywords: ["XY", " tools ", "", "Moonlight"]
        )

        #expect(surface.searchKeywords == ["xy", "moonlight", "tools"])
    }

    @Test("The window surface is no longer published under omw")
    func retiresWindowAlias() {
        #expect(MoonlightSurfaceRegistry.surface(alias: "omw") == nil)
        #expect(MoonlightSurfaceRegistry.surface(id: MoonlightSurfaceID.window) == nil)
    }

    @Test("Aliases are unique across published surfaces")
    func aliasesAreUnique() {
        let aliases = MoonlightSurfaceRegistry.standard.map(\.alias)

        #expect(Set(aliases).count == aliases.count)
    }
}
