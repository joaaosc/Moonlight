import SwiftUI

struct ExecutionPlaceholderView: View {
    let hasExecutions: Bool

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: hasExecutions ? "sidebar.left" : "moon.stars",
            description: Text(description)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        hasExecutions ? "Select an Execution" : "Ready to Capture"
    }

    private var description: String {
        if hasExecutions {
            "Choose an item in History to see its complete result."
        } else {
            "Capture a note here or run Moonlight from Spotlight."
        }
    }
}
