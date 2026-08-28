# Moonlight architecture

Moonlight is a macOS 27 application that exposes small, semantic actions through App Intents and presents their results as system-hosted snippets.

## MVP flow

```text
Spotlight
  -> ExecuteActionIntent
  -> ActionEntity
  -> ActionRunner
  -> ExecutionStore
  -> ExecutionSnippetIntent
  -> ExecutionSnippetView
```

The first action is `Capture Note`, retained because BetterSpotlight proved short text capture, Unicode round trips, background App Intent execution, and process-local persistence. The implementation is rewritten around actions and executions rather than copied from the SlashLab probe.

## Module boundaries

```text
Moonlight.app
  -> MoonlightAppUI
  -> MoonlightIntents

MoonlightAppUI ---------> MoonlightInfrastructure -> MoonlightDomain
MoonlightIntents -------> MoonlightInfrastructure -> MoonlightDomain
MoonlightIntents -------> MoonlightSnippetUI ------> MoonlightDomain
```

- `MoonlightDomain`: action descriptors, requests, results, executions, registry, runner, store protocol, and in-memory test implementation. It imports no SwiftUI, AppKit, AppIntents, SwiftData, or CoreSpotlight.
- `MoonlightInfrastructure`: file-backed execution store and the live composition used by the app and intents.
- `MoonlightSnippetUI`: SwiftUI presentation intended for system-hosted snippets.
- `MoonlightIntents`: AppEntity adapters, queries, the execution intent, and the side-effect-free snippet intent.
- `MoonlightAppUI`: thin SwiftUI MV surface for local execution and execution history.

## Deliberate exclusions

- No App Intents Extension until cold-start and process-lifetime evidence justifies a second process.
- No Core Spotlight index until the intent-to-snippet path is manually proven on the installed beta.
- No App Shortcuts provider for the macOS product path.
- No slash parser or `/note` discovery contract.
- No `NSPanel` yet. Foreground escalation and the AppKit panel remain a later milestone.
- No arbitrary shell execution, destructive actions, undo, long-running intents, or third-party runtime dependencies.

## Persistence

The MVP uses an actor-backed Codable store in Application Support. Writes replace a versioned JSON document atomically. Version mismatches, malformed documents, and duplicate execution identifiers fail explicitly instead of discarding history. The store retains the newest 500 executions by default and preserves insertion order as a deterministic tie-breaker when timestamps match. This preserves the tested actor/Codable approach from BetterSpotlight while avoiding migration of its note-specific NDJSON and unfinished SwiftData schema.

## Execution invariants

- An action always resolves through `ActionRegistry` and `ActionRunner`.
- Functional failures, including blank input, over-limit input, and unknown actions, are persisted as failed executions and can be rendered by the same snippet path.
- Storage failures are thrown to the caller and are never presented as successful actions.
- `ExecutionSnippetIntent` is read-only: it resolves an execution by UUID and creates a view on the main actor.
- Runtime creation exposes typed failure instead of silently substituting an empty store.

## Validation boundary

Compilation, automated tests, metadata extraction, signing, and bundle validation prove the technical walking skeleton. They do not prove Spotlight ranking, cold-start behavior, or the visual presentation of the snippet in the system UI. Those remain a separate manual acceptance gate on the installed macOS beta.
