import Foundation
import MoonlightDomain
import Testing
@testable import MoonlightAppUI

/// The contract between the intents gallery and the action registry.
///
/// A card's identifier is what the runner hands to the registry. When no
/// handler answers to it the run fails as `unknownAction` and a failed record
/// lands in the history — which is what happened to the three cards the
/// interface runs itself. Nothing checked the two lists against each other, so
/// the mismatch was only visible by pressing the card.
@Suite("Intent catalogue contract")
struct MoonlightIntentCatalogTests {
    private var registeredIDs: Set<String> {
        Set(ActionRegistry.standard.descriptors.map(\.id))
    }

    @Test("Every card either has a handler or is run by the interface")
    func everyCardResolves() {
        for item in MoonlightIntentCatalog.allIntents {
            let isRegistered = registeredIDs.contains(item.id)
            let isInterfaceHandled = MoonlightIntentCatalog.interfaceHandledIDs.contains(item.id)
            #expect(
                isRegistered || isInterfaceHandled,
                "Card \(item.id) has no action handler and is not handled by the interface"
            )
        }
    }

    @Test("The interface does not claim cards that a handler already answers")
    func interfaceListDoesNotShadowHandlers() {
        for id in MoonlightIntentCatalog.interfaceHandledIDs {
            #expect(
                !registeredIDs.contains(id),
                "Card \(id) has a handler, so the interface must not run it itself"
            )
        }
    }

    @Test("The interface list names cards that exist")
    func interfaceListHasNoStrays() {
        let cardIDs = Set(MoonlightIntentCatalog.allIntents.map(\.id))

        for id in MoonlightIntentCatalog.interfaceHandledIDs {
            #expect(cardIDs.contains(id), "\(id) is named but is not a card")
        }
    }

    /// The other direction: an action that exists but is listed nowhere is
    /// reachable from Shortcuts and from nothing else, which is how the
    /// summary tool started out.
    @Test("Every registered action is listed in the gallery")
    func everyActionIsACard() {
        let cardIDs = Set(MoonlightIntentCatalog.allIntents.map(\.id))

        for id in registeredIDs {
            #expect(cardIDs.contains(id), "Action \(id) is registered but has no card")
        }
    }

    @Test("Summarize reaches the catalogue, not only Shortcuts")
    func summarizeIsACard() {
        let ids = MoonlightIntentCatalog.allIntents.map(\.id)

        #expect(ids.contains(MoonlightActionID.summarizeText))
        #expect(registeredIDs.contains(MoonlightActionID.summarizeText))
    }
}
