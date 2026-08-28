import CoreFoundation
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
    private let historyFileURL: URL?
    @ObservationIgnored private var historyObserver: DarwinNotificationToken?

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
        historyFileURL = try? FileExecutionStore.defaultFileURL()
        observeExternalHistoryChanges()
    }

    public init(client: MoonlightRuntimeClient) {
        clientResult = .success(client)
        historyFileURL = nil
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

    var historyRevision: String? {
        guard
            let historyFileURL,
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: historyFileURL.path
            )
        else {
            return nil
        }

        let modificationDate = (attributes[.modificationDate] as? Date)?
            .timeIntervalSinceReferenceDate ?? 0
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        return "\(fileNumber):\(fileSize):\(modificationDate)"
    }

    private func observeExternalHistoryChanges() {
        historyObserver = DarwinNotificationToken(
            name: MoonlightStorage.historyDidChangeDarwinName
        ) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }
    }
}

private final class DarwinNotificationToken: @unchecked Sendable {
    private let name: CFNotificationName
    private let onChange: @Sendable () -> Void

    init(name: String, onChange: @escaping @Sendable () -> Void) {
        self.name = CFNotificationName(rawValue: name as CFString)
        self.onChange = onChange

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let token = Unmanaged<DarwinNotificationToken>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                token.onChange()
            },
            self.name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            name,
            nil
        )
    }
}
