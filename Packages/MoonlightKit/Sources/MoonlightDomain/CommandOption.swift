import Foundation

/// A choice a command offers before it runs, declared by the feature itself.
///
/// Options exist so a tool with a mode — encode or decode, SHA-256 or SHA-512 —
/// can be rendered by any surface without that surface learning which tool it
/// is. A new tool contributes an option; no view gains a branch.
public struct CommandOption: Sendable, Equatable, Codable, Identifiable {
    public struct Choice: Sendable, Equatable, Codable, Identifiable {
        public let value: String
        public let title: String

        public var id: String { value }

        public init(value: String, title: String) {
            self.value = value
            self.title = title
        }
    }

    public let parameterName: String
    public let title: String
    public let choices: [Choice]
    public let defaultValue: String

    public var id: String { parameterName }

    public init(
        parameterName: String,
        title: String,
        choices: [Choice],
        defaultValue: String
    ) {
        self.parameterName = parameterName
        self.title = title
        self.choices = choices
        self.defaultValue = defaultValue
    }

    /// The stored value when it is still one of the offered choices, and the
    /// default otherwise — a draft must not send a value the tool rejects.
    public func resolvedValue(from selections: [String: String]) -> String {
        guard let selected = selections[parameterName],
              choices.contains(where: { $0.value == selected })
        else {
            return defaultValue
        }
        return selected
    }
}

public extension Collection<CommandOption> {
    /// Builds the parameters for a request from the user's selections.
    func parameters(from selections: [String: String]) -> ActionParameters {
        guard !isEmpty else { return .empty }
        let values = reduce(into: [String: String]()) { result, option in
            result[option.parameterName] = option.resolvedValue(from: selections)
        }
        return ActionParameters(values: values)
    }

    /// The defaults, used when a surface has no selection yet.
    var defaultSelections: [String: String] {
        reduce(into: [String: String]()) { result, option in
            result[option.parameterName] = option.defaultValue
        }
    }
}
