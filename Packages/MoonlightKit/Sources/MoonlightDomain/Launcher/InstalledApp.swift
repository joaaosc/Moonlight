import Foundation

/// An application the launcher can show and open.
///
/// Identity is the bundle identifier, not the URL: an app that moves between
/// `/Applications` and `~/Applications`, or that is replaced by an update, is
/// still the same app to the user and must keep its place in the grid. Apps
/// without a bundle identifier are not representable here, which is deliberate
/// — there would be nothing stable to remember them by.
public struct InstalledApp: Sendable, Hashable, Identifiable, Codable {
    public let bundleIdentifier: String
    /// Where the bundle was when the catalogue was read. Not part of identity,
    /// because it changes for reasons the user does not think of as a change.
    public let url: URL
    /// The name as the Finder shows it, already localized by the system.
    public let name: String

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, url: URL, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.name = name
    }

    /// Two apps are the same app when they carry the same identifier. The URL
    /// and the name are allowed to differ, and the newer reading wins.
    public static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}
