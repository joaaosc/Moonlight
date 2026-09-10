import Foundation
import Testing
@testable import MoonlightShortcuts

/// Checks the hand-written bridge against the scripting dictionary installed on
/// this Mac.
///
/// The bridge declares Objective-C selectors by hand, so a name that drifts
/// would make a property read as `nil` and silently drop shortcuts. Generating
/// the header with `sdef | sdp` compares the declarations against the real
/// dictionary without sending a single Apple Event, which needs no consent.
@Suite("Shortcuts scripting dictionary contract")
struct ShortcutsDictionaryContractTests {
    private static let shortcutsPath = "/System/Applications/Shortcuts.app"

    private func generatedHeader() throws -> String {
        try #require(
            FileManager.default.fileExists(atPath: Self.shortcutsPath),
            "Shortcuts is not installed on this machine."
        )

        let directory = URL.temporaryDirectory
            .appending(path: "MoonlightShortcutsDictionary")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sdef = Process()
        sdef.executableURL = URL(filePath: "/usr/bin/sdef")
        sdef.arguments = [Self.shortcutsPath]
        let sdp = Process()
        sdp.executableURL = URL(filePath: "/usr/bin/sdp")
        sdp.arguments = ["-fh", "--basename", "Shortcuts", "-o", directory.path]

        let pipe = Pipe()
        sdef.standardOutput = pipe
        sdp.standardInput = pipe
        sdef.standardError = FileHandle.nullDevice
        sdp.standardError = FileHandle.nullDevice

        try sdef.run()
        try sdp.run()
        sdef.waitUntilExit()
        sdp.waitUntilExit()

        let headerURL = directory.appending(path: "Shortcuts.h")
        try #require(
            FileManager.default.fileExists(atPath: headerURL.path),
            "sdef/sdp did not produce a header."
        )
        return try String(contentsOf: headerURL, encoding: .utf8)
    }

    @Test("Every declared property exists in the installed dictionary")
    func declaredPropertiesMatch() throws {
        let header = try generatedHeader()

        // Read-only properties the listing depends on.
        #expect(header.contains("NSString *name;"))
        #expect(header.contains("NSString *subtitle;"))
        #expect(header.contains("- (NSString *) id;"))
        #expect(header.contains("BOOL acceptsInput;"))
        #expect(header.contains("NSInteger actionCount;"))
        // The element accessor the client calls to enumerate the library.
        #expect(header.contains("shortcuts;"))
    }

    @Test("The run command keeps the selector the bridge sends")
    func runSelectorMatches() throws {
        let header = try generatedHeader()

        #expect(header.contains("- (id) runWithInput:(id)withInput;"))
    }

    @Test("The access group the entitlement names still guards the dictionary")
    func accessGroupMatches() throws {
        let sdef = Process()
        sdef.executableURL = URL(filePath: "/usr/bin/sdef")
        sdef.arguments = [Self.shortcutsPath]
        let pipe = Pipe()
        sdef.standardOutput = pipe
        sdef.standardError = FileHandle.nullDevice
        try sdef.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        sdef.waitUntilExit()
        let dictionary = String(decoding: data, as: UTF8.self)

        #expect(dictionary.contains("com.apple.shortcuts.run"))
        #expect(ShortcutsEventsClient.accessGroup == "com.apple.shortcuts.run")
        #expect(ShortcutsEventsClient.bundleIdentifier == "com.apple.shortcuts.events")
    }
}
