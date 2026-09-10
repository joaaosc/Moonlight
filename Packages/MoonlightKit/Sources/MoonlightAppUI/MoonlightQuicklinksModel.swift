import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

/// Manages the quicklinks the user turned into commands.
@MainActor
@Observable
public final class MoonlightQuicklinksModel {
    public private(set) var quicklinks: [QuicklinkCommand] = []
    public private(set) var errorMessage: String?

    public var draftTitle = ""
    public var draftURLTemplate = ""
    public var draftAlias = ""

    private let store: QuicklinkStore?
    private let cache: QuicklinkCache

    public init(store: QuicklinkStore?, cache: QuicklinkCache) {
        self.store = store
        self.cache = cache
        if store == nil {
            errorMessage = "Moonlight cannot reach its shared container, so quicklinks are unavailable."
        }
    }

    public convenience init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        switch environment {
        case let .success(environment):
            self.init(store: environment.quicklinkStore, cache: environment.quicklinkCache)
        case let .failure(error):
            self.init(store: nil, cache: QuicklinkCache())
            errorMessage = error.localizedDescription
        }
    }

    public var canAddDraft: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftURLTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func load() async {
        guard let store else { return }
        do {
            let stored = try await store.quicklinks()
            apply(stored)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addDraft() async {
        guard let store, canAddDraft else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let alias = draftAlias.isEmpty
            ? ShortcutCommandBinding.suggestedAlias(
                for: title,
                avoiding: Set(quicklinks.map(\.alias))
                    .union(ShortcutCommandBinding.reservedAliases())
            )
            : ShortcutCommandBinding.normalizedAlias(draftAlias)

        let quicklink = QuicklinkCommand(
            title: title,
            urlTemplate: draftURLTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            alias: alias
        )

        do {
            apply(try await store.add(quicklink))
            draftTitle = ""
            draftURLTemplate = ""
            draftAlias = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(_ quicklink: QuicklinkCommand) async {
        guard let store else { return }
        do {
            apply(try await store.remove(id: quicklink.id))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ stored: [QuicklinkCommand]) {
        quicklinks = stored
        cache.replace(stored)
    }
}
