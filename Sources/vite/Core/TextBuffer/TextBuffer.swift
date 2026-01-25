import Foundation

/// High-level text buffer API combining gap buffer with line array
class TextBuffer {
    private var gapBuffer: GapBuffer
    private var lines: [String]

    init() {
        self.gapBuffer = GapBuffer()
        self.lines = [""]
    }

    init(_ text: String) {
        self.gapBuffer = GapBuffer(text)
        self.lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if self.lines.isEmpty {
            self.lines = [""]
        }
    }

    // MARK: - Properties

    var text: String {
        // Return text from lines array (this is where edits are actually stored)
        lines.joined(separator: "\n")
    }

    var lineCount: Int {
        lines.count
    }

    func line(_ index: Int) -> String {
        guard index >= 0 && index < lines.count else { return "" }
        return lines[index]
    }

    func lineLength(_ index: Int) -> Int {
        guard index >= 0 && index < lines.count else { return 0 }
        return lines[index].count
    }

    // MARK: - Editing Operations

    /// Insert character at position
    func insertCharacter(_ char: Character, at position: Position) {
        guard position.line >= 0 && position.line < lines.count else { return }

        var line = lines[position.line]
        let idx = min(position.column, line.count)
        line.insert(char, at: line.index(line.startIndex, offsetBy: idx))
        lines[position.line] = line

        if char == "\n" {
            let remaining = String(line.dropFirst(idx + 1))
            lines[position.line] = String(line.prefix(idx))
            lines.insert(remaining, at: position.line + 1)
        }
    }

    /// Insert string at position
    func insertString(_ str: String, at position: Position) {
        for char in str {
            insertCharacter(char, at: position)
        }
    }

    /// Delete character at position
    func deleteCharacter(at position: Position) {
        guard position.line >= 0 && position.line < lines.count else { return }
        guard position.column >= 0 && position.column < lines[position.line].count else { return }

        var line = lines[position.line]
        let idx = line.index(line.startIndex, offsetBy: position.column)
        line.remove(at: idx)
        lines[position.line] = line
    }

    /// Delete backward (like backspace)
    func deleteBackward(at position: Position) {
        guard position.column > 0 else {
            if position.line > 0 {
                let prevLine = lines[position.line - 1]
                let currentLine = lines[position.line]
                lines[position.line - 1] = prevLine + currentLine
                lines.remove(at: position.line)
            }
            return
        }

        var line = lines[position.line]
        let idx = line.index(line.startIndex, offsetBy: position.column - 1)
        line.remove(at: idx)
        lines[position.line] = line
    }

    /// Delete range
    func deleteRange(from start: Position, to end: Position) {
        guard start.line >= 0 && start.line < lines.count else { return }
        guard end.line >= 0 && end.line < lines.count else { return }

        if start.line == end.line {
            var line = lines[start.line]
            let startIdx = min(start.column, line.count)
            let endIdx = min(end.column, line.count)
            if startIdx < endIdx {
                let startStringIdx = line.index(line.startIndex, offsetBy: startIdx)
                let endStringIdx = line.index(line.startIndex, offsetBy: endIdx)
                line.removeSubrange(startStringIdx..<endStringIdx)
                lines[start.line] = line
            }
        } else {
            let startLine = lines[start.line]
            let endLine = lines[end.line]

            let startPart = String(startLine.prefix(start.column))
            let endPart = String(endLine.dropFirst(end.column))

            lines[start.line] = startPart + endPart
            lines.removeSubrange((start.line + 1)...end.line)
        }
    }

    /// Replace range with string
    func replaceRange(from start: Position, to end: Position, with text: String) {
        deleteRange(from: start, to: end)
        insertString(text, at: start)
    }

    /// Replace line
    func replaceLine(_ index: Int, with content: String) {
        guard index >= 0 && index < lines.count else { return }
        lines[index] = content
    }

    /// Insert new line
    func insertLine(_ content: String, at index: Int) {
        let idx = min(max(index, 0), lines.count)
        lines.insert(content, at: idx)
    }

    /// Delete line
    func deleteLine(_ index: Int) {
        guard index >= 0 && index < lines.count else { return }
        guard lines.count > 1 else { return }
        lines.remove(at: index)
    }

    // MARK: - Query Operations

    func clampPosition(_ position: Position) -> Position {
        let line = max(0, min(position.line, lines.count - 1))
        let column = max(0, min(position.column, lines[line].count))
        return Position(line: line, column: column)
    }

    func characterAt(_ position: Position) -> Character? {
        guard position.line >= 0 && position.line < lines.count else { return nil }
        let line = lines[position.line]
        guard position.column >= 0 && position.column < line.count else { return nil }
        let idx = line.index(line.startIndex, offsetBy: position.column)
        return line[idx]
    }

    func substring(from start: Position, to end: Position) -> String {
        if start.line == end.line {
            let line = lines[start.line]
            let startIdx = min(start.column, line.count)
            let endIdx = min(end.column, line.count)
            if startIdx < endIdx {
                let start = line.index(line.startIndex, offsetBy: startIdx)
                let end = line.index(line.startIndex, offsetBy: endIdx)
                return String(line[start..<end])
            }
        } else if start.line < end.line {
            var result = ""
            let startLine = lines[start.line]
            result += String(startLine.dropFirst(start.column))

            for i in (start.line + 1)..<end.line {
                result += "\n" + lines[i]
            }

            let endLine = lines[end.line]
            result += "\n" + String(endLine.prefix(end.column))
            return result
        }
        return ""
    }

    func word(at position: Position) -> String? {
        guard characterAt(position) != nil else { return nil }

        let line = lines[position.line]
        var start = position.column
        var end = position.column

        // Find word boundaries
        while start > 0 && isWordCharacter(line[line.index(line.startIndex, offsetBy: start - 1)]) {
            start -= 1
        }
        while end < line.count && isWordCharacter(line[line.index(line.startIndex, offsetBy: end)])
        {
            end += 1
        }

        if start < end {
            let startIdx = line.index(line.startIndex, offsetBy: start)
            let endIdx = line.index(line.startIndex, offsetBy: end)
            return String(line[startIdx..<endIdx])
        }
        return nil
    }

    // MARK: - Private Helpers

    private func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }
}
