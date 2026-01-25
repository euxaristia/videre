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

        // Register mode handlers with state for lifecycle management
        state.normalModeHandler = normalMode
        state.insertModeHandler = insertMode
        state.visualModeHandler = visualMode
        state.commandModeHandler = commandMode

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

        // Clear screen and show cursor
        print("\u{001B}[2J")
        print("\u{001B}[H")
        print("\u{001B}[?25h", terminator: "")
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
        if byte == 0x1B {  // ESC
            // Set non-blocking to check if more bytes follow
            let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
            _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)

            // Try to read the next byte
            var nextBuffer: [UInt8] = [0]
            let nextN = read(STDIN_FILENO, &nextBuffer, 1)

            // Restore blocking mode
            _ = fcntl(STDIN_FILENO, F_SETFL, flags)

            if nextN > 0 && nextBuffer[0] == 0x5B {  // '['
                // Read the final byte of the escape sequence
                var finalBuffer: [UInt8] = [0]
                let finalN = read(STDIN_FILENO, &finalBuffer, 1)

                if finalN > 0 {
                    switch finalBuffer[0] {
                    case 0x41: return "↑"  // Up arrow
                    case 0x42: return "↓"  // Down arrow
                    case 0x43: return "→"  // Right arrow
                    case 0x44: return "←"  // Left arrow
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

        // Reserve space for status line and command line (always reserve 2 lines to match Neovim)
        let availableLines = Int(terminalSize.rows) - 2
        let totalLines = state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false)
            .count

        // Render buffer (limited to available screen lines)
        if state.showWelcomeMessage {
            renderWelcomeMessage(availableLines: availableLines)
        } else {
            let gutterWidth = String(totalLines).count
            for lineIndex in 0..<min(totalLines, availableLines) {
                let line = state.buffer.line(lineIndex)

                // Line number (faint/dimmed)
                print("\u{001B}[2m", terminator: "")  // Dim mode
                print(String(format: "%\(gutterWidth)d ", lineIndex + 1), terminator: "")
                print("\u{001B}[0m", terminator: "")  // Reset

                // Line content with cursor (truncate if exceeds terminal width)
                let maxLineLength = Int(terminalSize.cols) - (gutterWidth + 1)  // Account for line numbers and space
                let displayLine = String(line.prefix(maxLineLength))

                // Print line content without manual cursor rendering
                print(displayLine, terminator: "")

                // Clear to end of line to handle terminal resize artifacts
                print("\u{001B}[K")
            }

            // Fill remaining lines with dim tildes (Neovim-style)
            for _ in totalLines..<availableLines {
                print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
            }
        }

        // Build status line (always shown)
        let statusWidth = Int(terminalSize.cols)
        let filename = state.filePath ?? "[No Name]"
        let modifiedFlag = state.isDirty ? " [+]" : ""
        let cursorPos = state.cursor.position

        // Match Neovim's specific '0,0-1' indexing/format from screenshots
        let lineCol = "\(cursorPos.line),\(cursorPos.column)-1"

        // Calculate position indicator (Top/All/Bot/percentage)
        let posIndicator: String
        if totalLines <= availableLines || state.showWelcomeMessage {
            posIndicator = "All"
        } else if cursorPos.line == 0 {
            posIndicator = "Top"
        } else if cursorPos.line >= totalLines - 1 {
            posIndicator = "Bot"
        } else {
            let percentage = (cursorPos.line + 1) * 100 / totalLines
            posIndicator = "\(percentage)%"
        }

        // Construct status line segments
        // Segment 1: "filename [+]"
        let segment1 = " \(filename)\(modifiedFlag) "
        // Segment 2: "line,col-1"
        let segment2 = "\(lineCol)"
        // Segment 3: "All" (or percentage)
        let segment3 = "\(posIndicator)"

        // Neovim default spacing: filename is left, (line,col and percentage) are right-aligned
        // There is usually a wider gap between the col and percentage
        let gapBetween2And3 = 12
        let rightPartWidth = segment2.count + gapBetween2And3 + segment3.count
        let flexiblePaddingSize = max(0, statusWidth - segment1.count - rightPartWidth)
        let flexiblePadding = String(repeating: " ", count: flexiblePaddingSize)

        // Final status line construction (no trailing space to ensure flush right)
        let statusLine =
            segment1 + flexiblePadding + segment2 + String(repeating: " ", count: gapBetween2And3)
            + segment3

        // Render status line (second to last line)
        // Using specific grey background (ANSI 250) and black text (ANSI 30) to match Neovim shading
        let statusLineRow = Int(terminalSize.rows) - 1
        print("\u{001B}[\(statusLineRow);1H", terminator: "")
        print(
            "\u{001B}[48;5;250m\u{001B}[30m\(statusLine.padding(toLength: statusWidth, withPad: " ", startingAt: 0))\u{001B}[0m",
            terminator: "")

        // Render command line or mode indicator (last line)
        print("\u{001B}[\(terminalSize.rows);1H", terminator: "")
        if state.currentMode == .command {
            print(state.pendingCommand, terminator: "")
        } else if state.currentMode == .insert {
            print("-- INSERT --", terminator: "")
        } else if state.currentMode == .visual {
            print("-- VISUAL --", terminator: "")
        }
        print("\u{001B}[K", terminator: "")  // Clear rest of line

        // Position the real terminal cursor
        if state.currentMode == .command {
            // In command mode, position cursor after the command text
            let commandCursorCol = state.pendingCommand.count + 1
            print("\u{001B}[\(terminalSize.rows);\(commandCursorCol)H", terminator: "")
        } else if !state.showWelcomeMessage {
            // In normal/insert/visual modes, position cursor at the actual cursor position
            let gutterWidth = String(totalLines).count
            let cursorRow = state.cursor.position.line + 1
            let cursorCol = gutterWidth + 1 + state.cursor.position.column + 1
            print("\u{001B}[\(cursorRow);\(cursorCol)H", terminator: "")
        }

        fflush(stdout)
    }

    private func renderWelcomeMessage(availableLines: Int) {
        let terminalCols = Int(terminalSize.cols)

        let message = [
            "VITE v0.1.0",
            "",
            "vite is open source and freely distributable",
            "https://github.com/euxaristia/vite",
            "",
            "type  :q<Enter>               to exit         ",
            "type  :help<Enter>            for help        ",
            "",
            "Maintainer: euxaristia",
        ]

        let startRow = (availableLines - message.count) / 2

        // Fill before message with tildes
        for _ in 0..<startRow {
            print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
        }

        // Render message centered
        for line in message {
            let padding = max(0, (terminalCols - line.count) / 2)
            print("\u{001B}[2m~\u{001B}[0m", terminator: "")  // Gutter tilde
            print(String(repeating: " ", count: padding - 1), terminator: "")
            print(line, terminator: "")
            print("\u{001B}[K")
        }

        // Fill after message with tildes
        for _ in (startRow + message.count)..<availableLines {
            print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
        }
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
        // Clear welcome message on editing actions, not on entering command mode
        // This matches Neovim behavior where : doesn't dismiss the welcome screen
        if state.currentMode == .normal && event.character != ":" {
            state.showWelcomeMessage = false
        } else if state.currentMode == .insert {
            state.showWelcomeMessage = false
        }

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
