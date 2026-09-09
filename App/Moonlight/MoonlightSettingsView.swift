import AppKit
import SwiftUI

struct MoonlightSettingsView: View {
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
