import AppKit
import SwiftUI

/// Turns a horizontal two-finger swipe into a page change, the way the
/// launcher this replaces did.
///
/// AppKit rather than a SwiftUI `DragGesture`: the tiles already own dragging —
/// that is how the grid is rearranged — so a drag recognizer over the same area
/// would have to win a fight it should not be in. Scroll events travel a
/// different path and never collide with it.
struct LauncherPageSwipe: NSViewRepresentable {
    /// Called with -1 for a swipe towards the previous page, +1 for the next.
    let onPageChange: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        SwipeView(onPageChange: onPageChange)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? SwipeView)?.onPageChange = onPageChange
    }

    final class SwipeView: NSView {
        /// How far a swipe travels before it counts. Precise devices report
        /// many small deltas, so the threshold is in points of travel rather
        /// than in events.
        private static let preciseThreshold: CGFloat = 55
        /// Line-based devices — a wheel mouse — report far coarser units.
        private static let coarseThreshold: CGFloat = 2

        var onPageChange: (Int) -> Void
        private var travelled: CGFloat = 0
        /// Keeps one continuous swipe from paging twice: the finger has to
        /// lift before the next page can be asked for.
        private var hasPagedInGesture = false

        init(onPageChange: @escaping (Int) -> Void) {
            self.onPageChange = onPageChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func scrollWheel(with event: NSEvent) {
            // A vertical scroll is not a page turn; let it pass untouched.
            guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else {
                super.scrollWheel(with: event)
                return
            }

            if event.phase.contains(.began) {
                travelled = 0
                hasPagedInGesture = false
            }

            // Natural scrolling flips the sign; the page should follow the
            // content the way the user sees it move.
            let delta = event.isDirectionInvertedFromDevice
                ? -event.scrollingDeltaX
                : event.scrollingDeltaX
            travelled += delta

            let threshold = event.hasPreciseScrollingDeltas
                ? Self.preciseThreshold
                : Self.coarseThreshold

            if !hasPagedInGesture, abs(travelled) >= threshold {
                // Swiping content leftwards reveals the page to its right.
                onPageChange(travelled < 0 ? 1 : -1)
                hasPagedInGesture = true
                travelled = 0
            }

            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                travelled = 0
                hasPagedInGesture = false
            }
        }
    }
}
