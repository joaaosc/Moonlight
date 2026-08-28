import Foundation
import MoonlightDomain
import MoonlightInfrastructure
import Observation

@MainActor
@Observable
public final class MoonlightModel {
    public var text = ""
    public private(set) var executions: [Execution] = []
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false
    public private(set) var isLoading = false

    private let clientResult: Result<MoonlightRuntimeClient, MoonlightRuntimeError>

    public var inputCharacterCount: Int {
        normalizedInput.count
    }

    public var inputValidationMessage: String? {
        guard inputCharacterCount > CaptureNoteAction.maximumCharacterCount else {
            return nil
        }
        let excess = inputCharacterCount - CaptureNoteAction.maximumCharacterCount
        return "Remove \(excess.formatted()) characters to capture this note."
    }

    public var canCapture: Bool {
        !isWorking
            && !normalizedInput.isEmpty
            && inputCharacterCount <= CaptureNoteAction.maximumCharacterCount
    }

    public init() {
        clientResult = MoonlightRuntime.liveClient
    }

    public init(client: MoonlightRuntimeClient) {
        clientResult = .success(client)
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let client = try clientResult.get()
            executions = try await client.recent(50)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    public func capture() async -> Execution? {
        guard canCapture else { return nil }
        isWorking = true
        defer { isWorking = false }

        do {
            let client = try clientResult.get()
            let execution = try await client.execute(
                ActionRequest(actionID: MoonlightActionID.captureNote, input: text)
            )
            if execution.status == .succeeded {
                text = ""
                errorMessage = nil
            } else {
                errorMessage = execution.detail
            }
            executions = try await client.recent(50)
            return execution
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private var normalizedInput: String {
        text
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
