import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

@MainActor
@Observable
public final class MoonlightToolPaletteModel {
    public private(set) var descriptors: [ActionDescriptor] = []
    public var query = ""
    public var input = ""
    public var base64Operation: Base64TextOperation = .encode
    public private(set) var result: Execution?
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false
    public let preferredActionID: String?

    private let client: MoonlightRuntimeClient
    private let openColorPicker: @MainActor () -> Void

    public init(
        client: MoonlightRuntimeClient,
        preferredActionID: String? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        self.client = client
        self.preferredActionID = preferredActionID
        self.openColorPicker = onOpenColorPicker
        descriptors = client.descriptors().sorted { $0.title < $1.title }
    }

    public convenience init(
        preferredActionID: String? = nil,
        onOpenColorPicker: @escaping @MainActor () -> Void = {}
    ) {
        switch MoonlightRuntime.liveClient {
        case let .success(client):
            self.init(
                client: client,
                preferredActionID: preferredActionID,
                onOpenColorPicker: onOpenColorPicker
            )
        case let .failure(error):
            self.init(client: .init(
                descriptors: { [] },
                execute: { _ in throw error },
                execution: { _ in nil },
                recent: { _ in [] }
            ), preferredActionID: preferredActionID, onOpenColorPicker: onOpenColorPicker)
            errorMessage = error.localizedDescription
        }
    }

    public var filteredDescriptors: [ActionDescriptor] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return descriptors }
        return descriptors.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.summary.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    public func execute(_ descriptor: ActionDescriptor) async {
        guard !isWorking else { return }

        isWorking = true
        result = nil
        errorMessage = nil
        defer { isWorking = false }

        let request: ActionRequest
        if descriptor.id == MoonlightActionID.base64Text {
            request = .transformBase64(input: input, operation: base64Operation)
        } else {
            request = ActionRequest(
                actionID: descriptor.id,
                input: input(for: descriptor)
            )
        }

        do {
            let execution = try await client.execute(request)
            if execution.status == .succeeded {
                result = execution
                if descriptor.id == MoonlightActionID.openColorPicker {
                    openColorPicker()
                }
            } else {
                errorMessage = execution.detail
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func acceptsInput(_ descriptor: ActionDescriptor) -> Bool {
        switch descriptor.id {
        case MoonlightActionID.generateUUID, MoonlightActionID.openColorPicker:
            false
        default:
            true
        }
    }

    private func input(for descriptor: ActionDescriptor) -> String {
        acceptsInput(descriptor) ? input : ""
    }
}
