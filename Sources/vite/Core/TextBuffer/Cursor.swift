import Foundation

/// Represents a position in the text (line, column)
struct Position: Equatable {
    var line: Int
    var column: Int

    init(line: Int = 0, column: Int = 0) {
        self.line = max(0, line)
        self.column = max(0, column)
    }

    mutating func moveUp() {
        line = max(0, line - 1)
    }

    mutating func moveDown() {
        line += 1
    }

    mutating func moveLeft() {
        column = max(0, column - 1)
    }

    mutating func moveRight() {
        column += 1
    }

    mutating func moveToLineStart() {
        column = 0
    }

    mutating func moveToLineEnd() {
        column = Int.max // Will be clamped by buffer
    }

    mutating func moveToFirstNonWhitespace() {
        column = 0 // Will be updated by buffer
    }
}

/// Cursor with position and movement
class Cursor {
    var position: Position
    /// The column the user intends to be in (used for vertical movement)
    var preferredColumn: Int

    init(line: Int = 0, column: Int = 0) {
        self.position = Position(line: line, column: column)
        self.preferredColumn = column
    }

    func move(to position: Position, updatePreferredColumn: Bool = true) {
        self.position = position
        if updatePreferredColumn {
            self.preferredColumn = position.column
        }
    }

    func moveUp(_ count: Int = 1) {
        position.line = max(0, position.line - count)
    }

    func moveDown(_ count: Int = 1) {
        position.line += count
    }

    func moveLeft(_ count: Int = 1) {
        position.column = max(0, position.column - count)
        preferredColumn = position.column
    }

    func moveRight(_ count: Int = 1) {
        position.column += count
        preferredColumn = position.column
    }

    func moveToLineStart() {
        position.column = 0
        preferredColumn = 0
    }

    func moveToLineEnd() {
        position.column = Int.max
        preferredColumn = Int.max
    }

    func moveToFirstNonWhitespace() {
        position.column = 0 // Will be determined by line content
        preferredColumn = 0
    }

    func moveToBeginningOfFile() {
        position = Position(line: 0, column: 0)
        preferredColumn = 0
    }

    func moveToEndOfFile(_ lastLine: Int) {
        position = Position(line: lastLine, column: 0)
        preferredColumn = 0
    }
}
