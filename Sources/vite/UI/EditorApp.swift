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
        // Enable mouse tracking (SGR mode)
        print("\u{001B}[?1000h\u{001B}[?1006h", terminator: "")
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
        print("\u{001B}[?1006l\u{001B}[?1000l", terminator: "")
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

            // Restore blocking mode
            _ = fcntl(STDIN_FILENO, F_SETFL, flags)

            if nextN > 0 && nextBuffer[0] == 0x5B {  // '['
                // Read the next byte of the escape sequence
                var thirdBuffer: [UInt8] = [0]
                let thirdN = read(STDIN_FILENO, &thirdBuffer, 1)

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
            }
            // If we got here, it's just a plain ESC
            return "\u{1B}"
        }

        return Character(UnicodeScalar(byte))
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
        }

        return nil
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
                state.cursor.move(
                    to: Position(
                        line: bufferLine, column: min(bufferCol, max(0, lineLength - 1))))
                state.showWelcomeMessage = false
                state.updateStatusMessage()
            }
        }
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
        let totalLines = state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false)
            .count

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

        // Render buffer (limited to available screen lines)
        if state.showWelcomeMessage {
            renderWelcomeMessage(availableLines: availableLines)
        } else {
            let gutterWidth = String(totalLines).count
            for screenLine in 0..<availableLines {
                let lineIndex = state.scrollOffset + screenLine

                if lineIndex < totalLines {
                    let line = state.buffer.line(lineIndex)

                    // Line number (faint/dimmed)
                    print("\u{001B}[2m", terminator: "")  // Dim mode
                    print(String(format: "%\(gutterWidth)d ", lineIndex + 1), terminator: "")
                    print("\u{001B}[0m", terminator: "")  // Reset

                    // Line content with cursor (truncate if exceeds terminal width)
                    let maxLineLength = max(1, Int(terminalSize.cols) - (gutterWidth + 1))  // Account for line numbers and space
                    let displayLine = String(line.prefix(maxLineLength))

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

                    // Apply bracket highlighting
                    if !state.showWelcomeMessage {
                        if lineIndex == state.cursor.position.line {
                            finalLine = applyBracketHighlighting(
                                to: finalLine, col: state.cursor.position.column, raw: displayLine)
                        }
                        if let match = state.matchingBracketPosition, lineIndex == match.line {
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
        // Segment 1: "filename [+]"
        var segment1 = " \(filename)\(modifiedFlag) "
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
        }
        print("\u{001B}[K", terminator: "")  // Clear rest of line

        // Position the real terminal cursor
        if state.currentMode == .command {
            // In command mode, position cursor after the command text
            let commandCursorCol = state.pendingCommand.count + 1
            print("\u{001B}[\(terminalSize.rows);\(commandCursorCol)H", terminator: "")
        } else if state.currentMode == .search {
            // In search mode, position cursor after the search pattern
            let searchCursorCol = state.searchPattern.count + 2  // +1 for "/" prefix, +1 for 1-based
            print("\u{001B}[\(terminalSize.rows);\(searchCursorCol)H", terminator: "")
        } else if !state.showWelcomeMessage {
            // In normal/insert/visual modes, position cursor at the actual cursor position
            // Cursor row is relative to viewport (scroll offset)
            let gutterWidth = String(totalLines).count
            let cursorRow = state.cursor.position.line - state.scrollOffset + 1
            let cursorCol = gutterWidth + 1 + state.cursor.position.column + 1
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

        // Handle case where terminal is too small to show full message
        let linesToShow = min(message.count, availableLines)
        let startRow = max(0, (availableLines - linesToShow) / 2)

        // Fill before message with tildes
        for _ in 0..<startRow {
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
        // Clear welcome message on editing actions, not on entering command mode
        // This matches Neovim behavior where : and / don't dismiss the welcome screen
        if state.currentMode == .normal && event.character != ":" && event.character != "/"
            && event.character != "?"
        {
            state.showWelcomeMessage = false
        } else if state.currentMode == .insert {
            state.showWelcomeMessage = false
        }

        switch state.currentMode {
        case .normal:
            _ = editor.normalMode.handleInput(event.character)
        case .insert:
            _ = editor.insertMode.handleInput(event.character)
        case .visual, .visualLine:
            _ = editor.visualMode.handleInput(event.character)
        case .command:
            _ = editor.commandMode.handleInput(event.character)
        case .search:
            _ = editor.searchMode.handleInput(event.character)
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
