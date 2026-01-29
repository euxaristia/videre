import Foundation

/// Handler for Normal mode
class NormalMode: BaseModeHandler {
    var motionEngine: MotionEngine
    var operatorEngine: OperatorEngine
    var pendingCommand: String = ""
    var countPrefix: Int = 0
    var searchChar: Character?
    var lastSearchChar: Character?
    var lastSearchDirection: Character = "f"  // f, F, t, T
    var waitingForRegisterName: Bool = false
    var selectedRegisterName: Character? = nil
    var waitingForMarkName: Bool = false
    var markMode: Character? = nil  // ' for linewise, ` for exact
    var pendingIndentChar: Character? = nil  // > or <

    override init(state: EditorState) {
        self.motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
        self.operatorEngine = OperatorEngine(state: state)
        super.init(state: state)
    }

    override func handleInput(_ char: Character) -> Bool {
        // Collect count prefix
        if char.isNumber && char != "0" && pendingCommand.isEmpty
            && operatorEngine.pendingOperator == .none
        {
            countPrefix = countPrefix * 10 + Int(String(char))!
            return true
        }

        // Apply count to next command
        let count = countPrefix > 0 ? countPrefix : 1
        countPrefix = 0

        // Handle pending operators
        if operatorEngine.pendingOperator != .none {
            // Check for text object prefix (i or a)
            if operatorEngine.pendingTextObjectPrefix != nil {
                // Execute text object operation
                if operatorEngine.executeWithTextObject(char) {
                    return true
                }
                // If text object failed, reset and continue
                operatorEngine.pendingTextObjectPrefix = nil
                operatorEngine.pendingOperator = .none
                return true
            }

            // Check if this is a text object prefix
            if char == "i" || char == "a" {
                operatorEngine.pendingTextObjectPrefix = char
                return true
            }

            switch operatorEngine.pendingOperator {
            case .delete:
                operatorEngine.deleteWithMotion(char)
                return true
            case .yank:
                operatorEngine.yankWithMotion(char)
                return true
            case .change:
                operatorEngine.changeWithMotion(char)
                return true
            case .lowercase:
                operatorEngine.lowercaseWithMotion(char)
                return true
            case .uppercase:
                operatorEngine.uppercaseWithMotion(char)
                return true
            case .indent:
                operatorEngine.indentWithMotion(char)
                return true
            case .unindent:
                operatorEngine.unindentWithMotion(char)
                return true
            case .none:
                break
            }
        }

        // Single character commands
        switch char {
        case "\u{7F}", "\u{08}", "⌦":
            // Backspace/delete are no-ops in normal mode
            return false
        case "\u{01}":
            // Ctrl+A: Increment number
            state.incrementNextNumber(count: count)
            return true
        case "\u{02}":
            // Ctrl+B: Page up (like vi/vim)
            // Use a reasonable page size for terminal editors
            let pageSize = 20
            for _ in 0..<count {
                state.moveCursorUp(count: pageSize)
            }
            return true
        case "\u{18}":  // Ctrl+X
            // Ctrl+X: Decrement number
            state.incrementNextNumber(count: -count)
            return true
        // Cursor movement
        case "h", "←":
            state.moveCursorLeft(count: count)
            return true
        case "j", "↓":
            state.moveCursorDown(count: count)
            return true
        case "k", "↑":
            state.moveCursorUp(count: count)
            return true
        case "l", "→":
            state.moveCursorRight(count: count)
            return true

        // Word motions
        case "w":
            let pos = motionEngine.nextWord(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "b":
            let pos = motionEngine.previousWord(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "e":
            let pos = motionEngine.endOfWord(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true

        // WORD motions
        case "W":
            let pos = motionEngine.nextWORD(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "B":
            let pos = motionEngine.previousWORD(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "E":
            let pos = motionEngine.endOfWORD(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true

        // Line motions
        case "0":
            state.cursor.moveToLineStart()
            state.updateStatusMessage()
            return true
        case "^":
            let pos = motionEngine.firstNonWhitespace()
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "$":
            state.moveCursorToLineEnd()
            return true
        case "g":
            pendingCommand = "g"
            return true
        case "G":
            if pendingCommand == "g" {
                state.moveCursorToBeginningOfFile()
                pendingCommand = ""
            } else if count > 0 {
                let pos = motionEngine.goToLine(count - 1)
                state.cursor.move(to: pos)
                state.updateStatusMessage()
            } else {
                state.moveCursorToEndOfFile()
            }
            return true

        // Character search
        case "f":
            pendingCommand = "f"
            return true
        case "F":
            pendingCommand = "F"
            return true
        case "t":
            pendingCommand = "t"
            return true
        case "T":
            pendingCommand = "T"
            return true
        case ";":
            // Repeat last find
            if let char = lastSearchChar {
                executeFindMotion(lastSearchDirection, char, count)
            }
            return true
        case ",":
            // Repeat last find in reverse direction
            if let char = lastSearchChar {
                let reverseDirection: Character
                switch lastSearchDirection {
                case "f":
                    reverseDirection = "F"
                case "F":
                    reverseDirection = "f"
                case "t":
                    reverseDirection = "T"
                case "T":
                    reverseDirection = "t"
                default:
                    return true
                }
                executeFindMotion(reverseDirection, char, count)
            }
            return true
        case "%":
            // Jump to matching bracket
            if let matchPos = motionEngine.findMatchingBracket(at: state.cursor.position) {
                state.cursor.move(to: matchPos)
                state.updateStatusMessage()
            }
            return true

        // Paragraph motions
        case "{":
            let pos = motionEngine.previousParagraph(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true
        case "}":
            let pos = motionEngine.nextParagraph(count)
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true

        // Insert mode entry
        case "i":
            state.setMode(.insert)
            return true
        case "a":
            state.moveCursorRight()
            state.setMode(.insert)
            return true
        case "I":
            state.moveCursorToLineStart()
            state.setMode(.insert)
            return true
        case "A":
            state.moveCursorToLineEnd()
            state.moveCursorRight()
            state.setMode(.insert)
            return true
        case "o":
            state.moveCursorToLineEnd()
            state.insertNewLine()
            state.setMode(.insert)
            return true
        case "O":
            state.moveCursorToLineStart()
            let pos = state.cursor.position
            state.buffer.insertLine("", at: pos.line)
            state.setMode(.insert)
            return true

        // Operators
        case "d":
            operatorEngine.pendingOperator = .delete
            operatorEngine.pendingCount = count
            operatorEngine.pendingRegister = selectedRegisterName
            selectedRegisterName = nil
            return true
        case "y":
            operatorEngine.pendingOperator = .yank
            operatorEngine.pendingCount = count
            operatorEngine.pendingRegister = selectedRegisterName
            selectedRegisterName = nil
            return true
        case "c":
            operatorEngine.pendingOperator = .change
            operatorEngine.pendingCount = count
            operatorEngine.pendingRegister = selectedRegisterName
            selectedRegisterName = nil
            return true

        // Operator shortcuts
        case "C":
            // C = c$ (change to end of line)
            state.saveUndoState()
            let endPos = motionEngine.lineEnd()
            operatorEngine.executeChange(from: state.cursor.position, to: endPos)
            return true
        case "D":
            // D = d$ (delete to end of line)
            state.saveUndoState()
            let endPos = motionEngine.lineEnd()
            operatorEngine.executeDelete(from: state.cursor.position, to: endPos)
            return true
        case "S":
            // S = cc (substitute line - delete and enter insert mode)
            state.saveUndoState()
            operatorEngine.executeDeleteLine(count)
            state.setMode(.insert)
            return true

        // Delete commands
        case "x":
            state.saveUndoState()
            for _ in 0..<count {
                state.deleteCharacter()
            }
            return true
        case "s":
            // Substitute character (delete char + insert)
            state.saveUndoState()
            for _ in 0..<count {
                state.deleteCharacter()
            }
            state.setMode(.insert)
            return true
        case "X":
            // Delete backward
            state.saveUndoState()
            for _ in 0..<count {
                if state.cursor.position.column > 0 {
                    state.cursor.moveLeft()
                    state.deleteCharacter()
                }
            }
            return true

        // Undo/Redo
        case "u":
            _ = state.undo()
            return true
        case "\u{12}":  // Ctrl+R
            _ = state.redo()
            return true

        // Repeat last change
        case ".":
            // First try to repeat operator
            if let op = state.lastOperation {
                // Replay the operation
                operatorEngine.pendingOperator = op.type
                operatorEngine.pendingCount = op.count

                switch op.type {
                case .delete:
                    operatorEngine.deleteWithMotion(op.motion)
                case .yank:
                    operatorEngine.yankWithMotion(op.motion)
                case .change:
                    operatorEngine.changeWithMotion(op.motion)
                case .lowercase:
                    operatorEngine.lowercaseWithMotion(op.motion)
                case .uppercase:
                    operatorEngine.uppercaseWithMotion(op.motion)
                case .indent:
                    operatorEngine.indentWithMotion(op.motion)
                case .unindent:
                    operatorEngine.unindentWithMotion(op.motion)
                case .none:
                    break
                }
            } else if !state.lastInsertedText.isEmpty {
                // Fall back to insert text repeat
                state.saveUndoState()
                var pos = state.cursor.position
                for char in state.lastInsertedText {
                    if char == "\n" {
                        let line = state.buffer.line(pos.line)
                        let before = String(line.prefix(pos.column))
                        let after = String(line.dropFirst(pos.column))
                        state.buffer.replaceLine(pos.line, with: before)
                        state.buffer.insertLine(after, at: pos.line + 1)
                        pos.line += 1
                        pos.column = 0
                    } else {
                        state.buffer.insertCharacter(char, at: pos)
                        pos.column += 1
                    }
                }
                state.cursor.move(to: pos)
                state.isDirty = true
                state.updateStatusMessage()
            }
            return true

        // Paste
        case "p":
            state.saveUndoState()
            let content: RegisterContent
            if let registerName = selectedRegisterName {
                content = state.registerManager.get(registerName) ?? .characters("")
                selectedRegisterName = nil
            } else {
                content = state.registerManager.getUnnamedRegister()
            }
            switch content {
            case .characters(let str):
                var pos = state.cursor.position
                pos.column += 1
                for char in str {
                    state.buffer.insertCharacter(char, at: pos)
                    pos.column += 1
                }
                state.cursor.move(to: pos)
                state.isDirty = true
            case .lines(let lines):
                var insertLine = state.cursor.position.line + 1
                for line in lines {
                    state.buffer.insertLine(line, at: insertLine)
                    insertLine += 1
                }
                state.isDirty = true
            }
            state.updateStatusMessage()
            return true

        case "P":
            state.saveUndoState()
            let content: RegisterContent
            if let registerName = selectedRegisterName {
                content = state.registerManager.get(registerName) ?? .characters("")
                selectedRegisterName = nil
            } else {
                content = state.registerManager.getUnnamedRegister()
            }
            switch content {
            case .characters(let str):
                var pos = state.cursor.position
                for char in str {
                    state.buffer.insertCharacter(char, at: pos)
                    pos.column += 1
                }
                state.isDirty = true
            case .lines(let lines):
                var insertLine = state.cursor.position.line
                for line in lines {
                    state.buffer.insertLine(line, at: insertLine)
                    insertLine += 1
                }
                state.isDirty = true
            }
            state.updateStatusMessage()
            return true

        // Replace character
        case "r":
            pendingCommand = "r"
            return true

        // Named register selection
        case "\"":
            waitingForRegisterName = true
            return true

        // Marks
        case "m":
            waitingForMarkName = true
            markMode = "m"
            return true
        case "'":
            waitingForMarkName = true
            markMode = "'"
            return true
        case "`":
            waitingForMarkName = true
            markMode = "`"
            return true

        // Join lines
        case "J":
            state.saveUndoState()
            let currentLine = state.cursor.position.line
            if currentLine < state.buffer.lineCount - 1 {
                let line1 = state.buffer.line(currentLine)
                let line2 = state.buffer.line(currentLine + 1).trimmingCharacters(in: .whitespaces)
                let joinedLine = line1.isEmpty ? line2 : (line2.isEmpty ? line1 : line1 + " " + line2)
                state.buffer.replaceLine(currentLine, with: joinedLine)
                state.buffer.deleteLine(currentLine + 1)
                // Position cursor at the join point
                state.cursor.position.column = line1.count
                state.isDirty = true
            }
            state.updateStatusMessage()
            return true

        // Indentation
        case ">":
            // > can be an operator (>motion) or >>
            operatorEngine.pendingOperator = .indent
            operatorEngine.pendingCount = count
            operatorEngine.pendingRegister = selectedRegisterName
            selectedRegisterName = nil
            return true
        case "<":
            // < can be an operator (<motion) or <<
            operatorEngine.pendingOperator = .unindent
            operatorEngine.pendingCount = count
            operatorEngine.pendingRegister = selectedRegisterName
            selectedRegisterName = nil
            return true

        // Case toggle
        case "~":
            state.saveUndoState()
            var pos = state.cursor.position
            for _ in 0..<count {
                if let char = state.buffer.characterAt(pos) {
                    let toggled: Character
                    if char.isUppercase {
                        toggled = Character(char.lowercased())
                    } else if char.isLowercase {
                        toggled = Character(char.uppercased())
                    } else {
                        toggled = char
                    }
                    state.buffer.deleteCharacter(at: pos)
                    state.buffer.insertCharacter(toggled, at: pos)
                    pos.column += 1
                    if pos.column >= state.buffer.lineLength(pos.line) && pos.line < state.buffer.lineCount - 1 {
                        pos.line += 1
                        pos.column = 0
                    }
                    state.isDirty = true
                }
            }
            state.cursor.move(to: pos)
            state.updateStatusMessage()
            return true

        // Visual mode
        case "v":
            state.setMode(.visual)
            return true
        case "V":
            state.setMode(.visualLine)
            return true
        case "\u{16}":  // Ctrl+V
            state.setMode(.visualBlock)
            return true

        // Viewport positioning
        case "z":
            pendingCommand = "z"
            return true
        case "H":
            // Jump to top of window (scroll to show cursor at top)
            state.scrollOffset = state.cursor.position.line
            state.updateStatusMessage()
            return true
        case "M":
            // Jump to middle of window
            let viewportHeight = 20  // Default reasonable height
            state.scrollOffset = max(0, state.cursor.position.line - viewportHeight / 2)
            state.updateStatusMessage()
            return true
        case "L":
            // Jump to bottom of window
            let viewportHeight = 20  // Default reasonable height
            state.scrollOffset = max(0, state.cursor.position.line - viewportHeight + 1)
            state.updateStatusMessage()
            return true

        // Command mode
        case ":":
            state.pendingCommand = ":"
            state.setMode(.command)
            return true

        // Search mode
        case "/":
            state.searchDirection = .forward
            state.searchPattern = ""
            state.setMode(.search)
            return true
        case "?":
            state.searchDirection = .backward
            state.searchPattern = ""
            state.setMode(.search)
            return true

        // Repeat search
        case "n":
            if let searchMode = state.searchModeHandler as? SearchMode {
                _ = searchMode.searchNext()
            }
            return true
        case "N":
            if let searchMode = state.searchModeHandler as? SearchMode {
                _ = searchMode.searchPrevious()
            }
            return true

        // Word under cursor search
        case "*":
            if let word = state.buffer.word(at: state.cursor.position) {
                state.searchPattern = word
                state.searchDirection = .forward
                state.lastSearchPattern = word
                state.lastSearchDirection = .forward
                if let searchMode = state.searchModeHandler as? SearchMode {
                    _ = searchMode.searchNext()
                }
            }
            return true
        case "#":
            if let word = state.buffer.word(at: state.cursor.position) {
                state.searchPattern = word
                state.searchDirection = .backward
                state.lastSearchPattern = word
                state.lastSearchDirection = .backward
                if let searchMode = state.searchModeHandler as? SearchMode {
                    _ = searchMode.searchPrevious()
                }
            }
            return true

        // Escape
        case "\u{1B}":
            pendingCommand = ""
            countPrefix = 0
            operatorEngine.pendingOperator = .none
            return true

        default:
            // Check if we're waiting for a search character
            if pendingCommand == "f" {
                if let pos = motionEngine.findCharacterForward(char, count: count) {
                    state.cursor.move(to: pos)
                    state.updateStatusMessage()
                }
                lastSearchChar = char
                lastSearchDirection = "f"
                pendingCommand = ""
                return true
            } else if pendingCommand == "F" {
                if let pos = motionEngine.findCharacterBackward(char, count: count) {
                    state.cursor.move(to: pos)
                    state.updateStatusMessage()
                }
                lastSearchChar = char
                lastSearchDirection = "F"
                pendingCommand = ""
                return true
            } else if pendingCommand == "t" {
                if let pos = motionEngine.tillCharacterForward(char, count: count) {
                    state.cursor.move(to: pos)
                    state.updateStatusMessage()
                }
                lastSearchChar = char
                lastSearchDirection = "t"
                pendingCommand = ""
                return true
            } else if pendingCommand == "T" {
                if let pos = motionEngine.tillCharacterBackward(char, count: count) {
                    state.cursor.move(to: pos)
                    state.updateStatusMessage()
                }
                lastSearchChar = char
                lastSearchDirection = "T"
                pendingCommand = ""
                return true
            } else if pendingCommand == "g" {
                // gg combination or case conversion or other g commands
                if char == "g" {
                    state.moveCursorToBeginningOfFile()
                } else if char == "u" {
                    // gu - start lowercase operator
                    operatorEngine.pendingOperator = .lowercase
                    operatorEngine.pendingCount = count
                    pendingCommand = ""
                    return true
                } else if char == "U" {
                    // gU - start uppercase operator
                    operatorEngine.pendingOperator = .uppercase
                    operatorEngine.pendingCount = count
                    pendingCommand = ""
                    return true
                } else if char == "_" {
                    // g_ - go to last non-whitespace on line
                    let line = state.buffer.line(state.cursor.position.line)
                    var lastNonWS = line.count - 1
                    while lastNonWS >= 0 && line[line.index(line.startIndex, offsetBy: lastNonWS)].isWhitespace {
                        lastNonWS -= 1
                    }
                    if lastNonWS >= 0 {
                        state.cursor.position.column = lastNonWS
                    }
                    state.updateStatusMessage()
                } else if char == "J" {
                    // gJ - join without spaces
                    state.saveUndoState()
                    let currentLine = state.cursor.position.line
                    if currentLine < state.buffer.lineCount - 1 {
                        let line1 = state.buffer.line(currentLine)
                        let line2 = state.buffer.line(currentLine + 1)
                        let joinedLine = line1 + line2
                        state.buffer.replaceLine(currentLine, with: joinedLine)
                        state.buffer.deleteLine(currentLine + 1)
                        state.cursor.position.column = line1.count
                        state.isDirty = true
                    }
                    state.updateStatusMessage()
                } else if char == "v" {
                    // gv - reselect last visual selection (simplified - just enter visual mode)
                    state.setMode(.visual)
                }
                pendingCommand = ""
                return true
            } else if pendingCommand == "r" {
                // Replace character under cursor
                state.saveUndoState()
                let pos = state.cursor.position
                if state.buffer.characterAt(pos) != nil {
                    state.buffer.deleteCharacter(at: pos)
                    state.buffer.insertCharacter(char, at: pos)
                    state.isDirty = true
                }
                pendingCommand = ""
                return true
            } else if waitingForRegisterName {
                // Register name selection
                let validNames = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
                if validNames.contains(char) {
                    selectedRegisterName = char
                }
                waitingForRegisterName = false
                return true
            } else if waitingForMarkName {
                // Mark name selection (a-z only)
                let markNames = Set("abcdefghijklmnopqrstuvwxyz")
                if markNames.contains(char) {
                    if markMode == "m" {
                        // Set a mark
                        state.marks[char] = state.cursor.position
                        state.updateStatusMessage()
                    } else if markMode == "'" {
                        // Jump to mark (linewise)
                        if let markPos = state.marks[char] {
                            state.cursor.move(to: Position(line: markPos.line, column: 0))
                            state.updateStatusMessage()
                        }
                    } else if markMode == "`" {
                        // Jump to mark (exact)
                        if let markPos = state.marks[char] {
                            state.cursor.move(to: markPos)
                            state.updateStatusMessage()
                        }
                    }
                }
                waitingForMarkName = false
                markMode = nil
                return true
            } else if let indentChar = pendingIndentChar, indentChar == char {
                // Handle >> and <<
                state.saveUndoState()
                for _ in 0..<count {
                    if indentChar == ">" {
                        state.buffer.indentLine(state.cursor.position.line)
                    } else {
                        state.buffer.unindentLine(state.cursor.position.line)
                    }
                }
                state.isDirty = true
                state.updateStatusMessage()
                pendingIndentChar = nil
                return true
            } else if pendingCommand == "z" {
                // z commands for viewport positioning
                let viewportHeight = 20  // Default reasonable height
                if char == "z" {
                    // zz - center cursor on screen
                    state.scrollOffset = max(0, state.cursor.position.line - viewportHeight / 2)
                } else if char == "t" {
                    // zt - cursor to top of screen
                    state.scrollOffset = state.cursor.position.line
                } else if char == "b" {
                    // zb - cursor to bottom of screen
                    state.scrollOffset = max(0, state.cursor.position.line - viewportHeight + 1)
                }
                state.updateStatusMessage()
                pendingCommand = ""
                return true
            }

            return false
        }
    }

    private func executeFindMotion(_ direction: Character, _ char: Character, _ count: Int) {
        switch direction {
        case "f":
            if let pos = motionEngine.findCharacterForward(char, count: count) {
                state.cursor.move(to: pos)
                state.updateStatusMessage()
            }
        case "F":
            if let pos = motionEngine.findCharacterBackward(char, count: count) {
                state.cursor.move(to: pos)
                state.updateStatusMessage()
            }
        case "t":
            if let pos = motionEngine.tillCharacterForward(char, count: count) {
                state.cursor.move(to: pos)
                state.updateStatusMessage()
            }
        case "T":
            if let pos = motionEngine.tillCharacterBackward(char, count: count) {
                state.cursor.move(to: pos)
                state.updateStatusMessage()
            }
        default:
            break
        }
    }

    override func enter() {
        // Set cursor to block for normal mode (ANSI: CSI 2 SP q)
        print("\u{001B}[2 q", terminator: "")
        fflush(stdout)

        pendingCommand = ""
        countPrefix = 0
    }

    override func exit() {
        pendingCommand = ""
        countPrefix = 0
        operatorEngine.pendingOperator = .none
        waitingForRegisterName = false
        selectedRegisterName = nil
        waitingForMarkName = false
        markMode = nil
        pendingIndentChar = nil
    }
}
