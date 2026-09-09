# Moonlight architecture

Moonlight is a macOS 27 application that provides a native palette of small semantic tools, records executions, and experiments with public Spotlight and App Intents surfaces.

## Current system flow

```text
Spotlight
  -> Moonlight.app result
     -> Tab scopes search to Moonlight content
     -> MoonlightToolEntity in the named Core Spotlight index
     -> OpenMoonlightToolIntent (discoverable system route, main app only)
     -> MoonlightForegroundClient
     -> Color Picker: execute action and present NSColorPanel directly
     -> other tools: MoonlightToolPalettePresenter
     -> selected ActionDescriptor
     -> ActionRunner
     -> FileExecutionStore in the shared App Group

Moonlight palette
  -> ActionRegistry.standard
  -> six ActionDescriptor values
  -> MoonlightRuntimeClient
  -> ActionRunner / FileExecutionStore
  -> foreground adapter only when a tool needs AppKit

AppIntentsTesting / previously saved shortcuts
  -> public OpenColorPickerIntent; hidden CaptureNoteIntent, FormatJSONIntent,
     OpenMoonlightIntent, and RunMoonlightCommandIntent

Previously saved build 2 shortcuts
  -> RunMoonlightCommandIntent (not discoverable, main app only)
     -> MoonlightCommandParser
     -> the same domain actions and execution store
```

The system builds the intent interface from static metadata. Moonlight controls titles, parameter types, summaries, dialogs, execution, and snippet content. Spotlight controls discovery, ranking, tokenization, outer layout, and the exact parameter-resolution presentation.

There is no contract for intercepting the global Spotlight query. New executions use purpose-specific intents rather than parsing free-form Spotlight text. The domain parser remains available for a future Moonlight-owned text surface and for actions saved against the build 2 `command` parameter.

The build 4 manual gate rejected the optional tool dispatcher because Spotlight repeatedly opened a disambiguation picker. Builds 11 through 13 showed that publishing specialized actions created extra results without reliable snippet presentation. Builds 14 through 18 moved the complete catalog to a Moonlight-owned `NSPanel`. Build 19 adds an indexed catalog experiment so the app result can remain the root while tools are represented as app content.

## Module boundaries

```text
Moonlight.app
  -> MoonlightAppUI
  -> MoonlightIntents

MoonlightAppIntentsExtension
  -> MoonlightIntents

MoonlightAppUI ---------> MoonlightInfrastructure -> MoonlightDomain
MoonlightIntents -------> MoonlightInfrastructure -> MoonlightDomain
MoonlightIntents -------> MoonlightSnippetUI ------> MoonlightDomain
```

- `MoonlightDomain`: action IDs, descriptors, requests, results, executions, parser, registry, runner, store protocol, and in-memory test implementation. It imports no SwiftUI, AppKit, AppIntents, SwiftData, or Core Spotlight.
- `MoonlightInfrastructure`: file-backed execution store and live runtime composition shared by app and extension.
- `MoonlightSnippetUI`: compact SwiftUI result presentation hosted by the system.
- `MoonlightIntents`: hidden compatibility intents, `MoonlightToolEntity`, its queries and named Spotlight index, `OpenMoonlightToolIntent`, the foreground bridge, and the side-effect-free snippet intent.
- `MoonlightAppUI`: SwiftUI/AppKit adapters for the searchable tool palette, execution history, and color panel.
- `Moonlight.app`: composition root and registration of the main-process foreground dependency.
- `MoonlightAppIntentsExtension`: isolated system execution entry point using the same App Group store.

The dependency direction remains inward toward `MoonlightDomain`. App Intents and AppKit types do not cross into the domain.

## Spotlight and App Intents contract

- No `AppShortcutsProvider` is shipped. Apple’s current HIG states that App Shortcuts aren’t supported on macOS, and the previous provider produced independent top-level results.
- `OpenColorPickerIntent` is a discoverable parameter-free foreground action. Other compatibility intents remain hidden; `OpenMoonlightToolIntent` is the public open route for indexed entities.
- `MoonlightToolEntity` is the only discoverable entity type. Its IDs and descriptions are projections of `ActionRegistry.standard` rather than a second catalog.
- The main app upserts six stable tool entities into `Moonlight_Tools` without deleting the index at launch. The index contains no execution history or user text. Removing a tool in a future release requires targeted deletion of its indexed entity.
- `OpenMoonlightToolIntent` opens the color panel directly for `open-color-picker`, and the selected tool editor for other IDs. It is foreground-only and restricted to the main process; its summary includes the required target parameter.
- `ShowInAppSearchResultsIntent` is deliberately absent. Apple documents it as a handoff to the app’s own search UI, especially when Spotlight has more than ten results; it does not make Spotlight display an action menu.
- Spotlight owns whether indexed entities appear after Tab, in general results, and in what order. Build 21 physically showed all six tools after Tab and opened Color Picker while the app was running. Cold-start presentation and three integration failures remain unresolved; see VALIDATION.md.

## Visual system

The composition root does not present windows during `App.init`. The application delegate presents the palette for a default launch or explicit reopen. Explicit intent presentation takes precedence if it arrives before launch completion. History launch/restoration is suppressed outside history tests and opened through SwiftUI's `openWindow`. Presenting the color panel dismisses the palette first. `InfoPlist.strings` supplies localized bundle names; Spotlight's final display remains a system behavior to verify.

The application icon is a layered `Moonlight.icon` document consumed by Icon Composer and selected through `ASSETCATALOG_COMPILER_APPICON_NAME`. Its source uses one full-bleed background and one centered crescent; masking, specular highlights, refraction, shadows, and appearance variants are rendered by the system.

Moonlight-owned UI uses native SwiftUI and AppKit structures. Liquid Glass is reserved for navigation, transient controls, and other functional layers where the system material provides hierarchy; content surfaces do not receive decorative glass effects by default.

## Execution invariants

- Every functional tool resolves to a registered `ActionHandler` and runs through `ActionRunner`.
- IDs stored in executions are stable strings and are not renamed without migration.
- Functional failures are persisted as failed executions when they occur inside a handler.
- Parameter-resolution failures occur before domain execution and are not recorded as successful actions.
- Storage failures are thrown and never presented as success.
- The snippet intent reads persisted state and does not perform the original side effect again.
- Foreground presentation remains an adapter concern and runs on the main actor.
- An actor provides process-local exclusion only; cross-process sharing comes from the atomic App Group store contract.

## Persistence

The initial product uses an actor-backed Codable store in the App Group container. Writes replace a versioned JSON document atomically. Version mismatches, malformed documents, and duplicate identifiers fail explicitly instead of silently discarding history.

The store retains a bounded recent history and transfers only `Sendable` value types across actors and processes. BetterSpotlight and SlashLab data are not migrated implicitly.

## Deliberate exclusions

- No interception of global Spotlight text.
- No slash-command discovery contract.
- No runtime registration of new App Intent types.
- No arbitrary shell execution or downloaded code.
- No Core Spotlight content beyond the bounded build 19 tool-catalog experiment.
- No CloudKit, remote telemetry, or third-party runtime dependencies.
- No weakening of App Sandbox or signing requirements.
- No large editor or command grid inside a snippet.

## Validation boundary

Compilation, Swift tests, hosted App Intents tests, metadata extraction, signing, and bundle inspection prove separate technical layers. They do not prove Spotlight ranking, parameter UI, cold start, foreground continuation, or the visual snippet in the installed system.

Any change to intent/entity title, parameters, summary, modes, execution targets, identifiers, or indexing requires:

1. a new installed build;
2. metadata inspection of that exact Release bundle;
3. a real Spotlight run with the app open;
4. a second run with the app terminated;
5. independent verification of persisted execution and snippet output.

The milestone remains open until those manual system gates pass.
