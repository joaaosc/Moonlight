import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

/// Manages the shell scripts the user turned into commands.
@MainActor
@Observable
public final class MoonlightTerminalModel {
    public private(set) var commands: [TerminalCommand] = []
    public private(set) var errorMessage: String?

    public var draftTitle = ""
    public var draftAlias = ""
    public var draftLines = ""

    private let store: TerminalCommandStore?
    private let cache: TerminalCache

    public init(store: TerminalCommandStore?, cache: TerminalCache) {
        self.store = store
        self.cache = cache
        if store == nil {
            errorMessage = "Moonlight cannot reach its shared container, so terminal commands are unavailable."
        }
    }

    public convenience init(
        environment: Result<MoonlightEnvironment, MoonlightRuntimeError> = MoonlightProcess.environment
    ) {
        switch environment {
        case let .success(environment):
            self.init(store: environment.terminalStore, cache: environment.terminalCache)
        case let .failure(error):
            self.init(store: nil, cache: TerminalCache())
            errorMessage = error.localizedDescription
        }
    }

    public var canAddDraft: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draftLines
                .split(separator: "\n")
                .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func load() async {
        guard let store else { return }
        do {
            let stored = try await store.commands()
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
                avoiding: Set(commands.map(\.alias))
                    .union(ShortcutCommandBinding.reservedAliases())
            )
            : ShortcutCommandBinding.normalizedAlias(draftAlias)
        let lines = draftLines
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let command = TerminalCommand(
            title: title,
            lines: lines,
            alias: alias
        )

        do {
            apply(try await store.add(command))
            draftTitle = ""
            draftAlias = ""
            draftLines = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(_ command: TerminalCommand) async {
        guard let store else { return }
        do {
            apply(try await store.remove(id: command.id))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ stored: [TerminalCommand]) {
        commands = stored
        cache.replace(stored)
    }
}
