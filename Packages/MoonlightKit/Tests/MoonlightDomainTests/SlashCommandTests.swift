import Testing
@testable import MoonlightDomain

@Suite("Slash commands")
struct SlashCommandTests {
    private let parser = SlashCommandParser()

    @Test("Parses a bare command")
    func parsesBareCommand() throws {
        let command = try parser.parse("/note")

        #expect(command.name == "note")
        #expect(command.arguments.isEmpty)
        #expect(command.typedText == "/note")
    }

    @Test("Keeps everything after the name as arguments")
    func parsesArguments() throws {
        let command = try parser.parse("  /note  Buy milk and bread  ")

        #expect(command.name == "note")
        #expect(command.arguments == "Buy milk and bread")
        #expect(command.typedText == "/note Buy milk and bread")
    }

    @Test("Names are case insensitive")
    func lowercasesName() throws {
        #expect(try parser.parse("/NOTE").name == "note")
    }

    @Test("Text without a slash is not a command")
    func rejectsMissingPrefix() {
        #expect(throws: SlashCommandError.missingPrefix) {
            try parser.parse("note this")
        }
    }

    @Test("A lone slash has no command name")
    func rejectsMissingName() {
        #expect(throws: SlashCommandError.missingName) {
            try parser.parse("/")
        }
        #expect(throws: SlashCommandError.missingName) {
            try parser.parse("/   ")
        }
    }

    @Test("Empty input is reported as empty, not as a syntax error")
    func rejectsEmpty() {
        #expect(throws: SlashCommandError.empty) {
            try parser.parse("   ")
        }
    }

    @Test("A name with punctuation is rejected")
    func rejectsInvalidName() {
        #expect(throws: SlashCommandError.invalidName("no+te")) {
            try parser.parse("/no+te")
        }
    }

    @Test("Hyphens and digits are valid in a name")
    func acceptsHyphenAndDigits() throws {
        #expect(try parser.parse("/base64-encode").name == "base64-encode")
    }

    @Test("No command is published yet")
    func catalogueIsEmpty() {
        // The command line ships before its commands. When this fails, the
        // catalogue gained an entry and the placeholder route in
        // OpenMoonlightCommandIntent needs a real implementation.
        #expect(SlashCommandRegistry.standard.isEmpty)
        #expect(SlashCommandRegistry.definition(named: "note") == nil)
        #expect(SlashCommandRegistry.completions(matching: "/no").isEmpty)
    }
}
