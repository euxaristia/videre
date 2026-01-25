import Foundation

/// Operator types
enum OperatorType {
    case delete      // d
    case yank        // y
    case change      // c
    case lowercase   // gu
    case uppercase   // gU
    case indent      // >
    case unindent    // <
    case none
}

/// Engine for executing operators (d, y, c) with motions
class OperatorEngine {
    let state: EditorState
    let motionEngine: MotionEngine
    var pendingOperator: OperatorType = .none
    var pendingCount: Int = 1
    var pendingTextObjectPrefix: Character? = nil  // 'i' for inner, 'a' for a/around
    var pendingRegister: Character? = nil  // Named register for this operation

    init(state: EditorState) {
        self.state = state
        self.motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
    }

    // MARK: - Text Object Support

    /// Handle text object prefix (i or a)
    func handleTextObjectPrefix(_ char: Character) -> Bool {
        if char == "i" || char == "a" {
            pendingTextObjectPrefix = char
            return true
        }
        return false
    }

    /// Execute operator with text object
    func executeWithTextObject(_ objectChar: Character) -> Bool {
        guard let prefix = pendingTextObjectPrefix else { return false }

        let textObjectEngine = TextObjectEngine(buffer: state.buffer, cursor: state.cursor)
        var range: (Position, Position)? = nil

        switch objectChar {
        case "w":
            range = prefix == "i" ? textObjectEngine.innerWord() : textObjectEngine.aWord()
        case "\"":
            range = prefix == "i" ? textObjectEngine.innerQuotes("\"") : textObjectEngine.aQuotes("\"")
        case "'":
            range = prefix == "i" ? textObjectEngine.innerQuotes("'") : textObjectEngine.aQuotes("'")
        case "`":
            range = prefix == "i" ? textObjectEngine.innerQuotes("`") : textObjectEngine.aQuotes("`")
        case "(", ")", "b":
            range = prefix == "i" ? textObjectEngine.innerBrackets("(") : textObjectEngine.aBrackets("(")
        case "[", "]":
            range = prefix == "i" ? textObjectEngine.innerBrackets("[") : textObjectEngine.aBrackets("[")
        case "{", "}", "B":
            range = prefix == "i" ? textObjectEngine.innerBrackets("{") : textObjectEngine.aBrackets("{")
        case "<", ">":
            range = prefix == "i" ? textObjectEngine.innerBrackets("<") : textObjectEngine.aBrackets("<")
        default:
            break
        }

        guard let (start, end) = range else {
            pendingTextObjectPrefix = nil
            pendingOperator = .none
            return false
        }

        state.saveUndoState()

        switch pendingOperator {
        case .delete:
            executeDelete(from: start, to: end)
            state.isDirty = true
        case .yank:
            let content = executeYank(from: start, to: end)
            if let registerName = pendingRegister {
                state.registerManager.set(registerName, content)
            } else {
                state.registerManager.setUnnamedRegister(content)
            }
        case .change:
            executeDelete(from: start, to: end)
            state.isDirty = true
            state.setMode(.insert)
        case .lowercase:
            lowercaseRange(from: start, to: end)
            state.isDirty = true
        case .uppercase:
            uppercaseRange(from: start, to: end)
            state.isDirty = true
        case .indent:
            // Indent/unindent with text objects not supported
            break
        case .unindent:
            // Indent/unindent with text objects not supported
            break
        case .none:
            break
        }

        pendingTextObjectPrefix = nil
        pendingOperator = .none
        pendingCount = 1
        pendingRegister = nil
        return true
    }

    // MARK: - Operator Execution

    func executeDelete(from start: Position, to end: Position) {
        state.buffer.deleteRange(from: start, to: end)
        // Move cursor to start of deletion
        state.cursor.move(to: start)
        state.updateStatusMessage()
    }

    func executeDeleteLine(_ count: Int = 1) {
        for _ in 0..<count {
            state.deleteCurrentLine()
        }
    }

    func executeYank(from start: Position, to end: Position) -> RegisterContent {
        let text = state.buffer.substring(from: start, to: end)
        return .characters(text)
    }

    func executeYankLine(_ count: Int = 1) -> RegisterContent {
        var lines: [String] = []
        let startLine = state.cursor.position.line

        for i in 0..<count {
            if startLine + i < state.buffer.lineCount {
                lines.append(state.buffer.line(startLine + i))
            }
        }

        return .lines(lines)
    }

    func executeChange(from start: Position, to end: Position) {
        executeDelete(from: start, to: end)
        state.setMode(.insert)
    }

    // MARK: - Operator + Motion Combinations

    func deleteWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount  // Save count before we reset it
        switch char {
        case "d":
            // dd - delete entire line
            executeDeleteLine(pendingCount)
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            executeDelete(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "W":
            let end = motionEngine.nextWORD(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "B":
            let end = motionEngine.previousWORD(pendingCount)
            executeDelete(from: end, to: state.cursor.position)
            pendingCount = 1
        case "E":
            let end = motionEngine.endOfWORD(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "0":
            let start = motionEngine.lineStart()
            executeDelete(from: start, to: state.cursor.position)
            pendingCount = 1
        case "$":
            let end = motionEngine.lineEnd()
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "^":
            let start = motionEngine.firstNonWhitespace()
            executeDelete(from: start, to: state.cursor.position)
            pendingCount = 1
        case "{":
            let start = motionEngine.previousParagraph(pendingCount)
            executeDelete(from: start, to: state.cursor.position)
            pendingCount = 1
        case "}":
            let end = motionEngine.nextParagraph(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "j":
            // Delete lines down (line-wise)
            let endLine = min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1)
            for _ in state.cursor.position.line...endLine {
                state.deleteCurrentLine()
            }
            pendingCount = 1
        case "k":
            // Delete lines up (line-wise)
            let startLine = max(0, state.cursor.position.line - pendingCount)
            state.cursor.position.line = startLine
            for _ in startLine...state.cursor.position.line {
                state.deleteCurrentLine()
            }
            pendingCount = 1
        default:
            pendingCount = 1
        }

        // Track the operation for repeat (.)
        state.lastOperation = EditorState.RepeatableOperation(
            type: .delete,
            motion: char,
            count: opCount
        )

        pendingRegister = nil
        pendingOperator = .none
    }

    func yankWithMotion(_ char: Character) {
        var content: RegisterContent = .characters("")
        let opCount = pendingCount  // Save count before reset

        switch char {
        case "y":
            // yy - yank entire line
            content = executeYankLine(pendingCount)
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            content = executeYank(from: end, to: state.cursor.position)
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "W":
            let end = motionEngine.nextWORD(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "B":
            let end = motionEngine.previousWORD(pendingCount)
            content = executeYank(from: end, to: state.cursor.position)
        case "E":
            let end = motionEngine.endOfWORD(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "0":
            let start = motionEngine.lineStart()
            content = executeYank(from: start, to: state.cursor.position)
        case "$":
            let end = motionEngine.lineEnd()
            content = executeYank(from: state.cursor.position, to: end)
        case "^":
            let start = motionEngine.firstNonWhitespace()
            content = executeYank(from: start, to: state.cursor.position)
        case "{":
            // Yank to previous paragraph (line-wise)
            let start = motionEngine.previousParagraph(pendingCount)
            var lines: [String] = []
            for i in start.line...state.cursor.position.line {
                lines.append(state.buffer.line(i))
            }
            content = .lines(lines)
        case "}":
            // Yank to next paragraph (line-wise)
            let end = motionEngine.nextParagraph(pendingCount)
            var lines: [String] = []
            for i in state.cursor.position.line...end.line {
                lines.append(state.buffer.line(i))
            }
            content = .lines(lines)
        case "j":
            // Yank lines down (line-wise)
            var lines: [String] = []
            let startLine = state.cursor.position.line
            let endLine = min(startLine + pendingCount, state.buffer.lineCount - 1)
            for i in startLine...endLine {
                lines.append(state.buffer.line(i))
            }
            content = .lines(lines)
        case "k":
            // Yank lines up (line-wise)
            var lines: [String] = []
            let endLine = state.cursor.position.line
            let startLine = max(0, endLine - pendingCount)
            for i in startLine...endLine {
                lines.append(state.buffer.line(i))
            }
            content = .lines(lines)
        default:
            break
        }

        // Store in register
        if !content.isEmpty {
            if let registerName = pendingRegister {
                state.registerManager.set(registerName, content)
            } else {
                state.registerManager.setUnnamedRegister(content)
            }
        }

        // Track the operation for repeat (.)
        state.lastOperation = EditorState.RepeatableOperation(
            type: .yank,
            motion: char,
            count: opCount
        )

        pendingCount = 1
        pendingRegister = nil
        pendingOperator = .none
    }

    func changeWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount  // Save count before reset
        switch char {
        case "c":
            // cc - change entire line
            executeDeleteLine(pendingCount)
            state.setMode(.insert)
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            executeChange(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "W":
            let end = motionEngine.nextWORD(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "B":
            let end = motionEngine.previousWORD(pendingCount)
            executeChange(from: end, to: state.cursor.position)
            pendingCount = 1
        case "E":
            let end = motionEngine.endOfWORD(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "0":
            let start = motionEngine.lineStart()
            executeChange(from: start, to: state.cursor.position)
            pendingCount = 1
        case "$":
            let end = motionEngine.lineEnd()
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "^":
            let start = motionEngine.firstNonWhitespace()
            executeChange(from: start, to: state.cursor.position)
            pendingCount = 1
        case "{":
            let start = motionEngine.previousParagraph(pendingCount)
            executeChange(from: start, to: state.cursor.position)
            pendingCount = 1
        case "}":
            let end = motionEngine.nextParagraph(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "j":
            // Change lines down
            let endLine = min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1)
            for _ in state.cursor.position.line...endLine {
                state.deleteCurrentLine()
            }
            state.setMode(.insert)
            pendingCount = 1
        case "k":
            // Change lines up
            let startLine = max(0, state.cursor.position.line - pendingCount)
            state.cursor.position.line = startLine
            for _ in startLine...state.cursor.position.line {
                state.deleteCurrentLine()
            }
            state.setMode(.insert)
            pendingCount = 1
        default:
            pendingCount = 1
        }

        // Track the operation for repeat (.)
        state.lastOperation = EditorState.RepeatableOperation(
            type: .change,
            motion: char,
            count: opCount
        )

        pendingRegister = nil
        pendingOperator = .none
    }

    // MARK: - Case Conversion Functions

    func lowercaseWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount
        switch char {
        case "u":
            // uu - lowercase entire line
            let line = state.buffer.line(state.cursor.position.line)
            state.buffer.replaceLine(state.cursor.position.line, with: line.lowercased())
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            lowercaseRange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            lowercaseRange(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            lowercaseRange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "j":
            // Lowercase lines down
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1) {
                let line = state.buffer.line(i)
                state.buffer.replaceLine(i, with: line.lowercased())
            }
            pendingCount = 1
        case "k":
            // Lowercase lines up
            let startLine = max(0, state.cursor.position.line - pendingCount)
            for i in startLine...state.cursor.position.line {
                let line = state.buffer.line(i)
                state.buffer.replaceLine(i, with: line.lowercased())
            }
            pendingCount = 1
        default:
            pendingCount = 1
        }

        state.isDirty = true
        state.lastOperation = EditorState.RepeatableOperation(
            type: .lowercase,
            motion: char,
            count: opCount
        )
        pendingOperator = .none
    }

    func uppercaseWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount
        switch char {
        case "U":
            // UU - uppercase entire line
            let line = state.buffer.line(state.cursor.position.line)
            state.buffer.replaceLine(state.cursor.position.line, with: line.uppercased())
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            uppercaseRange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            uppercaseRange(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            uppercaseRange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "j":
            // Uppercase lines down
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1) {
                let line = state.buffer.line(i)
                state.buffer.replaceLine(i, with: line.uppercased())
            }
            pendingCount = 1
        case "k":
            // Uppercase lines up
            let startLine = max(0, state.cursor.position.line - pendingCount)
            for i in startLine...state.cursor.position.line {
                let line = state.buffer.line(i)
                state.buffer.replaceLine(i, with: line.uppercased())
            }
            pendingCount = 1
        default:
            pendingCount = 1
        }

        state.isDirty = true
        state.lastOperation = EditorState.RepeatableOperation(
            type: .uppercase,
            motion: char,
            count: opCount
        )
        pendingOperator = .none
    }

    private func lowercaseRange(from start: Position, to end: Position) {
        var current = start
        while current.line < end.line || (current.line == end.line && current.column < end.column) {
            if let char = state.buffer.characterAt(current) {
                let lowercased = Character(String(char).lowercased())
                state.buffer.deleteCharacter(at: current)
                state.buffer.insertCharacter(lowercased, at: current)
            }
            current.column += 1
            if current.column >= state.buffer.lineLength(current.line) {
                current.line += 1
                current.column = 0
            }
        }
    }

    private func uppercaseRange(from start: Position, to end: Position) {
        var current = start
        while current.line < end.line || (current.line == end.line && current.column < end.column) {
            if let char = state.buffer.characterAt(current) {
                let uppercased = Character(String(char).uppercased())
                state.buffer.deleteCharacter(at: current)
                state.buffer.insertCharacter(uppercased, at: current)
            }
            current.column += 1
            if current.column >= state.buffer.lineLength(current.line) {
                current.line += 1
                current.column = 0
            }
        }
    }

    // MARK: - Indentation Functions

    func indentWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount
        switch char {
        case ">":
            // >> - indent current line
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount - 1, state.buffer.lineCount - 1) {
                state.buffer.indentLine(i)
            }
            pendingCount = 1
        case "j":
            // Indent lines down
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1) {
                state.buffer.indentLine(i)
            }
            pendingCount = 1
        case "k":
            // Indent lines up
            let startLine = max(0, state.cursor.position.line - pendingCount)
            for i in startLine...state.cursor.position.line {
                state.buffer.indentLine(i)
            }
            pendingCount = 1
        default:
            pendingCount = 1
        }

        state.isDirty = true
        state.lastOperation = EditorState.RepeatableOperation(
            type: .indent,
            motion: char,
            count: opCount
        )
        pendingOperator = .none
    }

    func unindentWithMotion(_ char: Character) {
        state.saveUndoState()
        let opCount = pendingCount
        switch char {
        case "<":
            // << - unindent current line
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount - 1, state.buffer.lineCount - 1) {
                state.buffer.unindentLine(i)
            }
            pendingCount = 1
        case "j":
            // Unindent lines down
            for i in state.cursor.position.line...min(state.cursor.position.line + pendingCount, state.buffer.lineCount - 1) {
                state.buffer.unindentLine(i)
            }
            pendingCount = 1
        case "k":
            // Unindent lines up
            let startLine = max(0, state.cursor.position.line - pendingCount)
            for i in startLine...state.cursor.position.line {
                state.buffer.unindentLine(i)
            }
            pendingCount = 1
        default:
            pendingCount = 1
        }

        state.isDirty = true
        state.lastOperation = EditorState.RepeatableOperation(
            type: .unindent,
            motion: char,
            count: opCount
        )
        pendingOperator = .none
    }

    // MARK: - Helpers

    private func isEmpty(_ content: RegisterContent) -> Bool {
        switch content {
        case .characters(let str):
            return str.isEmpty
        case .lines(let lines):
            return lines.isEmpty
        }
    }
}

extension RegisterContent {
    var isEmpty: Bool {
        switch self {
        case .characters(let str):
            return str.isEmpty
        case .lines(let lines):
            return lines.isEmpty
        }
    }
}
