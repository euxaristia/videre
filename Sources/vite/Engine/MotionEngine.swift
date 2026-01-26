import Foundation

/// Motion types in vi
enum MotionType {
    case characterMotion  // f, F, t, T
    case wordMotion  // w, b, e, W, B, E
    case lineMotion  // 0, ^, $, g_, j, k
    case searchMotion  // /, ?
    case none
}

/// Represents a motion and its type
struct Motion {
    let type: MotionType
    let distance: Int
    let inclusive: Bool  // Does motion include the target character?

    init(_ type: MotionType, distance: Int = 1, inclusive: Bool = false) {
        self.type = type
        self.distance = distance
        self.inclusive = inclusive
    }
}

/// Engine for calculating motion offsets
class MotionEngine {
    let buffer: TextBuffer
    let cursor: Cursor

    init(buffer: TextBuffer, cursor: Cursor) {
        self.buffer = buffer
        self.cursor = cursor
    }

    // MARK: - Word Motions

    /// Move to next word (w)
    func nextWord(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            // Skip current word
            while col < line.count
                && isWordCharacter(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Skip whitespace
            while col < line.count && isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // If we hit end of line, move to next line
            if col >= line.count && pos.line < buffer.lineCount - 1 {
                pos.line += 1
                pos.column = 0
                // Skip whitespace on new line
                let nextLine = buffer.line(pos.line)
                while pos.column < nextLine.count
                    && isWhitespace(
                        nextLine[nextLine.index(nextLine.startIndex, offsetBy: pos.column)])
                {
                    pos.column += 1
                }
            } else {
                pos.column = col
            }
        }
        return buffer.clampPosition(pos)
    }

    /// Move to previous word (b)
    func previousWord(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            if col == 0 && pos.line > 0 {
                pos.line -= 1
                pos.column = buffer.lineLength(pos.line)
                col = pos.column
            }

            // Move back one to avoid staying on same word
            if col > 0 {
                col -= 1
            }

            // Skip whitespace backward
            while col > 0 && isWhitespace(line[line.index(line.startIndex, offsetBy: col)]) {
                col -= 1
            }

            // Skip word backward
            while col > 0 && isWordCharacter(line[line.index(line.startIndex, offsetBy: col)]) {
                col -= 1
            }

            // If we're not at a word character, we overshot - move forward one
            if col < line.count
                && !isWordCharacter(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            pos.column = col
        }
        return buffer.clampPosition(pos)
    }

    /// Move to end of word (e)
    func endOfWord(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            // Skip to start of next word if on whitespace
            while col < line.count && isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Move to end of word
            while col < line.count
                && isWordCharacter(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Move back one to be on the last character of word
            if col > 0 {
                col -= 1
            }

            // If we hit end of line, move to next line
            if col >= buffer.lineLength(pos.line) && pos.line < buffer.lineCount - 1 {
                pos.line += 1
                pos.column = 0
                // Find first word on new line
                let nextLine = buffer.line(pos.line)
                while pos.column < nextLine.count
                    && isWhitespace(
                        nextLine[nextLine.index(nextLine.startIndex, offsetBy: pos.column)])
                {
                    pos.column += 1
                }
            } else {
                pos.column = col
            }
        }
        return buffer.clampPosition(pos)
    }

    /// Move to next WORD (W) - separated by whitespace
    func nextWORD(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            // Skip current non-whitespace
            while col < line.count && !isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Skip whitespace
            while col < line.count && isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // If we hit end of line, move to next line
            if col >= line.count && pos.line < buffer.lineCount - 1 {
                pos.line += 1
                pos.column = 0
                // Skip whitespace on new line
                let nextLine = buffer.line(pos.line)
                while pos.column < nextLine.count
                    && isWhitespace(nextLine[nextLine.index(nextLine.startIndex, offsetBy: pos.column)])
                {
                    pos.column += 1
                }
            } else {
                pos.column = col
            }
        }
        return buffer.clampPosition(pos)
    }

    /// Move to previous WORD (B) - separated by whitespace
    func previousWORD(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            if col == 0 && pos.line > 0 {
                pos.line -= 1
                pos.column = buffer.lineLength(pos.line)
                col = pos.column
            }

            // Move back one to avoid staying on same word
            if col > 0 {
                col -= 1
            }

            // Skip whitespace backward
            while col > 0 && isWhitespace(line[line.index(line.startIndex, offsetBy: col)]) {
                col -= 1
            }

            // Skip WORD backward
            while col > 0 && !isWhitespace(line[line.index(line.startIndex, offsetBy: col)]) {
                col -= 1
            }

            // If we're on whitespace, we overshot - move forward one
            if col < line.count && isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            pos.column = col
        }
        return buffer.clampPosition(pos)
    }

    /// Move to end of WORD (E) - separated by whitespace
    func endOfWORD(_ count: Int = 1) -> Position {
        var pos = cursor.position
        for _ in 0..<count {
            let line = buffer.line(pos.line)
            var col = pos.column

            // Skip to start of next WORD if on whitespace
            while col < line.count && isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Move to end of WORD
            while col < line.count
                && !isWhitespace(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }

            // Move back one to be on the last character of WORD
            if col > 0 {
                col -= 1
            }

            // If we hit end of line, move to next line
            if col >= buffer.lineLength(pos.line) && pos.line < buffer.lineCount - 1 {
                pos.line += 1
                pos.column = 0
                // Find first WORD on new line
                let nextLine = buffer.line(pos.line)
                while pos.column < nextLine.count
                    && isWhitespace(nextLine[nextLine.index(nextLine.startIndex, offsetBy: pos.column)])
                {
                    pos.column += 1
                }
            } else {
                pos.column = col
            }
        }
        return buffer.clampPosition(pos)
    }

    // MARK: - Line Motions

    /// Move to first character of line (0)
    func lineStart() -> Position {
        var pos = cursor.position
        pos.column = 0
        return pos
    }

    /// Move to first non-whitespace character (^)
    func firstNonWhitespace() -> Position {
        var pos = cursor.position
        let line = buffer.line(pos.line)

        pos.column = 0
        while pos.column < line.count
            && isWhitespace(line[line.index(line.startIndex, offsetBy: pos.column)])
        {
            pos.column += 1
        }
        return pos
    }

    /// Move to end of line ($)
    func lineEnd() -> Position {
        var pos = cursor.position
        pos.column = max(0, buffer.lineLength(pos.line) - 1)
        return pos
    }

    /// Move to first line (gg)
    func fileStart() -> Position {
        return Position(line: 0, column: 0)
    }

    /// Move to last line (G)
    func fileEnd() -> Position {
        let lastLine = max(0, buffer.lineCount - 1)
        return Position(line: lastLine, column: 0)
    }

    /// Move to specific line (G with count)
    func goToLine(_ line: Int) -> Position {
        let clampedLine = max(0, min(line, buffer.lineCount - 1))
        return Position(line: clampedLine, column: 0)
    }

    // MARK: - Line Down/Up Motions (j/k)

    /// Move down by lines (j)
    func lineDown(_ count: Int = 1) -> Position {
        let newLine = min(cursor.position.line + count, buffer.lineCount - 1)
        let lineLength = buffer.lineLength(newLine)
        let newCol = min(cursor.preferredColumn, max(0, lineLength - 1))
        return Position(line: newLine, column: newCol)
    }

    /// Move up by lines (k)
    func lineUp(_ count: Int = 1) -> Position {
        let newLine = max(0, cursor.position.line - count)
        let lineLength = buffer.lineLength(newLine)
        let newCol = min(cursor.preferredColumn, max(0, lineLength - 1))
        return Position(line: newLine, column: newCol)
    }

    // MARK: - Paragraph Motions

    /// Move to next paragraph ({ boundary - jump to blank line)
    func nextParagraph(_ count: Int = 1) -> Position {
        var line = cursor.position.line
        for _ in 0..<count {
            // Skip non-blank lines
            while line < buffer.lineCount {
                let currentLine = buffer.line(line)
                if isBlankLine(currentLine) {
                    break
                }
                line += 1
            }

            // Skip blank lines
            while line < buffer.lineCount {
                let currentLine = buffer.line(line)
                if !isBlankLine(currentLine) {
                    break
                }
                line += 1
            }
        }
        
        let targetLine = min(line, buffer.lineCount - 1)
        let lineLength = buffer.lineLength(targetLine)
        let newCol = min(cursor.preferredColumn, max(0, lineLength - 1))
        return Position(line: targetLine, column: newCol)
    }

    /// Move to previous paragraph (} boundary - jump to blank line)
    func previousParagraph(_ count: Int = 1) -> Position {
        var line = cursor.position.line
        for _ in 0..<count {
            // Skip blank lines
            while line > 0 {
                line -= 1
                let currentLine = buffer.line(line)
                if !isBlankLine(currentLine) {
                    break
                }
            }

            // Skip non-blank lines
            while line > 0 {
                line -= 1
                let currentLine = buffer.line(line)
                if isBlankLine(currentLine) {
                    break
                }
            }
        }
        
        let targetLine = max(0, line)
        let lineLength = buffer.lineLength(targetLine)
        let newCol = min(cursor.preferredColumn, max(0, lineLength - 1))
        return Position(line: targetLine, column: newCol)
    }

    // MARK: - Character Search

    /// Find character forward (f)
    func findCharacterForward(_ char: Character, count: Int = 1) -> Position? {
        let pos = cursor.position
        var occurrences = 0

        for line in pos.line...buffer.lineCount - 1 {
            let lineStr = buffer.line(line)
            let startCol = line == pos.line ? pos.column + 1 : 0

            for col in startCol..<lineStr.count {
                if lineStr[lineStr.index(lineStr.startIndex, offsetBy: col)] == char {
                    occurrences += 1
                    if occurrences == count {
                        return Position(line: line, column: col)
                    }
                }
            }
        }

        return nil
    }

    /// Find character backward (F)
    func findCharacterBackward(_ char: Character, count: Int = 1) -> Position? {
        let pos = cursor.position
        var occurrences = 0

        for line in stride(from: pos.line, through: 0, by: -1) {
            let lineStr = buffer.line(line)
            let endCol = line == pos.line ? pos.column - 1 : lineStr.count - 1

            for col in stride(from: endCol, through: 0, by: -1) {
                if lineStr[lineStr.index(lineStr.startIndex, offsetBy: col)] == char {
                    occurrences += 1
                    if occurrences == count {
                        return Position(line: line, column: col)
                    }
                }
            }
        }

        return nil
    }

    /// Find character forward, place cursor before it (t)
    func tillCharacterForward(_ char: Character, count: Int = 1) -> Position? {
        if let pos = findCharacterForward(char, count: count), pos.column > 0 {
            var result = pos
            result.column -= 1
            return result
        }
        return nil
    }

    /// Find character backward, place cursor after it (T)
    func tillCharacterBackward(_ char: Character, count: Int = 1) -> Position? {
        if let pos = findCharacterBackward(char, count: count),
            pos.column < buffer.lineLength(pos.line) - 1
        {
            var result = pos
            result.column += 1
            return result
        }
        return nil
    }

    /// Find the matching bracket for the character at position
    func findMatchingBracket(at position: Position) -> Position? {
        guard let char = buffer.characterAt(position) else { return nil }

        let brackets: [Character: Character] = [
            "(": ")", "[": "]", "{": "}", ")": "(", "]": "[", "}": "{",
        ]
        let openBrackets: Set<Character> = ["(", "[", "{"]

        guard let targetBracket = brackets[char] else { return nil }

        let isForward = openBrackets.contains(char)
        var stack = 0

        if isForward {
            // Search forward
            for line in position.line..<buffer.lineCount {
                let lineStr = buffer.line(line)
                let startCol = (line == position.line) ? position.column : 0

                for col in startCol..<lineStr.count {
                    let currentChar = lineStr[lineStr.index(lineStr.startIndex, offsetBy: col)]
                    if currentChar == char {
                        stack += 1
                    } else if currentChar == targetBracket {
                        stack -= 1
                        if stack == 0 {
                            return Position(line: line, column: col)
                        }
                    }
                }
            }
        } else {
            // Search backward
            for line in stride(from: position.line, through: 0, by: -1) {
                let lineStr = buffer.line(line)
                let startCol = (line == position.line) ? position.column : lineStr.count - 1

                for col in stride(from: startCol, through: 0, by: -1) {
                    let currentChar = lineStr[lineStr.index(lineStr.startIndex, offsetBy: col)]
                    if currentChar == char {
                        stack += 1
                    } else if currentChar == targetBracket {
                        stack -= 1
                        if stack == 0 {
                            return Position(line: line, column: col)
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Helpers

    private func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }

    private func isWhitespace(_ char: Character) -> Bool {
        char.isWhitespace && char != "\n"
    }

    private func isBlankLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
