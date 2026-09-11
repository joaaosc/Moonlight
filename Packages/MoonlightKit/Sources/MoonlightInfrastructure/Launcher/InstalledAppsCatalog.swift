import Foundation
import MoonlightDomain

/// Reads the applications installed on this machine.
///
/// A protocol because the grid must be testable without a real file system:
/// every rule about arrangement is about *which* apps exist, and a test that
/// depended on the machine's own `/Applications` would assert something
/// different on every machine.
public protocol InstalledAppsCatalog: Sendable {
    func apps() async throws -> [InstalledApp]
}

/// Walks the directories macOS keeps applications in.
///
/// Chosen over `NSMetadataQuery` after measuring both inside the sandbox: the
/// Spotlight query answered with 399 bundles against this directory walk's 110,
/// because it counts every nested bundle on the machine — helpers inside other
/// apps, copies in build directories, archives. A launcher wants the apps a
/// person would find in the Finder, which is what the directories hold.
public struct DirectoryAppCatalog: InstalledAppsCatalog {
    /// Where applications live. `~/Applications` is included because a
    /// per-user install is still installed.
    public static let standardDirectories: [URL] = {
        var directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        ]
        if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
            directories.append(home.appending(path: "Applications", directoryHint: .isDirectory))
        }
        return directories
    }()

    private let directories: [URL]
    /// How far to descend. Two levels reaches `/Applications/Utilities` and the
    /// folders people make, without walking into the bundles themselves.
    private let maximumDepth: Int

    public init(
        directories: [URL] = DirectoryAppCatalog.standardDirectories,
        maximumDepth: Int = 2
    ) {
        self.directories = directories
        self.maximumDepth = maximumDepth
    }

    public func apps() async throws -> [InstalledApp] {
        // Off the main actor: a hundred bundles is a hundred plist reads, and
        // this runs while a window is being presented.
        let directories = directories
        let maximumDepth = maximumDepth
        return await Task.detached(priority: .userInitiated) {
            // A private instance rather than `.default`: FileManager is not
            // Sendable, and the shared one belongs to whoever called us.
            let fileManager = FileManager()
            var found: [String: InstalledApp] = [:]
            for directory in directories {
                Self.collect(
                    in: directory,
                    depth: 1,
                    maximumDepth: maximumDepth,
                    fileManager: fileManager,
                    into: &found
                )
            }
            return Array(found.values)
        }.value
    }

    private static func collect(
        in directory: URL,
        depth: Int,
        maximumDepth: Int,
        fileManager: FileManager,
        into found: inout [String: InstalledApp]
    ) {
        guard depth <= maximumDepth,
              let contents = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles, .skipsPackageDescendants]
              )
        else { return }

        for url in contents {
            if url.pathExtension == "app" {
                guard let app = makeApp(at: url, fileManager: fileManager) else { continue }
                // First reading wins: the directories are listed in priority
                // order, so a user copy does not shadow the system one.
                if found[app.bundleIdentifier] == nil {
                    found[app.bundleIdentifier] = app
                }
                continue
            }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
            guard isDirectory == true else { continue }
            collect(
                in: url,
                depth: depth + 1,
                maximumDepth: maximumDepth,
                fileManager: fileManager,
                into: &found
            )
        }
    }

    /// An app with no bundle identifier is skipped: identity in the layout is
    /// the identifier, so there would be nothing to remember it by.
    private static func makeApp(at url: URL, fileManager: FileManager) -> InstalledApp? {
        guard let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier,
              !identifier.isEmpty
        else { return nil }

        return InstalledApp(
            bundleIdentifier: identifier,
            url: url,
            // The name the Finder shows, which already accounts for
            // localization and for the user hiding extensions.
            name: fileManager.displayName(atPath: url.path)
        )
    }
}
