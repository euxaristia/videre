import Foundation

#if os(Linux)
import Glibc
#endif

/// Main editor application class
class ViEditor {
    let state: EditorState
    let inputDispatcher: InputDispatcher
    let modeManager: ModeManager
    var normalMode: NormalMode
    var insertMode: InsertMode
    var visualMode: VisualMode
    var commandMode: CommandMode
    var shouldExit: Bool = false

    init(state: EditorState) {
        self.state = state
        self.inputDispatcher = InputDispatcher(state: state)
        self.modeManager = ModeManager(state: state)
        self.normalMode = NormalMode(state: state)
        self.insertMode = InsertMode(state: state)
        self.visualMode = VisualMode(state: state)
        self.commandMode = CommandMode(state: state)

        state.setMode(.normal)
    }

    func run() {
        setupTerminal()
        defer { restoreTerminal() }

        while true {
            render()

            if let char = readCharacter() {
                let keyEvent = KeyEvent(character: char)

                // Check if we should exit
                if state.currentMode == .command && state.pendingCommand.hasPrefix(":q") {
                    if state.pendingCommand == ":q" || state.pendingCommand == ":q!" {
                        shouldExit = true
                    }
                }

                inputDispatcher.dispatch(keyEvent, editor: self)

                if shouldExit {
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

    init(state: EditorState) {
        self.state = state
    }

    func dispatch(_ event: KeyEvent, editor: ViEditor) {
        switch state.currentMode {
        case .normal:
            _ = editor.normalMode.handleInput(event.character)
        case .insert:
            _ = editor.insertMode.handleInput(event.character)
        case .visual:
            _ = editor.visualMode.handleInput(event.character)
        case .command:
            _ = editor.commandMode.handleInput(event.character)
        }

        // Check for exit condition from command mode
        if state.currentMode == .command && state.pendingCommand == ":q" {
            editor.shouldExit = true
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
