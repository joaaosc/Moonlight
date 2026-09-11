import CoreTransferable
import MoonlightDomain
import UniformTypeIdentifiers

/// What travels while an icon is being dragged: where it came from.
///
/// The position rather than the app's identifier, because the drop needs to
/// know which slot to vacate — the same app can only be in one place, but the
/// layout is addressed by slot, and looking the position up again after the
/// drop would race with any change made in between.
///
/// Carried as JSON, a type the system already knows. A custom uniform type
/// would have to be declared in the app's Info.plist to be usable, and this
/// payload never leaves the process.
struct LauncherDragPayload: Codable, Transferable {
    let page: Int
    let slot: Int

    init(_ position: LauncherPosition) {
        page = position.page
        slot = position.slot
    }

    var position: LauncherPosition {
        LauncherPosition(page: page, slot: slot)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
