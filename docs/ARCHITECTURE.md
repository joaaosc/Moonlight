# Moonlight architecture

Moonlight is a macOS 27 application that exposes small semantic tools through App Intents, records every execution, and presents compact results in system-hosted snippets.

## Current system flow

```text
Spotlight / Shortcuts for Mac / AppIntentsTesting
  -> CaptureNoteIntent (discoverable, background, app or extension)
     -> required text
     -> MoonlightIntentExecutor
     -> ActionRunner
     -> FileExecutionStore in the shared App Group
     -> ExecutionSnippetIntent
     -> ExecutionSnippetView hosted by the system

  -> OpenColorPickerIntent (discoverable, immediate foreground, main app only)
     -> MoonlightIntentExecutor
     -> MoonlightForegroundClient
     -> MoonlightColorPanelPresenter
     -> hide the Moonlight history window for intent-driven presentation
     -> NSColorPanel.shared

Previously saved build 2 shortcuts
  -> RunMoonlightCommandIntent (not discoverable, main app only)
     -> MoonlightCommandParser
     -> the same domain actions and execution store
```

The system builds the intent interface from static metadata. Moonlight controls titles, parameter types, summaries, dialogs, execution, and snippet content. Spotlight controls discovery, ranking, tokenization, outer layout, and the exact parameter-resolution presentation.

There is no contract for intercepting the global Spotlight query. New executions use purpose-specific intents rather than parsing free-form Spotlight text. The domain parser remains available for a future Moonlight-owned text surface and for actions saved against the build 2 `command` parameter.

The build 4 manual gate rejected the optional tool dispatcher because Spotlight repeatedly opened a disambiguation picker. Build 5 proved that a default note value removed the picker, but also exposed an execution-boundary defect: a color action persisted in the extension while the main-process UI dependency was unavailable. Build 6 therefore separates background capture from foreground presentation. Build 7 keeps those contracts and isolates the color panel from the app's history window.

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
- `MoonlightIntents`: purpose-specific App Intents adapters, the legacy parser adapter, foreground bridge, and side-effect-free snippet intent.
- `MoonlightAppUI`: thin SwiftUI MV surface for direct note capture, execution history, and the AppKit color-panel presenter.
- `Moonlight.app`: composition root and registration of the main-process foreground dependency.
- `MoonlightAppIntentsExtension`: isolated system execution entry point using the same App Group store.

The dependency direction remains inward toward `MoonlightDomain`. App Intents and AppKit types do not cross into the domain.

## Public intent contract

There are two discoverable intents with different execution contracts:

- `CaptureNoteIntent` requires `text`, supports background execution, and may run in the app or App Intents extension;
- `OpenColorPickerIntent` has no parameters, uses immediate foreground mode, and may run only in the main app process.

Each adapter invokes one stable domain action ID:

- `CaptureNoteIntent` -> `capture-note`;
- `OpenColorPickerIntent` -> `open-color-picker`.

This removes the tool-selection parameter completely. Spotlight can resolve the required note text directly from the `Capture Note` summary, while the color action never displays a text field or tool picker.

`RunMoonlightCommandIntent` is retained with its original required `command` parameter and parser, but `isDiscoverable` is false. It is restricted to the main app process so legacy color commands cannot attempt to present AppKit UI from the extension. Removing or renaming this legacy type still requires an explicit shortcut migration.

`MoonlightAppShortcuts` publishes only these two common actions. Their short titles and SF Symbols provide the system metadata used by Spotlight, Siri, and Shortcuts for Mac; the provider doesn't add a third dispatch surface or change either intent's parameters.

## Visual system

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
- No Core Spotlight index until Moonlight has content that is useful to search independently of command dispatch.
- No CloudKit, remote telemetry, or third-party runtime dependencies.
- No weakening of App Sandbox or signing requirements.
- No large editor or command grid inside a snippet.

## Validation boundary

Compilation, Swift tests, hosted App Intents tests, metadata extraction, signing, and bundle inspection prove separate technical layers. They do not prove Spotlight ranking, parameter UI, cold start, foreground continuation, or the visual snippet in the installed system.

Any change to intent title, parameters, summary, modes, execution targets, or identifiers requires:

1. a new installed build;
2. metadata inspection of that exact Release bundle;
3. a real Spotlight run with the app open;
4. a second run with the app terminated;
5. independent verification of persisted execution and snippet output.

The milestone remains open until those manual system gates pass.
