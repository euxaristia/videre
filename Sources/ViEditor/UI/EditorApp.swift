import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Terminal window size structure
struct TerminalSize {
    var rows: UInt16 = 24
    var cols: UInt16 = 80
}

/// Global flag for terminal resize signal
private var terminalResized = false

/// Signal handler for SIGWINCH
private func handleResize(_ signal: Int32) {
    terminalResized = true
}

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
    var terminalSize: TerminalSize = TerminalSize()

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

        // Set up signal handler for terminal resize
        signal(SIGWINCH, handleResize)

        // Get initial terminal size
        updateTerminalSize()

        while true {
            // Check if terminal was resized
            if terminalResized {
                terminalResized = false
                updateTerminalSize()
            }

            render()

            if let char = readCharacter() {
                let keyEvent = KeyEvent(character: char)
                inputDispatcher.dispatch(keyEvent, editor: self)

                // Check if editor signaled exit
                if state.shouldExit {
                    break
                }
            }
        }
    }

    // MARK: - Terminal Size Management

    private func updateTerminalSize() {
        var ws = winsize()

        #if os(Linux)
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 {
            terminalSize.rows = ws.ws_row
            terminalSize.cols = ws.ws_col
        }
        #else
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 {
            terminalSize.rows = ws.ws_row
            terminalSize.cols = ws.ws_col
        }
        #endif
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
        guard n > 0 else { return nil }

        let byte = buffer[0]

        // Check for escape sequence
        if byte == 0x1B { // ESC
            // Set non-blocking to check if more bytes follow
            let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
            _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)

            // Try to read the next byte
            var nextBuffer: [UInt8] = [0]
            let nextN = read(STDIN_FILENO, &nextBuffer, 1)

            // Restore blocking mode
            _ = fcntl(STDIN_FILENO, F_SETFL, flags)

            if nextN > 0 && nextBuffer[0] == 0x5B { // '['
                // Read the final byte of the escape sequence
                var finalBuffer: [UInt8] = [0]
                let finalN = read(STDIN_FILENO, &finalBuffer, 1)

                if finalN > 0 {
                    switch finalBuffer[0] {
                    case 0x41: return "↑" // Up arrow
                    case 0x42: return "↓" // Down arrow
                    case 0x43: return "→" // Right arrow
                    case 0x44: return "←" // Left arrow
                    default: break
                    }
                }
            }
        }

        return Character(UnicodeScalar(byte))
    }

    private func render() {
        // Move to home and clear screen
        print("\u{001B}[H\u{001B}[2J", terminator: "")

        let availableLines = Int(terminalSize.rows) - 1 // Reserve one line for status
        let totalLines = state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false).count

        // Render buffer (limited to available screen lines)
        for lineIndex in 0..<min(totalLines, availableLines) {
            let line = state.buffer.line(lineIndex)
            let isCurrentLine = lineIndex == state.cursor.position.line

            // Line number (faint/dimmed)
            print("\u{001B}[2m", terminator: "") // Dim mode
            print(String(format: "%4d ", lineIndex + 1), terminator: "")
            print("\u{001B}[0m", terminator: "") // Reset

            // Line content with cursor (truncate if exceeds terminal width)
            let maxLineLength = Int(terminalSize.cols) - 6 // Account for line numbers and margin
            let displayLine = String(line.prefix(maxLineLength))

            for (colIndex, char) in displayLine.enumerated() {
                let isCursor = isCurrentLine && colIndex == state.cursor.position.column
                if isCursor {
                    print("\u{001B}[7m\(char)\u{001B}[0m", terminator: "")
                } else {
                    print(char, terminator: "")
                }
            }

            // Cursor at end of line
            if isCurrentLine && displayLine.count == state.cursor.position.column && state.cursor.position.column < maxLineLength {
                print("\u{001B}[7m \u{001B}[0m", terminator: "")
            }

            // Clear to end of line to handle terminal resize artifacts
            print("\u{001B}[K")
        }

        // Fill remaining lines with faint tildes (vim-style)
        for _ in totalLines..<availableLines {
            print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
        }

        // Build status line (Neovim format)
        let filename = state.filePath ?? "[No Name]"
        let modifiedFlag = state.isDirty ? "[+]" : ""
        let cursorPos = state.cursor.position
        let lineCol = "\(cursorPos.line + 1),\(cursorPos.column + 1)"

        // Calculate position indicator (Top/All/Bot/percentage)
        let posIndicator: String
        if totalLines <= availableLines {
            posIndicator = "All"
        } else if cursorPos.line == 0 {
            posIndicator = "Top"
        } else if cursorPos.line >= totalLines - 1 {
            posIndicator = "Bot"
        } else {
            let percentage = (cursorPos.line + 1) * 100 / totalLines
            posIndicator = "\(percentage)%"
        }

        // Construct status line
        let leftStatus = "\(filename)\(modifiedFlag)"
        let rightStatus = "\(lineCol)  \(posIndicator)"
        let statusWidth = Int(terminalSize.cols)
        let padding = max(0, statusWidth - leftStatus.count - rightStatus.count)
        let statusLine = leftStatus + String(repeating: " ", count: padding) + rightStatus

        // Move to status line position and render
        print("\u{001B}[\(terminalSize.rows);1H", terminator: "")
        print("\u{001B}[7m\(statusLine.prefix(statusWidth))\u{001B}[0m", terminator: "")

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
