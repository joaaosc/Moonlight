import AppKit
import MoonlightAppUI
import MoonlightIntents
import SwiftUI

struct MoonlightSettingsView: View {
    let hotKeyCenter: GlobalHotKeyCenter

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                MoonlightGeneralSettingsView(hotKeyCenter: hotKeyCenter)
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

    @AppStorage("showDockIcon") private var showsDockIcon = false
    @State private var activationError: String?

    var body: some View {
        Form {
            Section("Global Shortcut") {
                HotKeyRecorderView(center: hotKeyCenter)
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
