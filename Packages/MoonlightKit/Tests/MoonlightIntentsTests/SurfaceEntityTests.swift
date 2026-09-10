import AppIntents
import CoreSpotlight
import MoonlightDomain
import MoonlightIntents
import Testing

@Suite("Moonlight Spotlight surfaces")
struct MoonlightSurfaceEntityTests {
    @Test("Surfaces are opened by a discoverable main-process route")
    func openIntentContract() {
        requireOpenIntent(OpenMoonlightSurfaceIntent.self)

        #expect(OpenMoonlightSurfaceIntent.isDiscoverable)
        #expect(OpenMoonlightSurfaceIntent.allowedExecutionTargets.contains(.main))
        // The palette lives in the app process; an extension cannot present it.
        #expect(!OpenMoonlightSurfaceIntent.allowedExecutionTargets.contains(.appIntentsExtension))
    }

    @Test("Every published surface reaches the index with its alias")
    func indexedAliases() {
        let entities = MoonlightSurfaceEntityQuery.allEntities

        #expect(entities.map(\.id) == MoonlightSurfaceRegistry.standard.map(\.id))
        for entity in entities {
            #expect(entity.attributeSet.keywords?.contains(entity.alias) == true)
            #expect(entity.attributeSet.alternateNames?.contains(entity.alias) == true)
        }
    }

    @Test("Typing the alias resolves the tools surface")
    func aliasQuery() async throws {
        let query = MoonlightSurfaceEntityQuery()

        #expect(try await query.entities(matching: "omt").map(\.id) == [MoonlightSurfaceID.tools])
        #expect(try await query.entities(matching: "OMT").map(\.id) == [MoonlightSurfaceID.tools])
    }

    @Test("Typing the alias resolves the window surface")
    func windowAliasQuery() async throws {
        let query = MoonlightSurfaceEntityQuery()

        #expect(try await query.entities(matching: "omw").map(\.id) == [MoonlightSurfaceID.window])
    }

    @Test("A shared prefix keeps both surfaces available")
    func sharedPrefixQuery() async throws {
        let query = MoonlightSurfaceEntityQuery()
        let ids = try await query.entities(matching: "om").map(\.id)

        #expect(Set(ids) == Set([MoonlightSurfaceID.tools, MoonlightSurfaceID.window]))
    }

    @Test("Focus-forcing route is reachable from the foreground client")
    @MainActor
    func windowRoute() {
        let probe = WindowProbe()
        let client = MoonlightForegroundClient(
            presentColorPicker: {},
            presentWindow: { probe.count += 1 }
        )

        client.presentWindow()

        #expect(probe.count == 1)
    }

    @Test("An unrelated query does not surface the launcher")
    func unrelatedQuery() async throws {
        let query = MoonlightSurfaceEntityQuery()

        #expect(try await query.entities(matching: "zzz").isEmpty)
    }

    @Test("Retired identifiers stay listed so their index items can be withdrawn")
    func knownIdentifiersCoverPublishedSurfaces() {
        let known = Set(MoonlightSurfaceSpotlightIndex.knownIdentifiers)

        for surface in MoonlightSurfaceRegistry.standard {
            #expect(known.contains(surface.id))
        }
    }
}

@MainActor
private final class WindowProbe {
    var count = 0
}

private func requireOpenIntent<T: OpenIntent>(_ type: T.Type) {}
