import Foundation
import SwiftUI

/// One entry in the intents gallery.
///
/// Colour is deliberately a single accent rather than a gradient ramp: the
/// gallery shows a dozen of these side by side, and Apple's guidance is to keep
/// colour sparse so the set reads as one system instead of twelve badges.
public struct MoonlightIntentItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: MoonlightIntentCategory
    public let symbolName: String
    public let accentColor: Color
    public let requiresInput: Bool
    public let sampleInput: String
    public let parameterKey: String?
    public let parameterOptions: [(title: String, value: String)]
    public let defaultParameterValue: String?

    public init(
        id: String,
        title: String,
        subtitle: String,
        category: MoonlightIntentCategory,
        symbolName: String,
        accentColor: Color,
        requiresInput: Bool = true,
        sampleInput: String = "",
        parameterKey: String? = nil,
        parameterOptions: [(title: String, value: String)] = [],
        defaultParameterValue: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.symbolName = symbolName
        self.accentColor = accentColor
        self.requiresInput = requiresInput
        self.sampleInput = sampleInput
        self.parameterKey = parameterKey
        self.parameterOptions = parameterOptions
        self.defaultParameterValue = defaultParameterValue
    }
}
