import Testing
@testable import Lexa

struct TextDiffTests {
    @Test func unchangedTextHasOnlySameSegments() {
        let segments = TextDiff.diff("Hello world.", "Hello world.")
        #expect(segments == [DiffSegment(.same, "Hello world.")])
        #expect(TextDiff.isUnchanged(segments))
    }

    @Test func adjacentReplacementsAreGrouped() {
        let segments = TextDiff.diff("teh cat", "the dog")
        #expect(segments == [DiffSegment(.removed, "teh cat"), DiffSegment(.added, "the dog")])
    }

    @Test func singleWordFix() {
        let segments = TextDiff.diff("I like teh park.", "I like the park.")
        #expect(segments == [
            DiffSegment(.same, "I like "),
            DiffSegment(.removed, "teh"),
            DiffSegment(.added, "the"),
            DiffSegment(.same, " park."),
        ])
    }

    @Test func insertionAndPunctuation() {
        let segments = TextDiff.diff("Hello world", "Hello, world.")
        #expect(segments.contains(DiffSegment(.added, ",")))
        #expect(segments.contains(DiffSegment(.added, ".")))
        #expect(!segments.contains { $0.kind == .removed })
    }

    @Test func deletion() {
        let segments = TextDiff.diff("This is is a test", "This is a test")
        #expect(segments.filter { $0.kind == .removed }.map(\.text).joined().contains("is"))
        #expect(!segments.contains { $0.kind == .added })
    }

    @Test(arguments: [
        ("Their going to the libary tomorow.", "They're going to the library tomorrow."),
        ("a b c d", "a x c y"),
        ("", "New text"),
        ("Old text", ""),
        ("Line one\nline two", "Line one.\n\nLine two!"),
        ("I went store", "I went to the store"),
        ("我爱你们", "我爱他们"),
        ("  padded  ", "padded"),
    ])
    func renderedNewTextMatchesResult(old: String, new: String) {
        #expect(TextDiff.newText(TextDiff.diff(old, new)) == new)
    }

    @Test func tokenizerKeepsContractionsAndSplitsCJK() {
        #expect(TextDiff.tokenize("don't stop!") == ["don't", " ", "stop", "!"])
        #expect(TextDiff.tokenize("我爱你") == ["我", "爱", "你"])
        #expect(TextDiff.tokenize("a  b") == ["a", "  ", "b"])
    }
}
