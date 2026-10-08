import Foundation

nonisolated struct DiffSegment: Equatable, Sendable {
    enum Kind: Sendable { case same, added, removed }

    let kind: Kind
    let text: String

    init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Word-level diff used to highlight what the model changed.
nonisolated enum TextDiff {
    static func diff(_ old: String, _ new: String) -> [DiffSegment] {
        let a = tokenize(old)
        let b = tokenize(new)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in b.difference(from: a) {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }

        var raw: [DiffSegment] = []
        var i = 0
        var j = 0
        while i < a.count || j < b.count {
            if i < a.count, removed.contains(i) {
                raw.append(DiffSegment(.removed, a[i]))
                i += 1
            } else if j < b.count, inserted.contains(j) {
                raw.append(DiffSegment(.added, b[j]))
                j += 1
            } else {
                guard i < a.count, j < b.count else { break }
                raw.append(DiffSegment(.same, a[i]))
                i += 1
                j += 1
            }
        }
        return group(raw)
    }

    static func isUnchanged(_ segments: [DiffSegment]) -> Bool {
        segments.allSatisfy { $0.kind == .same }
    }

    /// Text the user ends up with (everything except removals).
    static func newText(_ segments: [DiffSegment]) -> String {
        segments.filter { $0.kind != .removed }.map(\.text).joined()
    }

    /// Words, whitespace runs, single CJK characters and single symbols.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentClass: CharClass?
        for character in text {
            let cls = CharClass(character)
            if cls == currentClass, cls.groups {
                current.append(character)
            } else {
                if !current.isEmpty { tokens.append(current) }
                current = String(character)
                currentClass = cls
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Merges adjacent segments into "removed, then added" runs. Whitespace sitting between
    /// two changes is folded into the run so "teh cat" -> "the dog" reads as one replacement.
    private static func group(_ raw: [DiffSegment]) -> [DiffSegment] {
        var result: [DiffSegment] = []
        var removedRun = ""
        var addedRun = ""

        func append(_ segment: DiffSegment) {
            if let last = result.last, last.kind == segment.kind {
                result[result.count - 1] = DiffSegment(last.kind, last.text + segment.text)
            } else {
                result.append(segment)
            }
        }

        func flush() {
            if !removedRun.allSatisfy(\.isWhitespace) { append(DiffSegment(.removed, removedRun)) }
            if addedRun.allSatisfy(\.isWhitespace) {
                if !addedRun.isEmpty { append(DiffSegment(.same, addedRun)) }
            } else {
                append(DiffSegment(.added, addedRun))
            }
            removedRun = ""
            addedRun = ""
        }

        for (index, segment) in raw.enumerated() {
            switch segment.kind {
            case .removed: removedRun += segment.text
            case .added: addedRun += segment.text
            case .same:
                let inRun = !removedRun.isEmpty || !addedRun.isEmpty
                let nextIsChange = index + 1 < raw.count && raw[index + 1].kind != .same
                if inRun, nextIsChange, segment.text.allSatisfy(\.isWhitespace) {
                    removedRun += segment.text
                    addedRun += segment.text
                } else {
                    if inRun { flush() }
                    append(segment)
                }
            }
        }
        if !removedRun.isEmpty || !addedRun.isEmpty { flush() }
        return result
    }

    private enum CharClass {
        case word, space, ideograph, symbol

        init(_ character: Character) {
            if character.isWhitespace {
                self = .space
            } else if let scalar = character.unicodeScalars.first,
                      scalar.properties.isIdeographic || (0x3040...0x30FF).contains(scalar.value) {
                self = .ideograph
            } else if character.isLetter || character.isNumber || character == "'" || character == "\u{2019}" || character == "_" {
                self = .word
            } else {
                self = .symbol
            }
        }

        var groups: Bool { self == .word || self == .space }
    }
}
