import MoonlightDomain

/// Immutable catalog that converts runtime descriptors into UI presentations.
public struct MoonlightToolCatalog: Sendable {
    public let descriptors: [ActionDescriptor]
    public let presentations: [MoonlightToolPresentation]

    public init(descriptors: [ActionDescriptor]) {
        let sorted = descriptors.sorted { $0.title < $1.title }
        self.descriptors = sorted
        presentations = sorted.map(MoonlightToolPresentation.init(descriptor:))
    }

    public func presentation(for id: String) -> MoonlightToolPresentation? {
        presentations.first { $0.id == id }
    }

    public func descriptor(for id: String) -> ActionDescriptor? {
        descriptors.first { $0.id == id }
    }
}
