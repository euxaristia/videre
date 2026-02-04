import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(FreeBSD)
    import FreeBSD
#elseif canImport(Musl)
    import Musl
#elseif canImport(Glibc)
    import Glibc
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

// MARK: - Display Width Utilities

/// Calculate the terminal display width of a character
/// Wide characters (emoji, CJK) take 2 columns, most others take 1
private func displayWidth(of char: Character) -> Int {
    // Check for Variation Selector-16 (Emoji style) -> Force 2 columns
    if char.unicodeScalars.contains(where: { $0.value == 0xFE0F }) {
        return 2
    }

    guard let scalar = char.unicodeScalars.first else { return 1 }
    let value = scalar.value

    // Zero-width characters (combining marks, zero-width joiners, etc.)
    if (value >= 0x0300 && value <= 0x036F) ||  // Combining Diacritical Marks
       (value >= 0x200B && value <= 0x200F) ||  // Zero-width space, joiners, marks
       (value >= 0xFE00 && value <= 0xFE0F) ||  // Variation Selectors
       (value >= 0xE0100 && value <= 0xE01EF) { // Variation Selectors Supplement
        return 0
    }

    // Wide characters (2 columns)
    // Emoji ranges
    if (value >= 0x1F300 && value <= 0x1F9FF) ||  // Miscellaneous Symbols and Pictographs, Emoticons, etc.
       (value >= 0x1FA00 && value <= 0x1FAFF) ||  // Chess symbols, extended-A
       (value >= 0x231A && value <= 0x231B) ||    // Watch, Hourglass
       (value >= 0x23E9 && value <= 0x23F3) ||    // Various symbols
       (value >= 0x23F8 && value <= 0x23FA) ||    // Various symbols
       (value >= 0x25AA && value <= 0x25AB) ||    // Squares
       (value >= 0x25B6 && value == 0x25B6) ||    // Play button
       (value >= 0x25C0 && value == 0x25C0) ||    // Reverse button
       (value >= 0x25FB && value <= 0x25FE) ||    // Squares
       (value >= 0x2614 && value <= 0x2615) ||    // Umbrella, hot beverage
       (value >= 0x2648 && value <= 0x2653) ||    // Zodiac
       (value >= 0x267F && value == 0x267F) ||    // Wheelchair
       (value >= 0x2693 && value == 0x2693) ||    // Anchor
       (value >= 0x26A1 && value == 0x26A1) ||    // High voltage
       (value >= 0x26AA && value <= 0x26AB) ||    // Circles
       (value >= 0x26BD && value <= 0x26BE) ||    // Soccer, baseball
       (value >= 0x26C4 && value <= 0x26C5) ||    // Snowman, sun
       (value >= 0x26CE && value == 0x26CE) ||    // Ophiuchus
       (value >= 0x26D4 && value == 0x26D4) ||    // No entry
       (value >= 0x26EA && value == 0x26EA) ||    // Church
       (value >= 0x26F2 && value <= 0x26F3) ||    // Fountain, golf
       (value >= 0x26F5 && value == 0x26F5) ||    // Sailboat
       (value >= 0x26FA && value == 0x26FA) ||    // Tent
       (value >= 0x26FD && value == 0x26FD) ||    // Fuel pump
       (value >= 0x2702 && value == 0x2702) ||    // Scissors
       (value >= 0x2705 && value == 0x2705) ||    // Check mark
       (value >= 0x2708 && value <= 0x270D) ||    // Various
       (value >= 0x270F && value == 0x270F) ||    // Pencil
       (value >= 0x2712 && value == 0x2712) ||    // Black nib
       (value >= 0x2714 && value == 0x2714) ||    // Check mark
       (value >= 0x2716 && value == 0x2716) ||    // X mark
       (value >= 0x271D && value == 0x271D) ||    // Latin cross
       (value >= 0x2721 && value == 0x2721) ||    // Star of David
       (value >= 0x2728 && value == 0x2728) ||    // Sparkles
       (value >= 0x2733 && value <= 0x2734) ||    // Eight spoked asterisk
       (value >= 0x2744 && value == 0x2744) ||    // Snowflake
       (value >= 0x2747 && value == 0x2747) ||    // Sparkle
       (value >= 0x274C && value == 0x274C) ||    // Cross mark
       (value >= 0x274E && value == 0x274E) ||    // Cross mark
       (value >= 0x2753 && value <= 0x2755) ||    // Question marks
       (value >= 0x2757 && value == 0x2757) ||    // Exclamation mark
       (value >= 0x2763 && value <= 0x2764) ||    // Heart exclamation, heart
       (value >= 0x2795 && value <= 0x2797) ||    // Plus, minus, divide
       (value >= 0x27A1 && value == 0x27A1) ||    // Right arrow
       (value >= 0x27B0 && value == 0x27B0) ||    // Curly loop
       (value >= 0x27BF && value == 0x27BF) ||    // Double curly loop
       (value >= 0x2934 && value <= 0x2935) ||    // Arrows
       (value >= 0x2B05 && value <= 0x2B07) ||    // Arrows
       (value >= 0x2B1B && value <= 0x2B1C) ||    // Squares
       (value >= 0x2B50 && value == 0x2B50) ||    // Star
       (value >= 0x2B55 && value == 0x2B55) ||    // Circle
       (value >= 0x3030 && value == 0x3030) ||    // Wavy dash
       (value >= 0x303D && value == 0x303D) ||    // Part alternation mark
       (value >= 0x3297 && value == 0x3297) ||    // Circled Ideograph Congratulation
       (value >= 0x3299 && value == 0x3299) {     // Circled Ideograph Secret
        return 2
    }

    // CJK characters (2 columns)
    if (value >= 0x4E00 && value <= 0x9FFF) ||    // CJK Unified Ideographs
       (value >= 0x3400 && value <= 0x4DBF) ||    // CJK Unified Ideographs Extension A
       (value >= 0x20000 && value <= 0x2A6DF) ||  // CJK Unified Ideographs Extension B
       (value >= 0x2A700 && value <= 0x2CEAF) ||  // CJK Unified Ideographs Extensions C-F
       (value >= 0xF900 && value <= 0xFAFF) ||    // CJK Compatibility Ideographs
       (value >= 0x2F800 && value <= 0x2FA1F) ||  // CJK Compatibility Ideographs Supplement
       (value >= 0x3000 && value <= 0x303F) ||    // CJK Symbols and Punctuation
       (value >= 0xFF00 && value <= 0xFFEF) ||    // Halfwidth and Fullwidth Forms
       (value >= 0x1100 && value <= 0x11FF) ||    // Hangul Jamo
       (value >= 0xAC00 && value <= 0xD7AF) ||    // Hangul Syllables
       (value >= 0x3040 && value <= 0x309F) ||    // Hiragana
       (value >= 0x30A0 && value <= 0x30FF) ||    // Katakana
       (value >= 0x31F0 && value <= 0x31FF) {     // Katakana Phonetic Extensions
        return 2
    }

    // Default: 1 column
    return 1
}

/// Calculate the total display width of a string
private func displayWidth(of string: String) -> Int {
    var width = 0
    for char in string {
        width += displayWidth(of: char)
    }
    return width
}

/// Truncate a string to fit within a maximum display width
/// Returns the truncated string that fits within maxWidth terminal columns
private func truncateToDisplayWidth(_ string: String, maxWidth: Int) -> String {
    var width = 0
    var result = ""

    for char in string {
        let charWidth = displayWidth(of: char)
        if width + charWidth > maxWidth {
            break
        }
        result.append(char)
        width += charWidth
    }

    return result
}

/// Calculate display width of string up to a character index
/// Used for cursor positioning - converts character column to display column
private func displayWidthUpTo(_ string: String, charIndex: Int) -> Int {
    var width = 0
    for (index, char) in string.enumerated() {
        if index >= charIndex {
            break
        }
        width += displayWidth(of: char)
    }
    return width
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
    var searchMode: SearchMode
    var shouldExit: Bool = false
    var terminalSize: TerminalSize = TerminalSize()

    // ESC spam detection
    private var escPressCount = 0
    private var lastEscPressTime: Date = Date.distantPast

    init(state: EditorState) {
        self.state = state
        self.inputDispatcher = InputDispatcher(state: state)
        self.modeManager = ModeManager(state: state)
        self.normalMode = NormalMode(state: state)
        self.insertMode = InsertMode(state: state)
        self.visualMode = VisualMode(state: state)
        self.commandMode = CommandMode(state: state)
        self.searchMode = SearchMode(state: state)

        // Register mode handlers with state for lifecycle management
        state.normalModeHandler = normalMode
        state.insertModeHandler = insertMode
        state.visualModeHandler = visualMode
        state.commandModeHandler = commandMode
        state.searchModeHandler = searchMode

        // Initialize syntax highlighting based on file extension
        let language = SyntaxHighlighter.shared.detectLanguage(from: state.filePath)
        SyntaxHighlighter.shared.setLanguage(language)

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
                // If waiting for enter, any key (or just enter) clears it
                if state.isWaitingForEnter {
                    state.isWaitingForEnter = false
                    state.multiLineMessage = []
                    continue
                }

                // Handle ESC spam detection
                if char == "\u{1B}" {
                    let now = Date()
                    if now.timeIntervalSince(lastEscPressTime) < 0.5 {
                        escPressCount += 1
                    } else {
                        escPressCount = 1
                    }
                    lastEscPressTime = now

                    if escPressCount >= 5 {
                        state.showExitHint = true
                    }
                } else if char != Character(UnicodeScalar(0)) {
                    // Any other key clears the hint and count
                    escPressCount = 0
                    state.showExitHint = false
                }

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

        #if canImport(Glibc) || canImport(Musl)
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

        // Enter alternate screen buffer (saves current terminal content)
        print("\u{001B}[?1049h", terminator: "")
        // Enable mouse tracking (Button Event mode for dragging)
        print("\u{001B}[?1002h\u{001B}[?1006h", terminator: "")
        // Clear screen and show cursor
        print("\u{001B}[2J", terminator: "")
        print("\u{001B}[H", terminator: "")
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    private func restoreTerminal() {
        // Restore canonical mode and echo
        var settings = termios()
        tcgetattr(STDIN_FILENO, &settings)
        settings.c_lflag |= tcflag_t(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &settings)

        // Disable mouse tracking
        print("\u{001B}[?1006l\u{001B}[?1002l", terminator: "")
        // Leave alternate screen buffer (restores original terminal content)
        print("\u{001B}[?1049l", terminator: "")
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

            if nextN > 0 && nextBuffer[0] == 0x5B {  // '['
                // Read the next byte of the escape sequence (still in non-blocking mode)
                var thirdBuffer: [UInt8] = [0]
                let thirdN = read(STDIN_FILENO, &thirdBuffer, 1)

                // Restore blocking mode after reading the sequence
                _ = fcntl(STDIN_FILENO, F_SETFL, flags)

                if thirdN > 0 {
                    switch thirdBuffer[0] {
                    case 0x41: return "↑"  // Up arrow (ESC [ A)
                    case 0x42: return "↓"  // Down arrow (ESC [ B)
                    case 0x43: return "→"  // Right arrow (ESC [ C)
                    case 0x44: return "←"  // Left arrow (ESC [ D)
                    case 0x33:  // Could be Delete (ESC [ 3 ~)
                        var fourthBuffer: [UInt8] = [0]
                        let fourthN = read(STDIN_FILENO, &fourthBuffer, 1)
                        if fourthN > 0 && fourthBuffer[0] == 0x7E {  // '~'
                            return "⌦"  // Delete key
                        }
                    case 0x48: return "↖"  // Home (ESC [ H)
                    case 0x46: return "↘"  // End (ESC [ F)
                    case 0x3C:  // SGR Mouse Protocol (ESC [ < ...)
                        return readMouseSequence()
                    default: break
                    }
                }
            } else {
                // No escape sequence, restore blocking mode
                _ = fcntl(STDIN_FILENO, F_SETFL, flags)
            }
            // If we got here, it's just a plain ESC
            return "\u{1B}"
        }

        // Handle UTF-8 multi-byte sequences
        var bytes: [UInt8] = [byte]
        let expectedLen: Int

        if (byte & 0x80) == 0 {
            expectedLen = 1
        } else if (byte & 0xE0) == 0xC0 {
            expectedLen = 2
        } else if (byte & 0xF0) == 0xE0 {
            expectedLen = 3
        } else if (byte & 0xF8) == 0xF0 {
            expectedLen = 4
        } else {
            // Invalid start byte, treat as ISO-8859-1 (raw byte)
            return Character(UnicodeScalar(byte))
        }

        if expectedLen > 1 {
            // Read remaining bytes
            for _ in 1..<expectedLen {
                var nextByte: [UInt8] = [0]
                let nextN = read(STDIN_FILENO, &nextByte, 1)
                if nextN > 0 {
                    bytes.append(nextByte[0])
                } else {
                    // EOF or error in middle of sequence, return what we have as distinct chars?
                    // For simplicity, just return the first byte as fallback
                    return Character(UnicodeScalar(byte))
                }
            }
        }

        // Try to decode as UTF-8 string
        if let str = String(bytes: bytes, encoding: .utf8), let char = str.first {
            return char
        } else {
            // Fallback for invalid sequence
            return Character(UnicodeScalar(byte))
        }
    }

    private func readMouseSequence() -> Character? {
        var seq = ""
        var buffer: [UInt8] = [0]
        while true {
            let n = read(STDIN_FILENO, &buffer, 1)
            guard n > 0 else { break }
            let char = Character(UnicodeScalar(buffer[0]))
            seq.append(char)
            if char == "m" || char == "M" { break }
        }

        // Format is <button>;<x>;<y><m/M>
        let parts = seq.dropLast().split(separator: ";")
        guard parts.count == 3,
            let button = Int(parts[0]),
            let x = Int(parts[1]),
            let y = Int(parts[2])
        else { return nil }

        let isRelease = seq.last == "m"
        if button == 0 && !isRelease {
            // Left click press
            handleMouseClick(x: x, y: y)
        } else if button == 0 && isRelease {
            // Left click release
            state.isDragging = false
        } else if button == 32 {
            // Drag event (Left button moved)
            handleMouseDrag(x: x, y: y)
        } else if button == 64 {
            // Wheel Up
            handleMouseScroll(delta: -3)
        } else if button == 65 {
            // Wheel Down
            handleMouseScroll(delta: 3)
        }

        return nil
    }

    private func handleMouseScroll(delta: Int) {
        let availableLines = max(1, Int(terminalSize.rows) - 2)
        let totalLines = state.buffer.lineCount

        // Update scroll offset
        let oldOffset = state.scrollOffset
        state.scrollOffset = max(
            0, min(state.scrollOffset + delta, max(0, totalLines - availableLines)))

        // If scroll offset changed, adjust cursor if it went out of bounds
        if state.scrollOffset != oldOffset {
            let cursorLine = state.cursor.position.line
            if cursorLine < state.scrollOffset {
                state.cursor.position.line = state.scrollOffset
            } else if cursorLine >= state.scrollOffset + availableLines {
                state.cursor.position.line = state.scrollOffset + availableLines - 1
            }
            // Hard clamp to buffer in case viewport math overshoots.
            let maxLine = max(0, totalLines - 1)
            if state.cursor.position.line > maxLine {
                state.cursor.position.line = maxLine
            }
            if state.cursor.position.line < 0 {
                state.cursor.position.line = 0
            }
            // Maintain horizontal position using preferredColumn, clamped to new line length
            let lineLength = state.buffer.lineLength(state.cursor.position.line)
            let maxCol = state.currentMode == .insert ? lineLength : max(0, lineLength - 1)
            state.cursor.position.column = min(state.cursor.preferredColumn, maxCol)
            state.updateStatusMessage()
        }
    }

    private func handleMouseClick(x: Int, y: Int) {
        let terminalRows = Int(terminalSize.rows)
        let gutterWidth = String(state.buffer.lineCount).count

        // Check if click is within the buffer area (not status/command lines)
        let availableLines = max(1, terminalRows - 2)
        if y >= 1 && y <= availableLines {
            let bufferLine = state.scrollOffset + y - 1
            if bufferLine < state.buffer.lineCount {
                let bufferCol = max(0, x - (gutterWidth + 1) - 1)
                let lineLength = state.buffer.lineLength(bufferLine)
                let clickPos = Position(
                    line: bufferLine, column: min(bufferCol, max(0, lineLength - 1)))

                // Handle multi-click detection
                let now = Date()
                if now.timeIntervalSince(state.lastClickTime) < 0.5
                    && clickPos == state.lastClickPosition
                {
                    state.clickCount = (state.clickCount % 3) + 1
                } else {
                    state.clickCount = 1
                }
                state.lastClickTime = now
                state.lastClickPosition = clickPos

                // Process click based on count
                switch state.clickCount {
                case 1:
                    // Single click: move cursor and start potential drag
                    state.cursor.move(to: clickPos)
                    if state.currentMode != .normal {
                        state.setMode(.normal)
                    }
                    state.isDragging = true
                case 2:
                    // Double click: select word
                    state.selectWord(at: clickPos)
                    state.isDragging = true
                case 3:
                    // Triple click: select line
                    state.selectLine(at: clickPos)
                    state.isDragging = true
                default:
                    break
                }

                state.showWelcomeMessage = false
                state.updateStatusMessage()
            }
        }
    }

    private func handleMouseDrag(x: Int, y: Int) {
        guard state.isDragging else { return }

        let gutterWidth = String(state.buffer.lineCount).count

        // Determine destination position
        var bufferLine = state.scrollOffset + y - 1
        bufferLine = max(0, min(bufferLine, state.buffer.lineCount - 1))

        let bufferCol = max(0, x - (gutterWidth + 1) - 1)
        let lineLength = state.buffer.lineLength(bufferLine)
        let targetPos = Position(line: bufferLine, column: min(bufferCol, max(0, lineLength - 1)))

        // If not already in visual mode, enter visual mode
        if state.currentMode == .normal {
            state.setMode(.visual)
            if let visualHandler = state.visualModeHandler as? VisualMode {
                visualHandler.startPosition = state.cursor.position
            }
        }

        // Move cursor to drag position
        state.cursor.move(to: targetPos)
        state.updateStatusMessage()
    }

    private func render() {
        // Guard against extremely small terminals that would cause crashes
        guard terminalSize.rows >= 3 && terminalSize.cols >= 10 else {
            // Terminal too small - just show a minimal message
            print("\u{001B}[H\u{001B}[2J", terminator: "")
            print("Terminal too small", terminator: "")
            fflush(stdout)
            return
        }

        // Hide cursor during render to prevent flicker
        print("\u{001B}[?25l", terminator: "")

        // Move to home position (no full screen clear to reduce flicker)
        print("\u{001B}[H", terminator: "")

        // Reset syntax highlighter state for new render
        SyntaxHighlighter.shared.reset()

        // Reserve space for status line and command line (always reserve 2 lines to match Neovim)
        let availableLines = max(1, Int(terminalSize.rows) - 2)
        let totalLines = state.buffer.lineCount

        // Clamp cursor to buffer bounds before calculating viewport.
        state.clampCursorToBufferForRender()

        // Update scroll offset to keep cursor visible (viewport scrolling)
        let cursorLine = state.cursor.position.line
        if cursorLine < state.scrollOffset {
            // Cursor moved above viewport
            state.scrollOffset = cursorLine
        } else if cursorLine >= state.scrollOffset + availableLines {
            // Cursor moved below viewport
            state.scrollOffset = cursorLine - availableLines + 1
        }

        // Clamp scroll offset to valid range
        state.scrollOffset = max(0, min(state.scrollOffset, max(0, totalLines - availableLines)))

        // Defensive clamp: ensure cursor never points past EOF after scrolling math.
        let maxLine = max(0, totalLines - 1)
        if state.cursor.position.line > maxLine {
            state.cursor.position.line = maxLine
        }
        if state.cursor.position.line < 0 {
            state.cursor.position.line = 0
        }
        let lineLength = state.buffer.lineLength(state.cursor.position.line)
        let maxCol = state.currentMode == .insert ? lineLength : max(0, lineLength - 1)
        if state.cursor.position.column > maxCol {
            state.cursor.position.column = maxCol
        }
        if state.cursor.preferredColumn > maxCol {
            state.cursor.preferredColumn = maxCol
        }

        // Render buffer (limited to available screen lines)
        if state.showWelcomeMessage {
            renderWelcomeMessage(availableLines: availableLines)
        } else {
            // Don't show line numbers for empty [No Name] buffer (matches Neovim behavior)
            let isEmptyNoNameBuffer =
                state.filePath == nil && state.buffer.lineCount == 1 && state.buffer.line(0).isEmpty
            let gutterWidth = isEmptyNoNameBuffer ? 0 : String(totalLines).count
            for screenLine in 0..<availableLines {
                let lineIndex = state.scrollOffset + screenLine

                if lineIndex < totalLines {
                    let line = state.buffer.line(lineIndex)

                    // Line number (faint/dimmed) - skip for empty [No Name] buffer
                    if !isEmptyNoNameBuffer {
                        print("\u{001B}[2m", terminator: "")  // Dim mode
                        print(String(format: "%\(gutterWidth)d ", lineIndex + 1), terminator: "")
                        print("\u{001B}[0m", terminator: "")  // Reset
                    }

                    // Line content with cursor (truncate if exceeds terminal width)
                    let maxLineLength =
                        isEmptyNoNameBuffer
                        ? Int(terminalSize.cols)
                        : max(1, Int(terminalSize.cols) - (gutterWidth + 1))
                    let displayLine = truncateToDisplayWidth(line, maxWidth: maxLineLength)

                    // Apply syntax highlighting
                    let highlightedLine = SyntaxHighlighter.shared.highlightLine(displayLine)

                    // Apply visual selection if in visual mode
                    var finalLine: String
                    if let visualHandler = state.visualModeHandler as? VisualMode,
                        state.currentMode == .visual || state.currentMode == .visualLine
                    {
                        let (start, end) = visualHandler.selectionRange()
                        finalLine = applySelectionHighlighting(
                            to: highlightedLine, line: lineIndex, raw: displayLine, start: start,
                            end: end)
                    } else {
                        finalLine = highlightedLine
                    }

                    // Apply bracket highlighting (only when cursor is on a bracket)
                    if !state.showWelcomeMessage, let match = state.matchingBracketPosition {
                        if lineIndex == state.cursor.position.line {
                            finalLine = applyBracketHighlighting(
                                to: finalLine, col: state.cursor.position.column, raw: displayLine)
                        }
                        if lineIndex == match.line {
                            finalLine = applyBracketHighlighting(
                                to: finalLine, col: match.column, raw: displayLine)
                        }
                    }

                    // Apply search highlighting on top if there's an active search
                    let searchedLine = highlightSearchMatches(in: finalLine, raw: displayLine)
                    print(searchedLine, terminator: "")
                    print(SyntaxColor.reset.rawValue, terminator: "")
                } else {
                    // Beyond file end - show tilde
                    print("\u{001B}[2m~\u{001B}[0m", terminator: "")
                }

                // Clear to end of line to handle terminal resize artifacts
                print("\u{001B}[K")
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
        // Segment 1: "filename [+] [branch*]"
        let gitInfo = state.gitStatus.isEmpty ? "" : " [\(state.gitStatus)]"
        var segment1 = " \(filename)\(modifiedFlag)\(gitInfo) "
        if state.showExitHint {
            segment1 += "[press :q or ^C to exit] "
        }
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
        } else if state.currentMode == .search {
            let prefix = state.searchDirection == .forward ? "/" : "?"
            print(prefix + state.searchPattern, terminator: "")
        } else if state.currentMode == .insert {
            print("-- INSERT --", terminator: "")
        } else if state.currentMode == .visual {
            print("-- VISUAL --", terminator: "")
        } else if !state.statusMessage.isEmpty {
            print(state.statusMessage, terminator: "")
        }
        print("\u{001B}[K", terminator: "")  // Clear rest of line

        // Position the real terminal cursor
        if state.currentMode == .command {
            // In command mode, position cursor after the command text
            let commandCursorCol = displayWidth(of: state.pendingCommand) + 1
            print("\u{001B}[\(terminalSize.rows);\(commandCursorCol)H", terminator: "")
        } else if state.currentMode == .search {
            // In search mode, position cursor after the search pattern
            let searchCursorCol = displayWidth(of: state.searchPattern) + 2  // +1 for "/" prefix, +1 for 1-based
            print("\u{001B}[\(terminalSize.rows);\(searchCursorCol)H", terminator: "")
        } else {
            // In normal/insert/visual modes, position cursor at the actual cursor position
            // Cursor row is relative to viewport (scroll offset)
            let cursorRow = state.cursor.position.line - state.scrollOffset + 1
            // For welcome message/empty [No Name] buffer, cursor is at column 1 (no line numbers)
            // Otherwise, account for line number gutter
            let cursorCol: Int
            let currentLine = state.buffer.line(state.cursor.position.line)
            let displayCol = displayWidthUpTo(currentLine, charIndex: state.cursor.position.column)
            if state.showWelcomeMessage
                || (state.filePath == nil && state.buffer.lineCount == 1
                    && state.buffer.line(0).isEmpty)
            {
                cursorCol = displayCol + 1
            } else {
                let gutterWidth = String(totalLines).count
                cursorCol = gutterWidth + 1 + displayCol + 1
            }
            // Only position cursor if it's within the visible area
            if cursorRow >= 1 && cursorRow <= availableLines {
                print("\u{001B}[\(cursorRow);\(cursorCol)H", terminator: "")
            }
        }

        // Render multi-line messages if waiting for enter
        if state.isWaitingForEnter {
            renderHitEnterPrompt()
        }

        // Show cursor after render is complete
        print("\u{001B}[?25h", terminator: "")

        fflush(stdout)
    }

    private func renderWelcomeMessage(availableLines: Int) {
        let terminalCols = Int(terminalSize.cols)

        let message = [
            "VIDERE v0.1.0",
            "",
            "videre is open source and freely distributable",
            "https://github.com/euxaristia/videre",
            "",
            "type  :q<Enter>               to exit         ",
            "type  :help<Enter>            for help        ",
            "",
            "Maintainer: euxaristia",
        ]

        // Handle case where terminal is too small to show full message
        let linesToShow = min(message.count, max(0, availableLines - 1))  // -1 for first line with cursor
        let startRow = max(1, (availableLines - linesToShow) / 2)  // Start from row 1 (after cursor row)

        // First line: empty line for cursor (like Neovim)
        print("\u{001B}[K")

        // Fill before message with tildes (starting from row 1)
        for _ in 1..<startRow {
            print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
        }

        // Render message centered (only show what fits)
        for i in 0..<linesToShow {
            let line = message[i]
            let padding = max(1, (terminalCols - line.count) / 2)
            print("\u{001B}[2m~\u{001B}[0m", terminator: "")  // Gutter tilde
            print(String(repeating: " ", count: max(0, padding - 1)), terminator: "")
            print(String(line.prefix(max(1, terminalCols - padding))), terminator: "")
            print("\u{001B}[K")
        }

        // Fill after message with tildes
        let endRow = startRow + linesToShow
        if endRow < availableLines {
            for _ in endRow..<availableLines {
                print("\u{001B}[2m~\u{001B}[0m\u{001B}[K")
            }
        }
    }

    /// Apply search match highlighting to a line
    /// - Parameters:
    ///   - highlighted: The syntax-highlighted line (with ANSI codes)
    ///   - raw: The raw line without any highlighting
    /// - Returns: The line with search matches highlighted
    private func highlightSearchMatches(in highlighted: String, raw: String) -> String {
        // Use current search pattern during search mode (incremental search),
        // otherwise use last search pattern
        let pattern: String
        if state.currentMode == .search && !state.searchPattern.isEmpty {
            pattern = state.searchPattern
        } else if !state.lastSearchPattern.isEmpty {
            pattern = state.lastSearchPattern
        } else {
            return highlighted
        }

        // Find all match positions in the raw line
        var matches: [Range<String.Index>] = []
        var searchStart = raw.startIndex
        while let range = raw.range(of: pattern, range: searchStart..<raw.endIndex) {
            matches.append(range)
            searchStart = range.upperBound
            if searchStart >= raw.endIndex { break }
        }

        guard !matches.isEmpty else { return highlighted }

        // Build a new string with search highlighting
        // We need to map raw positions to highlighted positions, accounting for ANSI codes
        var result = ""
        var rawIndex = raw.startIndex
        var highlightedIndex = highlighted.startIndex
        var matchIndex = 0

        while rawIndex < raw.endIndex && highlightedIndex < highlighted.endIndex {
            // Skip ANSI escape sequences in highlighted string
            if highlighted[highlightedIndex] == "\u{001B}" {
                // Find end of escape sequence (ends with letter)
                var escEnd = highlighted.index(after: highlightedIndex)
                while escEnd < highlighted.endIndex {
                    let c = highlighted[escEnd]
                    if c.isLetter || c == "m" {
                        escEnd = highlighted.index(after: escEnd)
                        break
                    }
                    escEnd = highlighted.index(after: escEnd)
                }
                result += String(highlighted[highlightedIndex..<escEnd])
                highlightedIndex = escEnd
                continue
            }

            // Check if we're at a match start
            if matchIndex < matches.count && rawIndex == matches[matchIndex].lowerBound {
                // Start search highlight
                result += SyntaxColor.searchMatch.rawValue
            }

            // Add the character
            result += String(highlighted[highlightedIndex])
            rawIndex = raw.index(after: rawIndex)
            highlightedIndex = highlighted.index(after: highlightedIndex)

            // Check if we're at a match end
            if matchIndex < matches.count && rawIndex == matches[matchIndex].upperBound {
                // End search highlight and restore
                result += SyntaxColor.reset.rawValue
                matchIndex += 1
            }
        }

        // Append any remaining highlighted content
        if highlightedIndex < highlighted.endIndex {
            result += String(highlighted[highlightedIndex...])
        }

        return result
    }

    private func renderHitEnterPrompt() {
        let rows = Int(terminalSize.rows)
        let messages = state.multiLineMessage

        // Position at the bottom, above the last line if possible, or just start from bottom
        var currentRow = rows - messages.count
        if currentRow < 1 { currentRow = 1 }

        for msg in messages {
            print("\u{001B}[\(currentRow);1H\u{001B}[K\(msg)")
            currentRow += 1
        }

        // Final prompt
        print("\u{001B}[\(rows);1H\u{001B}[K", terminator: "")
        print("\u{001B}[1;32mPress ENTER or type command to continue\u{001B}[0m", terminator: "")
        fflush(stdout)
    }

    private func applyBracketHighlighting(to highlighted: String, col: Int, raw: String) -> String {
        var result = ""
        var rawIndex = raw.startIndex
        var highlightedIndex = highlighted.startIndex
        let targetCol = col

        while rawIndex < raw.endIndex && highlightedIndex < highlighted.endIndex {
            // Skip ANSI escape sequences
            if highlighted[highlightedIndex] == "\u{001B}" {
                var escEnd = highlighted.index(after: highlightedIndex)
                while escEnd < highlighted.endIndex {
                    let c = highlighted[escEnd]
                    if c.isLetter || c == "m" {
                        escEnd = highlighted.index(after: escEnd)
                        break
                    }
                    escEnd = highlighted.index(after: escEnd)
                }
                result += String(highlighted[highlightedIndex..<escEnd])
                highlightedIndex = escEnd
                continue
            }

            let currentCol = raw.distance(from: raw.startIndex, to: rawIndex)
            if currentCol == targetCol {
                result += SyntaxColor.bracketMatch.rawValue
                result += String(highlighted[highlightedIndex])
                result += SyntaxColor.reset.rawValue
            } else {
                result += String(highlighted[highlightedIndex])
            }

            rawIndex = raw.index(after: rawIndex)
            highlightedIndex = highlighted.index(after: highlightedIndex)
        }

        // Append remaining
        if highlightedIndex < highlighted.endIndex {
            result += String(highlighted[highlightedIndex...])
        }

        return result
    }

    private func applySelectionHighlighting(
        to highlighted: String, line: Int, raw: String, start: Position, end: Position
    ) -> String {
        // Find if this line is within the selection range
        guard line >= start.line && line <= end.line else { return highlighted }

        var result = ""
        var rawIndex = raw.startIndex
        var highlightedIndex = highlighted.startIndex

        // Initial background if start of selection is at the beginning of this line
        if isSelected(line: line, col: 0, start: start, end: end) {
            result += SyntaxColor.visualSelection.rawValue
        }

        while rawIndex < raw.endIndex && highlightedIndex < highlighted.endIndex {
            // Skip ANSI escape sequences in highlighted string
            if highlighted[highlightedIndex] == "\u{001B}" {
                var escEnd = highlighted.index(after: highlightedIndex)
                while escEnd < highlighted.endIndex {
                    let c = highlighted[escEnd]
                    if c.isLetter || c == "m" {
                        escEnd = highlighted.index(after: escEnd)
                        break
                    }
                    escEnd = highlighted.index(after: escEnd)
                }
                let escSeq = String(highlighted[highlightedIndex..<escEnd])
                result += escSeq

                // If the escape sequence was a reset, re-apply selection background if we're still in selection
                if escSeq == SyntaxColor.reset.rawValue || escSeq == "\u{001B}[0m" {
                    let col = raw.distance(from: raw.startIndex, to: rawIndex)
                    if isSelected(line: line, col: col, start: start, end: end) {
                        result += SyntaxColor.visualSelection.rawValue
                    }
                }

                highlightedIndex = escEnd
                continue
            }

            let col = raw.distance(from: raw.startIndex, to: rawIndex)
            let selected = isSelected(line: line, col: col, start: start, end: end)

            // Check if selection changed state
            if col > 0 {
                let prevSelected = isSelected(line: line, col: col - 1, start: start, end: end)
                if selected && !prevSelected {
                    result += SyntaxColor.visualSelection.rawValue
                } else if !selected && prevSelected {
                    result += SyntaxColor.reset.rawValue
                }
            }

            result += String(highlighted[highlightedIndex])

            rawIndex = raw.index(after: rawIndex)
            highlightedIndex = highlighted.index(after: highlightedIndex)
        }

        // Append remaining
        if highlightedIndex < highlighted.endIndex {
            result += String(highlighted[highlightedIndex...])
        }

        // Always reset at the end of the line if we were selecting
        if isSelected(line: line, col: max(0, raw.count - 1), start: start, end: end) {
            result += SyntaxColor.reset.rawValue
        }

        return result
    }

    private func isSelected(line: Int, col: Int, start: Position, end: Position) -> Bool {
        if line < start.line || line > end.line { return false }
        if line == start.line && line == end.line {
            return col >= start.column && col <= end.column
        }
        if line == start.line {
            return col >= start.column
        }
        if line == end.line {
            return col <= end.column
        }
        return true
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
        let originalMode = state.currentMode
        let handled: Bool
        switch state.currentMode {
        case .normal:
            handled = editor.normalMode.handleInput(event.character)
        case .insert:
            handled = editor.insertMode.handleInput(event.character)
        case .visual, .visualLine, .visualBlock:
            handled = editor.visualMode.handleInput(event.character)
        case .command:
            handled = editor.commandMode.handleInput(event.character)
        case .search:
            handled = editor.searchMode.handleInput(event.character)
        }

        // Clear welcome message on editing actions, not on entering command mode
        // This matches Neovim behavior where : and / don't dismiss the welcome screen
        if handled && state.showWelcomeMessage {
            if originalMode == .normal && event.character != ":" && event.character != "/"
                && event.character != "?"
            {
                state.showWelcomeMessage = false
            } else if originalMode == .insert {
                state.showWelcomeMessage = false
            }
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
