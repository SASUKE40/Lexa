import Foundation

/// Normalizes raw model output into just the revised text.
nonisolated enum ResponseCleaner {
    /// Removes reasoning blocks. An unterminated block (still streaming) hides everything after it.
    static func stripThinking(_ text: String) -> String {
        var out = text.replacing(#/(?s)<(think|thinking|reasoning)>.*?</\1>/#, with: "")
        if let open = out.firstRange(of: #/(?s)<(think|thinking|reasoning)>.*$/#) {
            out.removeSubrange(open)
        }
        return out
    }

    static func clean(_ output: String, original: String) -> String {
        var text = trim(stripThinking(output))
        let trimmedOriginal = trim(original)

        if !trimmedOriginal.hasPrefix("```"),
           let match = text.wholeMatch(of: #/(?s)```[\w+-]*[ \t]*\n(.*?)\n?```/#) {
            text = trim(String(match.1))
        }

        if text.hasPrefix("<text>"), text.hasSuffix("</text>") {
            text = trim(String(text.dropFirst(6).dropLast(7)))
        }

        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        if lines.count == 2, isPreamble(lines[0]), !isPreamble(trimmedOriginal.split(separator: "\n").first ?? "") {
            text = trim(String(lines[1]))
        }

        for (open, close) in [("\"", "\""), ("\u{201C}", "\u{201D}")] where text.count >= 2 {
            if text.hasPrefix(open), text.hasSuffix(close), !trimmedOriginal.hasPrefix(open),
               !text.dropFirst().dropLast().contains(open), !text.dropFirst().dropLast().contains(close) {
                text = String(text.dropFirst().dropLast())
            }
        }

        let leading = original.prefix { $0.isWhitespace }
        let trailing = trimmedOriginal.isEmpty ? "" : String(original.reversed().prefix { $0.isWhitespace }.reversed())
        return leading + text + trailing
    }

    private static func isPreamble(_ line: Substring) -> Bool {
        line.wholeMatch(of: #/(?i)\s*(sure|certainly|of course|okay|ok|here(['’]s| is| are)|corrected|revised|improved|rewritten|translated|translation|fixed|edited|updated)\b.{0,80}:\s*/#) != nil
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
