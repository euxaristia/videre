import Foundation

enum EditorMode {
    case normal
    case insert
    case visual
    case visualLine
    case visualBlock  // Ctrl+V block mode
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

    var filePath: String? {
        didSet {
            updateGitStatus()
        }
    }
    var isDirty: Bool = false {
        didSet {
            // Update git status when dirty state changes (e.g. after save)
            if oldValue != isDirty {
                updateGitStatus()
            }
        }
    }
    var isHelpBuffer: Bool = false
    var registerManager: RegisterManager
    var undoManager: UndoManager = UndoManager()
    var shouldExit: Bool = false
    var showWelcomeMessage: Bool = false
    var showExitHint: Bool = false
    var matchingBracketPosition: Position? = nil
    var isWaitingForEnter: Bool = false
    var multiLineMessage: [String] = []

    // git state
    var gitStatus: String = ""

    func updateGitStatus() {
        guard let filePath = filePath else {
            gitStatus = ""
            return
        }

        let directory = (filePath as NSString).deletingLastPathComponent
        let fileName = (filePath as NSString).lastPathComponent
        let searchDir = directory.isEmpty ? "." : directory

        // Get branch and status in one go
        let output = executeShell("git status --porcelain -b -- \"\(fileName)\"", in: searchDir)
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard let firstLine = lines.first, firstLine.hasPrefix("## ") else {
            gitStatus = ""
            return
        }

        // Extract branch name (handles '## branch' or '## branch...remote')
        let branchLine = String(firstLine.dropFirst(3))
        let branch = branchLine.components(separatedBy: "...").first ?? branchLine
        
        // If there are more lines, the file itself has changes
        let hasChanges = lines.count > 1
        let indicator = hasChanges ? "*" : ""

        gitStatus = "\(branch)\(indicator)"
    }

    private func executeShell(_ command: String, in directory: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sh", "-c", command]
        
        let searchDir = directory.isEmpty ? "." : directory
        process.currentDirectoryURL = URL(fileURLWithPath: searchDir)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    // Viewport scrolling - the first visible line
    var scrollOffset: Int = 0

    // Mouse interaction state
    var lastClickTime: Date = Date.distantPast
    var lastClickPosition: Position? = nil
    var clickCount: Int = 0
    var isDragging: Bool = false

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

    // Repeat command state (for .)
    var lastInsertedText: String = ""
    var currentInsertText: String = ""
    var lastChangeCommand: Character? = nil

    // Repeatable operation state (for . with operators)
    struct RepeatableOperation {
        let type: OperatorType
        let motion: Character
        let count: Int
    }
    var lastOperation: RepeatableOperation? = nil

    // Marks (a-z)
    var marks: [Character: Position] = [:]

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
        updateGitStatus()
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
        case .visualBlock:
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
        if !isWaitingForEnter && currentMode != .command && currentMode != .search {
            statusMessage = ""
        }

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
        case .visualBlock:
            return "VISUAL BLOCK"
        case .command:
            return "COMMAND"
        case .search:
            return "SEARCH"
        }
    }

    // MARK: - Cursor Operations

    func moveCursorUp(count: Int = 1) {
        cursor.moveUp(count)
        let lineLength = buffer.lineLength(cursor.position.line)
        let maxCol = currentMode == .insert ? lineLength : max(0, lineLength - 1)
        let newCol = min(cursor.preferredColumn, maxCol)
        cursor.move(to: Position(line: cursor.position.line, column: newCol), updatePreferredColumn: false)
        updateStatusMessage()
    }

    func moveCursorDown(count: Int = 1) {
        cursor.moveDown(count)
        let lineLength = buffer.lineLength(cursor.position.line)
        let maxCol = currentMode == .insert ? lineLength : max(0, lineLength - 1)
        let newCol = min(cursor.preferredColumn, maxCol)
        cursor.move(to: Position(line: cursor.position.line, column: newCol), updatePreferredColumn: false)
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
        let newCol = currentMode == .insert ? lineLength : max(0, lineLength - 1)
        cursor.move(to: Position(line: cursor.position.line, column: newCol))
        cursor.preferredColumn = Int.max // Ensure vertical movement stays at end of line
        updateStatusMessage()
    }

    func moveCursorToFirstNonWhitespace() {
        let line = buffer.line(cursor.position.line)
        let firstNonWS = line.firstIndex { !$0.isWhitespace } ?? line.startIndex
        let column = line.distance(from: line.startIndex, to: firstNonWS)
        cursor.move(to: Position(line: cursor.position.line, column: column))
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

    // MARK: - Undo/Redo Operations

    /// Save current state before making changes
    func saveUndoState() {
        undoManager.saveState(text: buffer.text, cursor: cursor.position)
    }

    /// Undo the last change
    func undo() -> Bool {
        guard
            let previousState = undoManager.undo(
                currentText: buffer.text, currentCursor: cursor.position)
        else {
            statusMessage = "Already at oldest change"
            return false
        }

        buffer = TextBuffer(previousState.text)
        cursor.move(to: buffer.clampPosition(previousState.cursorPosition))
        isDirty = undoManager.undoCount > 0
        updateStatusMessage()
        return true
    }

    /// Redo the last undone change
    func redo() -> Bool {
        guard
            let redoState = undoManager.redo(
                currentText: buffer.text, currentCursor: cursor.position)
        else {
            statusMessage = "Already at newest change"
            return false
        }

        buffer = TextBuffer(redoState.text)
        cursor.move(to: buffer.clampPosition(redoState.cursorPosition))
        isDirty = true
        updateStatusMessage()
        return true
    }

    // MARK: - Number Operations

    func incrementNextNumber(count: Int) {
        saveUndoState()
        let lineIdx = cursor.position.line
        let line = buffer.line(lineIdx)
        let colIdx = cursor.position.column

        // Look for number starting at or after cursor
        let searchIdx = line.index(line.startIndex, offsetBy: colIdx)
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

    // MARK: - Viewport scrolling

    func scroll(by lines: Int) {
        scrollOffset = max(0, scrollOffset + lines)
        // Upper bound is clamped in the render loop based on terminal size
    }

    // MARK: - Mouse Selection Helpers

    func selectWord(at position: Position) {

        // Find start of word
        var start = position
        let line = buffer.line(position.line)
        if position.column < line.count {
            // Move backward to start of word
            var col = position.column
            while col > 0 && isWordCharacter(line[line.index(line.startIndex, offsetBy: col - 1)]) {
                col -= 1
            }
            start.column = col
        }

        // Find end of word
        var end = position
        if position.column < line.count {
            var col = position.column
            while col < line.count
                && isWordCharacter(line[line.index(line.startIndex, offsetBy: col)])
            {
                col += 1
            }
            end.column = max(0, col - 1)
        }

        cursor.move(to: start)
        setMode(.visual)
        if let visualHandler = visualModeHandler as? VisualMode {
            visualHandler.startPosition = start
        }
        cursor.move(to: end)
        updateStatusMessage()
    }

    func selectLine(at position: Position) {
        cursor.move(to: Position(line: position.line, column: 0))
        setMode(.visualLine)
        if let visualHandler = visualModeHandler as? VisualMode {
            visualHandler.startPosition = cursor.position
        }
        updateStatusMessage()
    }

    private func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }
}
