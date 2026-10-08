import Testing
@testable import Lexa

struct ResponseCleanerTests {
    @Test func removesThinkingBlocks() {
        let output = "<think>The user wants a fix.</think>\nThey're here."
        #expect(ResponseCleaner.clean(output, original: "Their here.") == "They're here.")
    }

    @Test func hidesUnterminatedThinkingWhileStreaming() {
        #expect(ResponseCleaner.stripThinking("<think>still reasoning") == "")
        #expect(ResponseCleaner.stripThinking("Done <thinking>a</thinking>text") == "Done text")
    }

    @Test func stripsCodeFences() {
        #expect(ResponseCleaner.clean("```\nHello there.\n```", original: "hello there") == "Hello there.")
        #expect(ResponseCleaner.clean("```text\nHello there.\n```", original: "hello there") == "Hello there.")
    }

    @Test func keepsFencesWhenOriginalHadThem() {
        let fenced = "```\ncode\n```"
        #expect(ResponseCleaner.clean(fenced, original: fenced) == fenced)
    }

    @Test func stripsPreamble() {
        let output = "Here is the corrected text:\nI have a cat."
        #expect(ResponseCleaner.clean(output, original: "I has a cat.") == "I have a cat.")
        #expect(ResponseCleaner.clean("Sure! Here's the revised version:\n\nHi.", original: "hi") == "Hi.")
    }

    @Test func keepsLegitimateFirstLineWithColon() {
        let text = "Agenda:\n- Item one"
        #expect(ResponseCleaner.clean(text, original: "Agenda:\n- item one") == text)
    }

    @Test func stripsWrappingQuotesOnlyWhenAdded() {
        #expect(ResponseCleaner.clean("\"Hello there.\"", original: "hello there") == "Hello there.")
        #expect(ResponseCleaner.clean("\u{201C}Hello.\u{201D}", original: "hello") == "Hello.")
        #expect(ResponseCleaner.clean("\"Hi,\" she said.", original: "\"hi\" she said") == "\"Hi,\" she said.")
        #expect(ResponseCleaner.clean("\"Quoted\"", original: "\"quoted\"") == "\"Quoted\"")
    }

    @Test func stripsEchoedTextTags() {
        #expect(ResponseCleaner.clean("<text>\nFixed.\n</text>", original: "fixed") == "Fixed.")
    }

    @Test func preservesSurroundingWhitespaceOfOriginal() {
        #expect(ResponseCleaner.clean("Hello.\n", original: "  hello \n") == "  Hello. \n")
        #expect(ResponseCleaner.clean("  Hello.  ", original: "hello") == "Hello.")
    }
}
