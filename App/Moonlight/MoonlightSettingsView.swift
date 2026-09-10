import AppKit
import MoonlightAppUI
import SwiftUI

struct MoonlightSettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                MoonlightGeneralSettingsView()
            }
            Tab("Shortcuts", systemImage: "link") {
                ShortcutBindingsView()
                    .frame(width: 560, height: 420)
            }
        }
        .scenePadding()
    }
}

private struct MoonlightGeneralSettingsView: View {
    @AppStorage("showDockIcon") private var showsDockIcon = false
    @State private var activationError: String?

    var body: some View {
        Form {
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
