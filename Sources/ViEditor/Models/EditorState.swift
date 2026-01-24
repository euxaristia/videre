import Foundation

enum EditorMode {
    case normal
    case insert
    case visual
    case command
}

/// Central state container for the editor
class EditorState {
    var buffer: TextBuffer
    var cursor: Cursor
    var currentMode: EditorMode
    var statusMessage: String
    var pendingCommand: String

    var filePath: String?
    var isDirty: Bool = false

    init() {
        self.buffer = TextBuffer()
        self.cursor = Cursor()
        self.currentMode = .normal
        self.statusMessage = ""
        self.pendingCommand = ""
    }

    init(filePath: String) throws {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        self.buffer = TextBuffer(content)
        self.cursor = Cursor()
        self.currentMode = .normal
        self.statusMessage = ""
        self.pendingCommand = ""
        self.filePath = filePath
        self.isDirty = false
    }

    // MARK: - Mode Management

    func setMode(_ mode: EditorMode) {
        currentMode = mode
        updateStatusMessage()
    }

    // MARK: - Status

    func updateStatusMessage() {
        let pos = cursor.position
        let modeStr = modeString()
        statusMessage = "[\(modeStr)] Line \(pos.line + 1), Col \(pos.column + 1)"
    }

    private func modeString() -> String {
        switch currentMode {
        case .normal:
            return "NORMAL"
        case .insert:
            return "INSERT"
        case .visual:
            return "VISUAL"
        case .command:
            return "COMMAND"
        }
    }

    // MARK: - Cursor Operations

    func moveCursorUp(count: Int = 1) {
        cursor.moveUp(count)
        let clamped = buffer.clampPosition(cursor.position)
        cursor.move(to: clamped)
        updateStatusMessage()
    }

    func moveCursorDown(count: Int = 1) {
        cursor.moveDown(count)
        let clamped = buffer.clampPosition(cursor.position)
        cursor.move(to: clamped)
        updateStatusMessage()
    }

    func moveCursorLeft(count: Int = 1) {
        cursor.moveLeft(count)
        let clamped = buffer.clampPosition(cursor.position)
        cursor.move(to: clamped)
        updateStatusMessage()
    }

    func moveCursorRight(count: Int = 1) {
        cursor.moveRight(count)
        let clamped = buffer.clampPosition(cursor.position)
        cursor.move(to: clamped)
        updateStatusMessage()
    }

    func moveCursorToLineStart() {
        cursor.moveToLineStart()
        updateStatusMessage()
    }

    func moveCursorToLineEnd() {
        let lineLength = buffer.lineLength(cursor.position.line)
        cursor.position.column = max(0, lineLength - 1)
        updateStatusMessage()
    }

    func moveCursorToFirstNonWhitespace() {
        let line = buffer.line(cursor.position.line)
        let firstNonWS = line.firstIndex { !$0.isWhitespace } ?? line.startIndex
        let column = line.distance(from: line.startIndex, to: firstNonWS)
        cursor.position.column = column
        updateStatusMessage()
    }

    func moveCursorToBeginningOfFile() {
        cursor.moveToBeginningOfFile()
        updateStatusMessage()
    }

    func moveCursorToEndOfFile() {
        let lastLine = max(0, buffer.lineCount - 1)
        cursor.moveToEndOfFile(lastLine)
        updateStatusMessage()
    }

    // MARK: - Text Operations

    func insertCharacter(_ char: Character) {
        buffer.insertCharacter(char, at: cursor.position)
        isDirty = true
    }

    func deleteCharacter() {
        buffer.deleteCharacter(at: cursor.position)
        isDirty = true
    }

    func deleteBackward() {
        let pos = cursor.position
        buffer.deleteBackward(at: pos)
        if pos.column > 0 {
            cursor.moveLeft()
        } else if pos.line > 0 {
            cursor.moveUp()
            cursor.moveToLineEnd()
        }
        isDirty = true
    }

    func deleteCurrentLine() {
        buffer.deleteLine(cursor.position.line)
        if cursor.position.line >= buffer.lineCount {
            cursor.position.line = max(0, buffer.lineCount - 1)
        }
        isDirty = true
    }

    func insertNewLine() {
        let pos = cursor.position
        let line = buffer.line(pos.line)
        let before = String(line.prefix(pos.column))
        let after = String(line.dropFirst(pos.column))

        buffer.replaceLine(pos.line, with: before)
        buffer.insertLine(after, at: pos.line + 1)

        cursor.position.line += 1
        cursor.position.column = 0
        isDirty = true
    }
}
