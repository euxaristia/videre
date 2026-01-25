import Foundation

/// Engine for calculating text object ranges
class TextObjectEngine {
    let buffer: TextBuffer
    let cursor: Cursor

    init(buffer: TextBuffer, cursor: Cursor) {
        self.buffer = buffer
        self.cursor = cursor
    }

    // MARK: - Word Text Objects

    /// Inner word (iw) - the word under cursor, no surrounding whitespace
    func innerWord() -> (Position, Position)? {
        let line = buffer.line(cursor.position.line)
        guard !line.isEmpty else { return nil }

        let col = min(cursor.position.column, line.count - 1)
        guard col >= 0 else { return nil }

        var start = col
        var end = col

        // Expand backward to word start
        while start > 0 {
            let idx = line.index(line.startIndex, offsetBy: start - 1)
            if !isWordCharacter(line[idx]) { break }
            start -= 1
        }

        // Expand forward to word end
        while end < line.count - 1 {
            let idx = line.index(line.startIndex, offsetBy: end + 1)
            if !isWordCharacter(line[idx]) { break }
            end += 1
        }

        // Include the character at 'end' position
        return (
            Position(line: cursor.position.line, column: start),
            Position(line: cursor.position.line, column: end + 1)
        )
    }

    /// A word (aw) - the word under cursor plus trailing whitespace
    func aWord() -> (Position, Position)? {
        guard let (wordStart, wordEnd) = innerWord() else { return nil }

        let line = buffer.line(cursor.position.line)
        var end = wordEnd.column

        // Include trailing whitespace
        while end < line.count {
            let idx = line.index(line.startIndex, offsetBy: end)
            if !line[idx].isWhitespace { break }
            end += 1
        }

        return (wordStart, Position(line: cursor.position.line, column: end))
    }

    // MARK: - Quote Text Objects

    /// Inner quotes (i" or i') - content between quotes, excluding quotes
    func innerQuotes(_ quote: Character) -> (Position, Position)? {
        let line = buffer.line(cursor.position.line)
        guard !line.isEmpty else { return nil }

        let col = cursor.position.column

        // Find opening quote (search backward from cursor or at cursor)
        var openIdx: Int? = nil
        var closeIdx: Int? = nil

        // First, check if cursor is on a quote
        if col < line.count {
            let charAtCursor = line[line.index(line.startIndex, offsetBy: col)]
            if charAtCursor == quote {
                // Could be opening or closing quote - look for matching
                // Search backward for another quote
                var foundPrev = false
                for i in stride(from: col - 1, through: 0, by: -1) {
                    if line[line.index(line.startIndex, offsetBy: i)] == quote {
                        foundPrev = true
                        break
                    }
                }
                if foundPrev {
                    closeIdx = col
                } else {
                    openIdx = col
                }
            }
        }

        // Search for opening quote if not found
        if openIdx == nil {
            for i in stride(from: col, through: 0, by: -1) {
                if line[line.index(line.startIndex, offsetBy: i)] == quote {
                    openIdx = i
                    break
                }
            }
        }

        // Search for closing quote
        if closeIdx == nil {
            let searchStart = (openIdx ?? col) + 1
            for i in searchStart..<line.count {
                if line[line.index(line.startIndex, offsetBy: i)] == quote {
                    closeIdx = i
                    break
                }
            }
        }

        guard let open = openIdx, let close = closeIdx, open < close else { return nil }

        return (
            Position(line: cursor.position.line, column: open + 1),
            Position(line: cursor.position.line, column: close)
        )
    }

    /// A quotes (a" or a') - content between quotes, including quotes
    func aQuotes(_ quote: Character) -> (Position, Position)? {
        guard let (innerStart, innerEnd) = innerQuotes(quote) else { return nil }

        return (
            Position(line: cursor.position.line, column: innerStart.column - 1),
            Position(line: cursor.position.line, column: innerEnd.column + 1)
        )
    }

    // MARK: - Bracket Text Objects

    /// Inner brackets (i(, i[, i{) - content between brackets, excluding brackets
    func innerBrackets(_ openBracket: Character) -> (Position, Position)? {
        let closeBracket = matchingBracket(for: openBracket)
        return findBracketRange(open: openBracket, close: closeBracket, includeDelimiters: false)
    }

    /// A brackets (a(, a[, a{) - content between brackets, including brackets
    func aBrackets(_ openBracket: Character) -> (Position, Position)? {
        let closeBracket = matchingBracket(for: openBracket)
        return findBracketRange(open: openBracket, close: closeBracket, includeDelimiters: true)
    }

    // MARK: - Private Helpers

    private func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }

    private func matchingBracket(for bracket: Character) -> Character {
        switch bracket {
        case "(", ")": return bracket == "(" ? ")" : "("
        case "[", "]": return bracket == "[" ? "]" : "["
        case "{", "}": return bracket == "{" ? "}" : "{"
        case "<", ">": return bracket == "<" ? ">" : "<"
        default: return bracket
        }
    }

    private func findBracketRange(open: Character, close: Character, includeDelimiters: Bool) -> (Position, Position)? {
        let line = buffer.line(cursor.position.line)
        let col = cursor.position.column

        // Simple single-line bracket matching for now
        var openIdx: Int? = nil
        var closeIdx: Int? = nil
        var depth = 0

        // Search backward for opening bracket
        for i in stride(from: col, through: 0, by: -1) {
            let char = line[line.index(line.startIndex, offsetBy: i)]
            if char == close { depth += 1 }
            if char == open {
                if depth == 0 {
                    openIdx = i
                    break
                }
                depth -= 1
            }
        }

        guard let open = openIdx else { return nil }

        // Search forward for closing bracket
        depth = 0
        for i in (open + 1)..<line.count {
            let char = line[line.index(line.startIndex, offsetBy: i)]
            if char == self.matchingBracket(for: close) { depth += 1 }
            if char == close {
                if depth == 0 {
                    closeIdx = i
                    break
                }
                depth -= 1
            }
        }

        guard let closePosition = closeIdx else { return nil }

        if includeDelimiters {
            return (
                Position(line: cursor.position.line, column: open),
                Position(line: cursor.position.line, column: closePosition + 1)
            )
        } else {
            return (
                Position(line: cursor.position.line, column: open + 1),
                Position(line: cursor.position.line, column: closePosition)
            )
        }
    }
}
