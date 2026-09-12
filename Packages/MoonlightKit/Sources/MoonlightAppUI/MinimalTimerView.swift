import MoonlightDomain
import SwiftUI

/// A minimal countdown in the Clock app's visual language.
///
/// One thin ring, one tabular time, two quiet buttons. The domain owns the
/// parsing (`StartTimerAction.parseDuration`); this view only ticks. It keeps
/// no history itself: `onStart` lets the host record the start the same way
/// every other tool run is recorded, exactly once per fresh start — resuming
/// after a pause is not a second timer.
public struct MinimalTimerView: View {
    public let totalSeconds: Int
    public var accent: Color = .cyan
    public var onStart: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining: Double
    @State private var endDate: Date?
    @State private var isRunning = false

    public init(
        totalSeconds: Int,
        accent: Color = .cyan,
        onStart: @escaping () -> Void = {}
    ) {
        self.totalSeconds = max(0, totalSeconds)
        self.accent = accent
        self.onStart = onStart
        _remaining = State(initialValue: Double(max(0, totalSeconds)))
    }

    private var isValid: Bool { totalSeconds > 0 }
    private var isFinished: Bool { isValid && remaining <= 0 && !isRunning }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.2)) { timeline in
            let display = displayedRemaining(at: timeline.date)
            content(displayRemaining: display, isDone: isValid && display <= 0)
                .onChange(of: isRunning && display <= 0) { _, finished in
                    guard finished else { return }
                    remaining = 0
                    isRunning = false
                }
        }
        .onAppear { reset() }
        .onChange(of: totalSeconds) { reset() }
    }

    private var ringSize: CGFloat { 196 }

    private func content(displayRemaining: Double, isDone: Bool) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.quinary, lineWidth: 10)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: progress(for: displayRemaining))
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
                    .animation(reduceMotion ? nil : .linear(duration: 0.2), value: displayRemaining)

                VStack(spacing: 2) {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .foregroundStyle(accent)
                            .accessibilityHidden(true)
                    }
                    Text(StartTimerAction.formatted(seconds: Int(displayRemaining.rounded())))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityLabel(accessibilityLabel(displayRemaining: displayRemaining, isDone: isDone))
                    Text(isDone ? "Done" : (isRunning ? "Remaining" : "Ready"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill") {
                    isRunning ? pause(displayRemaining: displayRemaining) : start()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(!isValid || isDone)
                .keyboardShortcut(.defaultAction)

                Button("Reset", systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.borderless)
                .disabled(!isValid || (remaining >= Double(totalSeconds) && !isRunning))
            }
            .font(.body)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func progress(for displayRemaining: Double) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(1 - displayRemaining / Double(totalSeconds))
    }

    private func displayedRemaining(at date: Date) -> Double {
        guard isRunning, let endDate else { return remaining }
        return max(0, endDate.distance(to: date) * -1)
    }

    private func start() {
        guard isValid else { return }
        if remaining <= 0 {
            remaining = Double(totalSeconds)
        }
        let fresh = remaining >= Double(totalSeconds)
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        if fresh {
            onStart()
        }
    }

    private func pause(displayRemaining: Double) {
        remaining = displayRemaining
        endDate = nil
        isRunning = false
    }

    private func reset() {
        remaining = Double(totalSeconds)
        endDate = nil
        isRunning = false
    }

    private func accessibilityLabel(displayRemaining: Double, isDone: Bool) -> String {
        if isDone { return "Timer done" }
        let total = Int(displayRemaining.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours) hours, \(minutes) minutes remaining"
        }
        if minutes > 0 {
            return "\(minutes) minutes, \(seconds) seconds remaining"
        }
        return "\(seconds) seconds remaining"
    }
}

#if DEBUG
#Preview("Timer idle") {
    MinimalTimerView(totalSeconds: 1_500)
        .padding()
        .frame(width: 320)
}

#Preview("Timer short") {
    MinimalTimerView(totalSeconds: 90, accent: .orange)
        .padding()
        .frame(width: 320)
}
#endif
