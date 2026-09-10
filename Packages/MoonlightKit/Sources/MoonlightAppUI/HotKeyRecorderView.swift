import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Captures a key combination for the global shortcut.
///
/// The recorder listens only while the user asked for it, and only inside
/// Moonlight's own windows.
public struct HotKeyRecorderView: View {
    private let center: GlobalHotKeyCenter

    @State private var isRecording = false
    @State private var monitor: Any?

    public init(center: GlobalHotKeyCenter) {
        self.center = center
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: toggleRecording) {
                    Text(label)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .help("Record a shortcut that opens Moonlight from any app")

                if center.hotKey != nil {
                    Button("Clear", systemImage: "xmark.circle") {
                        stopRecording()
                        center.clear()
                    }
                    .labelStyle(.iconOnly)
                }
            }

            if let failure = center.failure {
                Label(failure.message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else if center.hotKey != nil, center.isActive {
                Label("Shortcut active", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // This is Moonlight's own shortcut, registered with macOS. It is
            // not a Spotlight Quick Key and does not change Spotlight.
            Text("Opens the Moonlight palette from any app. Requires at least one modifier key.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording {
            return "Press keys… (⎋ cancels)"
        }
        return center.hotKey?.displayString ?? "Record Shortcut"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode != UInt16(kVK_Escape) else {
                stopRecording()
                return nil
            }
            guard let hotKey = MoonlightHotKey(event: event) else {
                // Not a usable combination; keep listening instead of storing
                // something that would swallow ordinary typing.
                return nil
            }
            center.update(to: hotKey)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }
}
