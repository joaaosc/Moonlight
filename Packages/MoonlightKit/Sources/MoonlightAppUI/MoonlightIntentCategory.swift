import Foundation

/// How the gallery groups Moonlight's App Intents.
///
/// The category is not drawn as a filter bar: it is search vocabulary and the
/// one word the runner sheet shows next to a tool's name.
public enum MoonlightIntentCategory: String, CaseIterable, Identifiable, Sendable {
    case core = "Core & Text"
    case transforms = "Transforms & Data"
    case system = "System & Automation"

    public var id: String { rawValue }
}
