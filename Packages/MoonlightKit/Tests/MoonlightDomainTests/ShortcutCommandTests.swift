import Foundation
import Testing
@testable import MoonlightDomain

@Suite("Shortcut command bindings")
struct ShortcutCommandBindingTests {
    @Test("An alias is normalized to a single addressable token")
    func normalizesAlias() {
        #expect(ShortcutCommandBinding.normalizedAlias("  Daily Note ") == "daily-note")
        #expect(ShortcutCommandBinding.normalizedAlias("Café/Notes") == "café-notes")
        #expect(ShortcutCommandBinding.normalizedAlias("***") == "")
    }

    @Test("Two shortcuts sharing a name receive distinct aliases")
    func suggestsDistinctAliases() {
        let first = ShortcutCommandBinding.suggestedAlias(for: "Daily Note", avoiding: [])
        let second = ShortcutCommandBinding.suggestedAlias(
            for: "Daily Note",
            avoiding: [first]
        )
        let third = ShortcutCommandBinding.suggestedAlias(
            for: "Daily Note",
            avoiding: [first, second]
        )

        #expect(first == "daily-note")
        #expect(second == "daily-note-2")
        #expect(third == "daily-note-3")
    }

    @Test("A binding keeps its identity when the shortcut is renamed")
    func keepsIdentityAcrossRename() {
        let summary = ShortcutSummary(externalID: "external-1", name: "Daily Note")
        var binding = ShortcutCommandBinding(summary: summary, alias: "daily-note")
        let originalCommandID = binding.commandID

        binding.cachedName = "Morning Note"

        #expect(binding.commandID == originalCommandID)
        #expect(binding.externalID == "external-1")
        #expect(binding.definition().descriptor.title == "Morning Note")
    }

    @Test("A command identifier cannot collide with a built-in tool")
    func commandIDIsNamespaced() {
        let binding = ShortcutCommandBinding(
            externalID: "external-1",
            cachedName: "Daily Note",
            alias: "daily-note"
        )

        #expect(binding.commandID.hasPrefix(ShortcutCommandBinding.commandIDPrefix))
        #expect(!ActionRegistry.standard.descriptors.contains { $0.id == binding.commandID })
    }

    @Test("Input handling follows the shortcut's declared input by default")
    func derivesInputKind() {
        let accepting = ShortcutCommandBinding(
            summary: ShortcutSummary(externalID: "a", name: "A", acceptsInput: true),
            alias: "a"
        )
        let plain = ShortcutCommandBinding(
            summary: ShortcutSummary(externalID: "b", name: "B", acceptsInput: false),
            alias: "b"
        )

        #expect(accepting.inputKind == .text)
        #expect(plain.inputKind == .none)
    }
}

@Suite("User shortcut catalog provider")
struct UserShortcutCommandProviderTests {
    @Test("Without a listing nothing is reported as missing")
    func availabilityRequiresEvidence() throws {
        let binding = ShortcutCommandBinding(
            externalID: "external-1",
            cachedName: "Daily Note",
            alias: "daily-note"
        )
        let cache = ShortcutBindingsCache()
        cache.replaceBindings([binding])

        let definitions = try UserShortcutCommandProvider(cache: cache).snapshot()

        #expect(definitions.count == 1)
        #expect(definitions[0].presentation.symbolName == "link")
        #expect(!definitions[0].descriptor.summary.contains("unavailable"))
    }

    @Test("A shortcut missing from the last listing is marked unavailable")
    func marksMissingShortcut() throws {
        let binding = ShortcutCommandBinding(
            externalID: "external-1",
            cachedName: "Daily Note",
            alias: "daily-note"
        )
        let cache = ShortcutBindingsCache()
        cache.replaceBindings([binding])
        cache.recordAvailability(externalIDs: ["external-2"])

        let definitions = try UserShortcutCommandProvider(cache: cache).snapshot()

        #expect(definitions[0].presentation.symbolName == "exclamationmark.triangle")
        #expect(definitions[0].descriptor.summary.contains("unavailable"))
    }

    @Test("Personal commands compose with the built-in catalog")
    func composesWithBuiltins() throws {
        let cache = ShortcutBindingsCache()
        cache.replaceBindings([
            ShortcutCommandBinding(
                externalID: "external-1",
                cachedName: "Daily Note",
                alias: "daily-note"
            ),
        ])

        let definitions = try CompositeCommandCatalogProvider(
            BuiltInCommandProvider(),
            UserShortcutCommandProvider(cache: cache)
        ).snapshot()

        #expect(definitions.count == ActionRegistry.standard.descriptors.count + 1)
    }
}

@Suite("Relinking a shortcut command")
struct ShortcutRelinkTests {
    @Test("Relinking moves the handle and keeps the command")
    func keepsCommandIdentity() {
        let original = ShortcutCommandBinding(
            externalID: "external-1",
            cachedName: "Daily Note",
            alias: "daily-note",
            inputKind: .text
        )

        let relinked = original.relinked(
            to: ShortcutSummary(
                externalID: "external-2",
                name: "Daily Note (restored)",
                subtitle: "Notes"
            )
        )

        #expect(relinked.id == original.id)
        #expect(relinked.commandID == original.commandID)
        #expect(relinked.alias == original.alias)
        #expect(relinked.inputKind == original.inputKind)
        #expect(relinked.externalID == "external-2")
        #expect(relinked.cachedName == "Daily Note (restored)")
        #expect(relinked.lastSeenAt != nil)
    }
}
