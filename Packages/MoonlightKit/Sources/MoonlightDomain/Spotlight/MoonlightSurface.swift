import Foundation

/// A Moonlight surface published to Spotlight behind a short typed alias.
///
/// The alias is the whole point: Spotlight already finds the app by name, so
/// what a launcher needs is a two or three letter prefix that reaches one
/// surface directly. The alias is indexed as a keyword and as an alternate
/// name, which is what makes `omt` resolve to Moonlight instead of to whatever
/// else on the machine happens to contain those letters.
public struct MoonlightSurface: Sendable, Hashable, Identifiable {
    public let id: String
    /// The literal text the user types in Spotlight, lowercase and stable.
    public let alias: String
    public let title: String
    public let summary: String
    public let symbolName: String
    /// Extra terms the surface should match on, beyond its alias and title.
    public let additionalKeywords: [String]

    public init(
        id: String,
        alias: String,
        title: String,
        summary: String,
        symbolName: String,
        additionalKeywords: [String] = []
    ) {
        self.id = id
        self.alias = alias
        self.title = title
        self.summary = summary
        self.symbolName = symbolName
        self.additionalKeywords = additionalKeywords
    }

    /// Everything Spotlight matches this surface on. `moonlight` is always
    /// present so the surface stays reachable by the app's own name when the
    /// alias has been forgotten.
    public var searchKeywords: [String] {
        var keywords = [alias, "moonlight", title.lowercased()]
        keywords.append(contentsOf: additionalKeywords)
        return keywords.reduce(into: [String]()) { unique, keyword in
            let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !unique.contains(normalized) else { return }
            unique.append(normalized)
        }
    }

    /// Names Spotlight may display or match instead of the title. The alias is
    /// uppercased here only for display; matching is case insensitive.
    public var alternateNames: [String] {
        [alias, alias.uppercased(), "Moonlight \(title)"]
    }
}

public enum MoonlightSurfaceID {
    public static let tools = "moonlight.surface.tools"
    public static let window = "moonlight.surface.window"
    public static let launcher = "moonlight.surface.launcher"
}

/// The surfaces Moonlight publishes to Spotlight.
///
/// Deliberately short: every entry here is a top level result competing with
/// the rest of the system, so a surface earns its place only when its alias
/// saves the user a step no tool entity already covers.
public enum MoonlightSurfaceRegistry {
    public static let tools = MoonlightSurface(
        id: MoonlightSurfaceID.tools,
        alias: "omt",
        title: "Tools",
        summary: "Open the Moonlight tool palette.",
        symbolName: "moon.stars",
        additionalKeywords: ["tools", "palette", "launcher", "open moonlight tools"]
    )

    /// The grid of installed applications.
    ///
    /// Earns its alias the same way the others do: Spotlight already finds
    /// individual apps, but nothing in the system reaches the arrangement of
    /// all of them in one keystroke.
    public static let launcher = MoonlightSurface(
        id: MoonlightSurfaceID.launcher,
        alias: "oml",
        title: "Launcher",
        summary: "Open the Moonlight application launcher.",
        symbolName: "square.grid.3x3",
        additionalKeywords: ["launcher", "apps", "applications", "launchpad", "grid"]
    )

    /// `window` is deliberately absent: it published a second alias for the
    /// same panel `tools` already opens, differing only in forcing the caret.
    /// One window earns one alias; the identifier stays known so the retired
    /// index item is withdrawn rather than left answering.
    public static let standard: [MoonlightSurface] = [tools, launcher]

    public static func surface(id: String) -> MoonlightSurface? {
        standard.first { $0.id == id }
    }

    /// Resolves a typed alias. Case and surrounding whitespace are ignored,
    /// because the text arrives from a search field, not from code.
    public static func surface(alias: String) -> MoonlightSurface? {
        let normalized = alias
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        return standard.first { $0.alias == normalized }
    }
}
