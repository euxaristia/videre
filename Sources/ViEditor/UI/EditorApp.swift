import Foundation

#if os(Linux)
import Glibc
#endif

/// Main editor application class
class ViEditor {
    let state: EditorState
    let inputDispatcher: InputDispatcher
    let modeManager: ModeManager
    let normalModeHandler: NormalModeHandler

    init(state: EditorState) {
        self.state = state
        self.inputDispatcher = InputDispatcher(state: state)
        self.modeManager = ModeManager(state: state)
        self.normalModeHandler = NormalModeHandler(state: state)

        state.setMode(.normal)
    }

    func run() {
        setupTerminal()
        defer { restoreTerminal() }

        while true {
            render()

            if let char = readCharacter() {
                let keyEvent = KeyEvent(character: char)
                inputDispatcher.dispatch(keyEvent)

                if inputDispatcher.shouldExit {
                    break
                }
            }
        }
    }

    // MARK: - Terminal Control

    private func setupTerminal() {
        // Disable canonical mode and echo
        var settings = termios()
        tcgetattr(STDIN_FILENO, &settings)
        settings.c_lflag &= ~tcflag_t(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &settings)

        // Clear screen and hide cursor
        print("\u{001B}[2J")
        print("\u{001B}[H")
        print("\u{001B}[?25l", terminator: "")
        fflush(stdout)
    }

    private func restoreTerminal() {
        // Restore canonical mode and echo
        var settings = termios()
        tcgetattr(STDIN_FILENO, &settings)
        settings.c_lflag |= tcflag_t(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &settings)

        // Clear screen and show cursor
        print("\u{001B}[2J")
        print("\u{001B}[H")
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    private func readCharacter() -> Character? {
        var buffer: [UInt8] = [0]
        let n = read(STDIN_FILENO, &buffer, 1)
        return n > 0 ? Character(UnicodeScalar(buffer[0])) : nil
    }

    private func render() {
        // Clear screen
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Render buffer
        for (lineIndex, _) in state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = state.buffer.line(lineIndex)
            let isCurrentLine = lineIndex == state.cursor.position.line

            // Line number
            print(String(format: "%4d ", lineIndex + 1), terminator: "")

            // Line content with cursor
            for (colIndex, char) in line.enumerated() {
                let isCursor = isCurrentLine && colIndex == state.cursor.position.column
                if isCursor {
                    print("\u{001B}[7m\(char)\u{001B}[0m", terminator: "")
                } else {
                    print(char, terminator: "")
                }
            }

            // Cursor at end of empty line
            if isCurrentLine && line.count == state.cursor.position.column {
                print("\u{001B}[7m \u{001B}[0m", terminator: "")
            }

            print()
        }

        // Status line
        print("\u{001B}[7m\(state.statusMessage)\u{001B}[0m", terminator: "")
        fflush(stdout)
    }
}

// MARK: - Input Handling

struct KeyEvent {
    let character: Character
}

class InputDispatcher {
    let state: EditorState
    var shouldExit = false
    var pendingCommand = ""

    init(state: EditorState) {
        self.state = state
    }

    func dispatch(_ event: KeyEvent) {
        switch state.currentMode {
        case .normal:
            dispatchNormal(event)
        case .insert:
            dispatchInsert(event)
        case .visual:
            dispatchVisual(event)
        case .command:
            dispatchCommand(event)
        }
    }

    private func dispatchNormal(_ event: KeyEvent) {
        let char = event.character

        switch char {
        case "h":
            state.moveCursorLeft()
        case "j":
            state.moveCursorDown()
        case "k":
            state.moveCursorUp()
        case "l":
            state.moveCursorRight()
        case "0":
            state.moveCursorToLineStart()
        case "$":
            state.moveCursorToLineEnd()
        case "g":
            pendingCommand = "g"
        case "G":
            if pendingCommand == "g" {
                state.moveCursorToBeginningOfFile()
            } else {
                state.moveCursorToEndOfFile()
            }
            pendingCommand = ""
        case "i":
            state.setMode(.insert)
        case "a":
            state.moveCursorRight()
            state.setMode(.insert)
        case "I":
            state.moveCursorToLineStart()
            state.setMode(.insert)
        case "A":
            state.moveCursorToLineEnd()
            state.moveCursorRight()
            state.setMode(.insert)
        case "o":
            state.moveCursorToLineEnd()
            state.insertNewLine()
            state.setMode(.insert)
        case "O":
            state.moveCursorToLineStart()
            let pos = state.cursor.position
            state.buffer.insertLine("", at: pos.line)
            state.setMode(.insert)
        case "x":
            state.deleteCharacter()
        case "d":
            state.deleteCurrentLine()
        case "p":
            // Paste (simplified for now)
            break
        case "u":
            // Undo (simplified for now)
            break
        case ":":
            state.setMode(.command)
            state.pendingCommand = ":"
        case "q":
            if pendingCommand == ":" {
                shouldExit = true
            }
        case "\u{1B}":
            // Escape
            pendingCommand = ""
        default:
            break
        }
    }

    private func dispatchInsert(_ event: KeyEvent) {
        let char = event.character

        switch char {
        case "\u{1B}":
            // Escape - return to normal mode
            state.setMode(.normal)
        case "\u{7F}", "\u{08}":
            // Backspace
            state.deleteBackward()
        case "\n":
            // Enter
            state.insertNewLine()
        default:
            state.insertCharacter(char)
        }
    }

    private func dispatchVisual(_ event: KeyEvent) {
        // Visual mode (to be implemented)
    }

    private func dispatchCommand(_ event: KeyEvent) {
        let char = event.character

        switch char {
        case "\u{1B}":
            // Escape
            state.setMode(.normal)
            state.pendingCommand = ""
        case "\n":
            // Execute command
            processCommand(state.pendingCommand)
            state.setMode(.normal)
            state.pendingCommand = ""
        default:
            state.pendingCommand.append(char)
        }
    }

    private func processCommand(_ command: String) {
        let cmd = command.trimmingCharacters(in: .whitespaces)

        switch cmd {
        case ":q", ":quit":
            shouldExit = true
        case ":w", ":write":
            // Save file (to be implemented)
            break
        case ":wq", ":wq!":
            // Save and quit
            shouldExit = true
        default:
            break
        }
    }
}

// MARK: - Mode Management

class ModeManager {
    let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    func switchMode(_ mode: EditorMode) {
        state.setMode(mode)
    }
}

// MARK: - Normal Mode Handler (placeholder)

class NormalModeHandler {
    let state: EditorState

    init(state: EditorState) {
        self.state = state
    }
}
