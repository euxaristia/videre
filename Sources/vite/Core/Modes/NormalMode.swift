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
            case .none:
                break
            }
        }

        // Single character commands
        switch char {
        case "\u{01}":
            // Ctrl+A: Increment number
            state.incrementNextNumber(count: count)
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
            return true
        case "y":
            operatorEngine.pendingOperator = .yank
            operatorEngine.pendingCount = count
            return true
        case "c":
            operatorEngine.pendingOperator = .change
            operatorEngine.pendingCount = count
            return true

        // Delete commands
        case "x":
            for _ in 0..<count {
                state.deleteCharacter()
            }
            return true

        // Paste
        case "p":
            let content = state.registerManager.getUnnamedRegister()
            switch content {
            case .characters(let str):
                var pos = state.cursor.position
                pos.column += 1
                for char in str {
                    state.buffer.insertCharacter(char, at: pos)
                    pos.column += 1
                }
                state.cursor.move(to: pos)
            case .lines(let lines):
                var insertLine = state.cursor.position.line + 1
                for line in lines {
                    state.buffer.insertLine(line, at: insertLine)
                    insertLine += 1
                }
            }
            state.updateStatusMessage()
            return true

        case "P":
            let content = state.registerManager.getUnnamedRegister()
            switch content {
            case .characters(let str):
                var pos = state.cursor.position
                for char in str {
                    state.buffer.insertCharacter(char, at: pos)
                    pos.column += 1
                }
            case .lines(let lines):
                var insertLine = state.cursor.position.line
                for line in lines {
                    state.buffer.insertLine(line, at: insertLine)
                    insertLine += 1
                }
            }
            state.updateStatusMessage()
            return true

        // Visual mode
        case "v":
            state.setMode(.visual)
            return true
        case "V":
            state.setMode(.visualLine)
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
                // gg combination
                if char == "g" {
                    state.moveCursorToBeginningOfFile()
                }
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
    }
}
