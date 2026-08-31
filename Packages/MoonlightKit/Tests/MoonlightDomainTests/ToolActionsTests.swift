import Foundation
import MoonlightDomain
import Testing

@Suite("Initial tool contracts")
struct ToolActionsTests {
    private let instant = Date(timeIntervalSince1970: 1_800_000_100)
    private let executionID = UUID(
        uuidString: "11111111-2222-4333-8444-555555555555"
    )!

    @Test("Registers each stable ID exactly once with its idempotence")
    func registersStableIDs() {
        let descriptors = ActionRegistry.standard.descriptors
        let expectedIDs = Set([
            MoonlightActionID.captureNote,
            MoonlightActionID.openColorPicker,
            MoonlightActionID.cleanText,
            MoonlightActionID.formatJSON,
            MoonlightActionID.generateUUID,
            MoonlightActionID.base64Text,
        ])

        #expect(Set(descriptors.map(\.id)) == expectedIDs)
        #expect(descriptors.count == expectedIDs.count)

        let idempotence = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.id, $0.isIdempotent) }
        )
        #expect(idempotence[MoonlightActionID.cleanText] == true)
        #expect(idempotence[MoonlightActionID.formatJSON] == true)
        #expect(idempotence[MoonlightActionID.generateUUID] == false)
        #expect(idempotence[MoonlightActionID.base64Text] == true)
    }

    @Test("Clean Text normalizes NFC and preserves internal whitespace")
    func cleansTextConservatively() async throws {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)
        let input = "\u{3000}Cafe\u{301} ☾ \n\tline  two\u{3000}"

        let execution = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.cleanText, input: input)
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail == "Café ☾ \n\tline  two")
        #expect(execution.parameters == .empty)
        #expect(await store.execution(id: executionID) == execution)
    }

    @Test("Clean Text rejects a result that is empty after trimming")
    func cleanTextRejectsBlankInput() async throws {
        let execution = try await makeRunner().execute(
            ActionRequest(actionID: MoonlightActionID.cleanText, input: " \n\t ")
        )

        #expect(execution.status == .failed)
        #expect(execution.detail == ActionError.emptyInput.localizedDescription)
    }

    @Test("Input limits are measured in UTF-8 bytes")
    func enforcesUTF8ByteLimit() async throws {
        let runner = makeRunner()
        let acceptedInput = String(
            repeating: "a",
            count: MoonlightToolLimits.maximumInputByteCount
        )
        let rejectedInput = String(
            repeating: "🌕",
            count: MoonlightToolLimits.maximumInputByteCount / 4 + 1
        )

        let accepted = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.cleanText, input: acceptedInput)
        )
        let rejected = try await runner.execute(
            ActionRequest(actionID: MoonlightActionID.cleanText, input: rejectedInput)
        )

        #expect(accepted.status == .succeeded)
        #expect(rejected.status == .failed)
        #expect(
            rejected.detail == ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            ).localizedDescription
        )
    }

    @Test("Format JSON sorts keys and uses locale-independent numbers")
    func formatsJSON() async throws {
        let execution = try await makeRunner().execute(
            ActionRequest(
                actionID: MoonlightActionID.formatJSON,
                input: "  {\"z\":1.5,\"a\":{\"line\":\"one\\ntwo\"}}  "
            )
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail.contains("\n"))
        #expect(execution.detail.contains("1.5"))
        #expect(!execution.detail.contains("1,5"))
        #expect(execution.detail.contains("one\\ntwo"))
        #expect(!execution.detail.hasSuffix("\n"))

        let firstKey = execution.detail.range(of: "\"a\"")
        let lastKey = execution.detail.range(of: "\"z\"")
        #expect(firstKey != nil)
        #expect(lastKey != nil)
        if let firstKey, let lastKey {
            #expect(firstKey.lowerBound < lastKey.lowerBound)
        }
    }

    @Test(
        "Format JSON rejects invalid roots and syntax",
        arguments: [
            JSONFailureCase(input: "42", error: .jsonRootMustBeContainer),
            JSONFailureCase(input: "{\"value\":}", error: .invalidJSON),
            JSONFailureCase(input: "{\"value\":1,}", error: .invalidJSON),
            JSONFailureCase(
                input: "\u{00A0}{\"value\":1}\u{00A0}",
                error: .invalidJSON
            ),
            JSONFailureCase(
                input: "{\"value\": 1 // JSON5 comment\n}",
                error: .invalidJSON
            ),
        ]
    )
    func rejectsInvalidJSON(testCase: JSONFailureCase) async throws {
        let execution = try await makeRunner().execute(
            ActionRequest(
                actionID: MoonlightActionID.formatJSON,
                input: testCase.input
            )
        )

        #expect(execution.status == .failed)
        #expect(execution.detail == testCase.error.localizedDescription)
    }

    @Test("Format JSON rejects excessive nesting")
    func rejectsDeepJSON() async throws {
        let depth = MoonlightToolLimits.maximumJSONNestingDepth + 1
        let input = String(repeating: "[", count: depth)
            + "0"
            + String(repeating: "]", count: depth)

        let execution = try await makeRunner().execute(
            ActionRequest(actionID: MoonlightActionID.formatJSON, input: input)
        )

        #expect(execution.status == .failed)
        #expect(
            execution.detail == ToolActionError.jsonTooDeep(
                limit: MoonlightToolLimits.maximumJSONNestingDepth
            ).localizedDescription
        )
    }

    @Test("Format JSON rejects pretty-printed output above its limit")
    func rejectsExpandedJSONOutput() async throws {
        let elementCount = 110_000
        let input = "["
            + String(repeating: "0,", count: elementCount - 1)
            + "0]"

        let execution = try await makeRunner().execute(
            ActionRequest(actionID: MoonlightActionID.formatJSON, input: input)
        )

        #expect(input.utf8.count < MoonlightToolLimits.maximumInputByteCount)
        #expect(execution.status == .failed)
        #expect(
            execution.detail == ActionError.outputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumOutputByteCount
            ).localizedDescription
        )
    }

    @Test("Generate UUID emits a canonical lowercase version 4 value")
    func generatesUUID() async throws {
        let generatedUUID = UUID(
            uuidString: "01234567-89AB-4CDE-8123-456789ABCDEF"
        )!
        let registry = ActionRegistry(
            handlers: [GenerateUUIDAction(generator: { generatedUUID })]
        )
        let execution = try await makeRunner(registry: registry).execute(
            ActionRequest(actionID: MoonlightActionID.generateUUID, input: " \n")
        )

        #expect(execution.status == .succeeded)
        #expect(execution.detail == "01234567-89ab-4cde-8123-456789abcdef")
        #expect(UUID(uuidString: execution.detail) == generatedUUID)
        #expect(execution.detail.split(separator: "-")[2].first == "4")
    }

    @Test("Default UUID generator produces the RFC 4122 version and variant")
    func defaultUUIDIsVersion4() async throws {
        let output = try await GenerateUUIDAction().perform(
            request: ActionRequest(
                actionID: MoonlightActionID.generateUUID,
                input: ""
            )
        )
        let components = output.detail.split(separator: "-")

        #expect(UUID(uuidString: output.detail) != nil)
        #expect(components.count == 5)
        if components.count == 5 {
            #expect(components[2].first == "4")
            if let variantPrefix = components[3].first {
                #expect("89ab".contains(variantPrefix))
            }
        }
    }

    @Test("Generate UUID rejects actual input")
    func uuidRejectsInput() async throws {
        let execution = try await makeRunner().execute(
            ActionRequest(actionID: MoonlightActionID.generateUUID, input: "namespace")
        )

        #expect(execution.status == .failed)
        #expect(execution.detail == ToolActionError.unexpectedInput.localizedDescription)
    }

    @Test(
        "Base64 round-trips exact UTF-8 text",
        arguments: ["Moonlight", "Café 🌕\n", "", " \t"]
    )
    func roundTripsBase64(input: String) async throws {
        let action = TransformBase64Action()
        let encoded = try await action.perform(
            request: .transformBase64(input: input, operation: .encode)
        )
        let decoded = try await action.perform(
            request: .transformBase64(input: encoded.detail, operation: .decode)
        )

        #expect(decoded.detail == input)
    }

    @Test("Base64 uses the standard canonical alphabet and persists its operation")
    func encodesCanonicalBase64() async throws {
        let store = InMemoryExecutionStore()
        let request = ActionRequest.transformBase64(
            input: "Moonlight",
            operation: .encode
        )
        let execution = try await makeRunner(store: store).execute(request)

        #expect(execution.status == .succeeded)
        #expect(execution.detail == "TW9vbmxpZ2h0")
        #expect(execution.parameters == request.parameters)
        #expect(await store.execution(id: executionID) == execution)
    }

    @Test(
        "Base64 rejects noncanonical or binary values",
        arguments: [
            Base64FailureCase(input: "not base64!", error: .invalidBase64),
            Base64FailureCase(input: "TW9v\nbmxpZ2h0", error: .invalidBase64),
            Base64FailureCase(input: "TQ", error: .invalidBase64),
            Base64FailureCase(input: "____", error: .invalidBase64),
            Base64FailureCase(input: "/w==", error: .decodedTextIsNotUTF8),
        ]
    )
    func rejectsInvalidBase64(testCase: Base64FailureCase) async {
        let action = TransformBase64Action()

        await #expect(throws: testCase.error) {
            try await action.perform(
                request: .transformBase64(input: testCase.input, operation: .decode)
            )
        }
    }

    @Test("Base64 validates its operation parameter envelope")
    func validatesBase64Parameters() async {
        let action = TransformBase64Action()

        await #expect(
            throws: ToolActionError.missingParameter(
                TransformBase64Action.operationParameterName
            )
        ) {
            try await action.perform(
                request: ActionRequest(
                    actionID: MoonlightActionID.base64Text,
                    input: "Moonlight"
                )
            )
        }

        await #expect(
            throws: ToolActionError.invalidParameter(
                TransformBase64Action.operationParameterName
            )
        ) {
            try await action.perform(
                request: ActionRequest(
                    actionID: MoonlightActionID.base64Text,
                    input: "Moonlight",
                    parameters: ActionParameters(
                        values: [TransformBase64Action.operationParameterName: "compress"]
                    )
                )
            )
        }

        await #expect(throws: ToolActionError.unexpectedParameters) {
            try await action.perform(
                request: ActionRequest(
                    actionID: MoonlightActionID.base64Text,
                    input: "Moonlight",
                    parameters: ActionParameters(
                        values: [
                            TransformBase64Action.operationParameterName: "encode",
                            "extra": "value",
                        ]
                    )
                )
            )
        }
    }

    @Test(
        "Every initial tool rejects input above the shared byte limit",
        arguments: [
            OversizedInputCase(actionID: MoonlightActionID.cleanText),
            OversizedInputCase(actionID: MoonlightActionID.formatJSON),
            OversizedInputCase(actionID: MoonlightActionID.generateUUID),
            OversizedInputCase(
                actionID: MoonlightActionID.base64Text,
                parameters: ActionParameters(
                    values: [TransformBase64Action.operationParameterName: "encode"]
                )
            ),
        ]
    )
    func rejectsOversizedInput(testCase: OversizedInputCase) async throws {
        let input = String(
            repeating: "a",
            count: MoonlightToolLimits.maximumInputByteCount + 1
        )
        let execution = try await makeRunner().execute(
            ActionRequest(
                actionID: testCase.actionID,
                input: input,
                parameters: testCase.parameters
            )
        )

        #expect(execution.status == .failed)
        #expect(
            execution.detail == ActionError.inputTooLarge(
                limitInBytes: MoonlightToolLimits.maximumInputByteCount
            ).localizedDescription
        )
    }

    @Test("Rejects unknown parameter schema and preserves it in the failure")
    func rejectsUnknownParameterSchema() async throws {
        let request = ActionRequest(
            actionID: MoonlightActionID.cleanText,
            input: "Moonlight",
            parameters: ActionParameters(schemaVersion: 2)
        )

        let execution = try await makeRunner().execute(request)

        #expect(execution.status == .failed)
        #expect(execution.parameters == request.parameters)
        #expect(
            execution.detail == ActionError.unsupportedParameterSchema(2)
                .localizedDescription
        )
    }

    @Test("Cancellation is rethrown without persisting an execution")
    func cancellationIsNotFailure() async {
        let store = InMemoryExecutionStore()
        let runner = makeRunner(store: store)
        let task = Task {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            return try await runner.execute(
                ActionRequest(actionID: MoonlightActionID.cleanText, input: "Moonlight")
            )
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await store.recent(limit: 1).isEmpty)
    }

    private func makeRunner(
        registry: ActionRegistry = .standard,
        store: any ExecutionStore = InMemoryExecutionStore()
    ) -> ActionRunner {
        ActionRunner(
            registry: registry,
            store: store,
            clock: { instant },
            identifierGenerator: { executionID }
        )
    }
}

struct JSONFailureCase: Sendable, CustomTestStringConvertible {
    let input: String
    let error: ToolActionError

    var testDescription: String {
        error.localizedDescription
    }
}

struct Base64FailureCase: Sendable, CustomTestStringConvertible {
    let input: String
    let error: ToolActionError

    var testDescription: String {
        error.localizedDescription
    }
}

struct OversizedInputCase: Sendable, CustomTestStringConvertible {
    let actionID: String
    let parameters: ActionParameters

    init(
        actionID: String,
        parameters: ActionParameters = .empty
    ) {
        self.actionID = actionID
        self.parameters = parameters
    }

    var testDescription: String {
        actionID
    }
}
