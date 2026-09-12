import AppKit
import MoonlightAppUI
import MoonlightInfrastructure
import MoonlightIntents
import SwiftUI

struct MoonlightSettingsView: View {
    let hotKeyCenter: GlobalHotKeyCenter
    let launcherHotKeyCenter: GlobalHotKeyCenter

    /// One size for the whole window instead of one per tab.
    ///
    /// Each tab used to pin its own width and height, so switching tabs
    /// resized the window and no tab could be resized at all. The floor lives
    /// here, the ceiling is the user's.
    private enum Metrics {
        static let minimumSize = CGSize(width: 560, height: 440)
        static let idealSize = CGSize(width: 620, height: 520)
    }

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                MoonlightGeneralSettingsView(
                    hotKeyCenter: hotKeyCenter,
                    launcherHotKeyCenter: launcherHotKeyCenter
                )
            }
            Tab("Quicklinks", systemImage: "arrow.up.right.square") {
                QuicklinksView()
            }
            Tab("Terminal", systemImage: "terminal") {
                TerminalCommandsView()
            }
            Tab("Diagnostics", systemImage: "stethoscope") {
                DiagnosticsView()
            }
            Tab("Shortcuts", systemImage: "link") {
                ShortcutBindingsView(
                    model: MoonlightShortcutsModel(
                        reindexCatalog: { try await MoonlightToolSpotlightIndex.refresh() }
                    )
                )
            }
        }
        .scenePadding()
        .frame(
            minWidth: Metrics.minimumSize.width,
            idealWidth: Metrics.idealSize.width,
            maxWidth: .infinity,
            minHeight: Metrics.minimumSize.height,
            idealHeight: Metrics.idealSize.height,
            maxHeight: .infinity
        )
    }
}

private struct MoonlightGeneralSettingsView: View {
    let hotKeyCenter: GlobalHotKeyCenter
    let launcherHotKeyCenter: GlobalHotKeyCenter

    @AppStorage("showDockIcon") private var showsDockIcon = false
    @AppStorage(MoonlightRetention.executionLimitKey)
    private var executionLimit = MoonlightRetention.defaultExecutionLimit
    @AppStorage(MoonlightRetention.noteLimitKey)
    private var noteLimit = MoonlightRetention.defaultNoteLimit
    @State private var activationError: String?

    var body: some View {
        Form {
            Section("Global Shortcut") {
                HotKeyRecorderView(center: hotKeyCenter)
            }
            Section("Launcher Shortcut") {
                HotKeyRecorderView(center: launcherHotKeyCenter)
            }
            Section {
                Stepper(
                    "Keep \(executionLimit.formatted()) executions",
                    value: $executionLimit,
                    in: MoonlightRetention.minimumLimit...MoonlightRetention.maximumLimit,
                    step: 50
                )
                Stepper(
                    "Keep \(noteLimit.formatted()) notes",
                    value: $noteLimit,
                    in: MoonlightRetention.minimumLimit...MoonlightRetention.maximumLimit,
                    step: 50
                )
                Text("New limits apply the next time Moonlight starts. Records beyond the limit are dropped when the next one is written.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Retention")
            }

            Section {
                Toggle("Show Moonlight in the Dock", isOn: $showsDockIcon)
                    .onChange(of: showsDockIcon) { previousValue, newValue in
                        let policy: NSApplication.ActivationPolicy = newValue ? .regular : .accessory
                        guard NSApplication.shared.activationPolicy() != policy else { return }
                        if NSApplication.shared.setActivationPolicy(policy) {
                            activationError = nil
                        } else {
                            showsDockIcon = previousValue
                            activationError = "Could not change Dock visibility. Please try again."
                        }
                    }
                Text("Moonlight runs without a Dock icon by default. Use Spotlight for tools and the menu bar for the control panel and settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Appearance")
            }
            if let activationError {
                Label(activationError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
