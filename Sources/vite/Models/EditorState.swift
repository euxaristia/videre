import Foundation

enum EditorMode {
    case normal
    case insert
    case visual
    case visualLine
    case command
    case search
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
    var registerManager: RegisterManager
    var shouldExit: Bool = false
    var showWelcomeMessage: Bool = false
    var showExitHint: Bool = false
    var matchingBracketPosition: Position? = nil
    var isWaitingForEnter: Bool = false
    var multiLineMessage: [String] = []

    // Viewport scrolling - the first visible line
    var scrollOffset: Int = 0

    // Mode handlers for lifecycle management
    var normalModeHandler: ModeHandler?
    var insertModeHandler: ModeHandler?
    var visualModeHandler: ModeHandler?
    var commandModeHandler: ModeHandler?
    var searchModeHandler: ModeHandler?

    // Search state
    var searchPattern: String = ""
    var searchDirection: SearchDirection = .forward
    var lastSearchPattern: String = ""
    var lastSearchDirection: SearchDirection = .forward

    enum SearchDirection {
        case forward  // /
        case backward  // ?
    }

    init() {
        self.buffer = TextBuffer()
        self.cursor = Cursor()
        self.currentMode = .normal
        self.statusMessage = ""
        self.pendingCommand = ""
        self.registerManager = RegisterManager()
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
        self.registerManager = RegisterManager()
    }

    // MARK: - Mode Management

    func setMode(_ mode: EditorMode) {
        // Call exit on current mode
        let currentModeHandler = getModeHandler(currentMode)
        currentModeHandler?.exit()

        // Switch mode
        currentMode = mode

        // Call enter on new mode
        let newModeHandler = getModeHandler(mode)
        newModeHandler?.enter()

        updateStatusMessage()
    }

    private func getModeHandler(_ mode: EditorMode) -> ModeHandler? {
        switch mode {
        case .normal:
            return normalModeHandler
        case .insert:
            return insertModeHandler
        case .visual:
            return visualModeHandler
        case .visualLine:
            return visualModeHandler
        case .command:
            return commandModeHandler
        case .search:
            return searchModeHandler
        }
    }

    // MARK: - Status

    func updateStatusMessage() {
        let pos = cursor.position
        let modeStr = modeString()
        statusMessage = "[\(modeStr)] Line \(pos.line + 1), Col \(pos.column + 1)"

        // Update matching bracket
        let motionEngine = MotionEngine(buffer: buffer, cursor: cursor)
        matchingBracketPosition = motionEngine.findMatchingBracket(at: pos)
    }

    private func modeString() -> String {
        switch currentMode {
        case .normal:
            return "NORMAL"
        case .insert:
            return "INSERT"
        case .visual:
            return "VISUAL"
        case .visualLine:
            return "VISUAL LINE"
        case .command:
            return "COMMAND"
        case .search:
            return "SEARCH"
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

        // If at start of line (but not first line), we'll be merging with previous line
        // Calculate new column position BEFORE the merge
        if pos.column == 0 && pos.line > 0 {
            let prevLineLength = buffer.lineLength(pos.line - 1)
            buffer.deleteBackward(at: pos)
            cursor.moveUp()
            cursor.position.column = prevLineLength
        } else {
            // Normal backspace within line or at start of file
            buffer.deleteBackward(at: pos)
            if pos.column > 0 {
                cursor.moveLeft()
            }
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

    // MARK: - Number Operations

    func incrementNextNumber(count: Int) {
        let lineIdx = cursor.position.line
        let line = buffer.line(lineIdx)
        let colIdx = cursor.position.column

        // Look for number starting at or after cursor
        var searchIdx = line.index(line.startIndex, offsetBy: colIdx)
        var numberStartIdx: String.Index?
        var numberEndIdx: String.Index?

        // Special case: if we are on a digit or on a minus followed by a digit
        func isNumberChar(_ idx: String.Index) -> Bool {
            if line[idx].isNumber { return true }
            if line[idx] == "-" {
                let nextIdx = line.index(after: idx)
                if nextIdx < line.endIndex && line[nextIdx].isNumber {
                    return true
                }
            }
            return false
        }

        // Search for the start of a number
        var i = searchIdx
        while i < line.endIndex {
            if line[i].isNumber
                || (line[i] == "-" && line.index(after: i) < line.endIndex
                    && line[line.index(after: i)].isNumber)
            {
                numberStartIdx = i
                break
            }
            i = line.index(after: i)
        }

        guard let start = numberStartIdx else { return }

        // Find the end of the number
        var j = line.index(after: start)
        while j < line.endIndex && line[j].isNumber {
            j = line.index(after: j)
        }
        numberEndIdx = j

        let numberStr = String(line[start..<numberEndIdx!])
        if let num = Int(numberStr) {
            let newNum = num + count
            let newNumStr = String(newNum)

            let startCol = line.distance(from: line.startIndex, to: start)
            let endCol = line.distance(from: line.startIndex, to: numberEndIdx!)

            buffer.replaceRange(
                from: Position(line: lineIdx, column: startCol),
                to: Position(line: lineIdx, column: endCol),
                with: newNumStr)

            // Move cursor to the end of the new number
            cursor.position.column = startCol + newNumStr.count - 1
            isDirty = true
            updateStatusMessage()
        }
    }
}
