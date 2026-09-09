import AppIntents
import ExtensionFoundation
import MoonlightIntents

struct MoonlightExtensionIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MoonlightIntentsPackage.self]
    }
}

@main
struct MoonlightAppIntentsExtension: AppIntentsExtension {}
