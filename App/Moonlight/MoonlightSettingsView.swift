import AppKit
import MoonlightAppUI
import MoonlightInfrastructure
import MoonlightIntents
import SwiftUI

struct MoonlightSettingsView: View {
    let hotKeyCenter: GlobalHotKeyCenter
    let launcherHotKeyCenter: GlobalHotKeyCenter

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
                    .frame(width: 560, height: 460)
            }
            Tab("Diagnostics", systemImage: "stethoscope") {
                DiagnosticsView()
                    .frame(width: 560, height: 420)
            }
            Tab("Shortcuts", systemImage: "link") {
                ShortcutBindingsView(
                    model: MoonlightShortcutsModel(
                        reindexCatalog: { try await MoonlightToolSpotlightIndex.refresh() }
                    )
                )
                .frame(width: 560, height: 460)
            }
        }
        .scenePadding()
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
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
