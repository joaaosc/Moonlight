import Foundation
import MoonlightDomain
import MoonlightInfrastructure

/// A catalogue that answers with whatever it was given.
///
/// Lives beside the launcher rather than in a test target because the snapshot
/// renderer needs it too: it draws the real views, and the real views ask a
/// catalogue for apps.
public struct StubAppCatalog: InstalledAppsCatalog {
    private let installed: [InstalledApp]

    public init(_ installed: [InstalledApp]) {
        self.installed = installed
    }

    /// Names only, pointing at bundles that need not exist. Enough for
    /// arrangement and search, which is what the stub is for; icons come back
    /// as the system's generic application icon.
    public static func named(_ names: [String]) -> StubAppCatalog {
        StubAppCatalog(
            names.map { name in
                InstalledApp(
                    bundleIdentifier: "com.example." + name.lowercased()
                        .replacingOccurrences(of: " ", with: "-"),
                    url: URL(fileURLWithPath: "/Applications/\(name).app"),
                    name: name
                )
            }
        )
    }

    public func apps() async throws -> [InstalledApp] { installed }
}
