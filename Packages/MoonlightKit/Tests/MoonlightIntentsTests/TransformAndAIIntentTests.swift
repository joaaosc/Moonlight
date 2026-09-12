import AppIntents
import MoonlightDomain
import MoonlightIntents
import Testing

@Suite("Transform and AI intents")
struct TransformAndAIIntentTests {
    @Test("Hash, URL and timestamp tools are published like the other text tools")
    func transformIntentsContract() {
        requireAppIntent(HashTextIntent.self)
        requireAppIntent(TransformURLIntent.self)
        requireAppIntent(ConvertTimestampIntent.self)

        #expect(HashTextIntent.isDiscoverable)
        #expect(TransformURLIntent.isDiscoverable)
        #expect(ConvertTimestampIntent.isDiscoverable)
        for targets in [
            HashTextIntent.allowedExecutionTargets,
            TransformURLIntent.allowedExecutionTargets,
            ConvertTimestampIntent.allowedExecutionTargets,
        ] {
            #expect(targets.contains(.appIntentsExtension))
            #expect(targets.contains(.main))
        }
        #expect(HashTextIntent.supportedModes.contains(.background))
        #expect(TransformURLIntent.supportedModes.contains(.background))
        #expect(ConvertTimestampIntent.supportedModes.contains(.background))
        #expect(HashAlgorithmAppEnum.sha512.algorithm == .sha512)
        #expect(URLOperationAppEnum.decode.operation == .decode)
        #expect(HashTextIntent(text: "a").algorithm == .sha256)
        #expect(TransformURLIntent(text: "a").operation == .encode)
        #expect(ConvertTimestampIntent(text: "1773000000").text == "1773000000")
    }

    @Test("Summarize is a discoverable background intent for Siri and Apple Intelligence")
    func summarizeIntentContract() {
        requireAppIntent(SummarizeTextIntent.self)

        #expect(SummarizeTextIntent.isDiscoverable)
        #expect(SummarizeTextIntent.supportedModes.contains(.background))
        #expect(SummarizeTextIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(SummarizeTextIntent.allowedExecutionTargets.contains(.main))
        #expect(SummarizeTextIntent(text: "Hello").text == "Hello")
    }

    @Test("Timer is published like the other text tools")
    func timerIntentContract() {
        requireAppIntent(StartTimerIntent.self)

        #expect(StartTimerIntent.isDiscoverable)
        #expect(StartTimerIntent.supportedModes.contains(.background))
        #expect(StartTimerIntent.allowedExecutionTargets.contains(.appIntentsExtension))
        #expect(StartTimerIntent.allowedExecutionTargets.contains(.main))
        #expect(StartTimerIntent(duration: "25m").duration == "25m")
    }

    /// The summary moved into the domain when it became a registered action,
    /// so the rule is asserted where it now lives.
    @Test("Summarize is extractive, deterministic and empty-aware")
    func summarizeLogic() {
        #expect(SummarizeTextAction.extractiveSummary(of: "   ") == "")
        #expect(SummarizeTextAction.extractiveSummary(of: "Hello world. Second sentence") == "Hello world. Second sentence")
        let long = String(repeating: "word ", count: 100)
        #expect(SummarizeTextAction.extractiveSummary(of: long).count <= 280)
    }

    @Test("Summarize runs through the registry like the other text tools")
    func summarizeIsRegistered() async throws {
        let registry = ActionRegistry.standard
        let handler = try #require(registry.definition(id: MoonlightActionID.summarizeText))

        #expect(handler.presentation.alias == "summarize")

        let output = try await SummarizeTextAction().perform(
            request: ActionRequest(
                actionID: MoonlightActionID.summarizeText,
                input: "First sentence. Second sentence."
            )
        )

        #expect(output.value.text == "First sentence. Second sentence")
    }

    @Test("Summarize refuses empty input instead of returning nothing")
    func summarizeRejectsEmptyInput() async {
        await #expect(throws: ActionError.emptyInput) {
            try await SummarizeTextAction().perform(
                request: ActionRequest(actionID: MoonlightActionID.summarizeText, input: "   ")
            )
        }
    }
}

private func requireAppIntent<T: AppIntent>(_ type: T.Type) {}
