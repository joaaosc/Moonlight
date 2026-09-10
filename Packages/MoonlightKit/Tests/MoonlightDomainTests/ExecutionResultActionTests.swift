import Foundation
import Testing
@testable import MoonlightDomain

@Suite("Result actions")
struct ExecutionResultActionTests {
    private func execution(
        value: ActionOutputValue,
        detail: String,
        status: ExecutionStatus = .succeeded
    ) -> Execution {
        Execution(
            id: UUID(),
            actionID: "tool",
            actionTitle: "Tool",
            input: "",
            summary: "Done",
            detail: detail,
            status: status,
            createdAt: Date(),
            output: ActionOutput(summary: "Done", detail: detail, value: value)
        )
    }

    @Test("A result with no value offers no actions")
    func offersNothingWithoutValue() {
        let result = execution(value: ActionOutputValue.none, detail: "Picker opened")

        #expect(result.resultActions.isEmpty)
    }

    @Test("A failed execution offers no actions")
    func offersNothingWhenFailed() {
        let result = execution(value: .text("boom"), detail: "boom", status: .failed)

        #expect(result.resultActions.isEmpty)
    }

    @Test("Text can be copied and saved as plain text")
    func offersCopyAndSave() throws {
        let actions = execution(value: .text("Moonlight"), detail: "Moonlight").resultActions

        #expect(actions.map(\.id) == ["copy", "save"])
        guard case let .save(_, fileName) = actions[1] else {
            Issue.record("Expected a save action")
            return
        }
        #expect(fileName.hasSuffix(".txt"))
    }

    @Test("JSON is saved with a JSON file name")
    func suggestsJSONFileName() {
        let actions = execution(value: .json("{}"), detail: "{}").resultActions

        guard case let .save(_, fileName) = actions[1] else {
            Issue.record("Expected a save action")
            return
        }
        #expect(fileName.hasSuffix(".json"))
    }

    @Test("Only a complete web address is openable")
    func offersOpenForURLsOnly() {
        let openable = execution(
            value: .text("https://example.com/a"),
            detail: "https://example.com/a"
        ).resultActions
        let sentence = execution(
            value: .text("see https://example.com"),
            detail: "see https://example.com"
        ).resultActions
        let scheme = execution(
            value: .text("file:///tmp/x"),
            detail: "file:///tmp/x"
        ).resultActions

        #expect(openable.map(\.id) == ["copy", "save", "open"])
        #expect(sentence.map(\.id) == ["copy", "save"])
        #expect(scheme.map(\.id) == ["copy", "save"])
    }

    @Test("Historical records without typed output stay copyable")
    func supportsHistoricalRecords() {
        let historical = Execution(
            id: UUID(),
            actionID: "tool",
            actionTitle: "Tool",
            input: "",
            summary: "Done",
            detail: "Moonlight",
            status: .succeeded,
            createdAt: Date()
        )

        #expect(historical.resultActions.map(\.id) == ["copy", "save"])
    }
}
