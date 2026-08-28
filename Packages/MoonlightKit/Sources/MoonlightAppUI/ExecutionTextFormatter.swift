import Foundation

public enum ExecutionTextFormatter {
    public static func preview(_ text: String) -> String {
        text
            .split { $0.isWhitespace }
            .joined(separator: " ")
    }
}
