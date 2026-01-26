import Foundation

/// Handler for Search mode (/ and ? search)
class SearchMode: BaseModeHandler {
    private var motionEngine: MotionEngine {
        MotionEngine(buffer: state.buffer, cursor: state.cursor)
    }

    private var initialCursorPosition: Position?

    override func handleInput(_ char: Character) -> Bool {
        switch char {
        case "\u{1B}":
            // Escape - cancel search
            if let initialPos = initialCursorPosition {
                state.cursor.move(to: initialPos)
            }
            state.searchPattern = ""
            state.setMode(.normal)
            return true

        case "\n", "\r":
            // Enter - execute search
            if !state.searchPattern.isEmpty {
                state.lastSearchPattern = state.searchPattern
                state.lastSearchDirection = state.searchDirection

                // Final search from initial position to ensure we land on the right match
                if let initialPos = initialCursorPosition {
                    state.cursor.move(to: initialPos)
                }

                if !executeSearch() {
                    state.statusMessage = "E486: Pattern not found: \(state.searchPattern)"
                    // If not found, stay where we were (already restored in executeSearch if failure is handled)
                    // But actually if performIncrementalSearch moved us, we might want to stay or revert.
                    // Vim reverts if you cancel, but Enter stays.
                }
            }
            state.searchPattern = ""
            state.currentMode = .normal
            return true

        case "\u{7F}", "\u{08}":
            // Backspace
            if !state.searchPattern.isEmpty {
                state.searchPattern.removeLast()
                updatePrompt()
                performIncrementalSearch()
            } else {
                if let initialPos = initialCursorPosition {
                    state.cursor.move(to: initialPos)
                }
                state.setMode(.normal)
            }
            return true

        default:
            // Add character to search pattern
            state.searchPattern.append(char)
            updatePrompt()
            performIncrementalSearch()
            return true
        }
    }

    private func performIncrementalSearch() {
        guard let initialPos = initialCursorPosition else { return }

        // Always search from initial position for incremental search
        state.cursor.move(to: initialPos)

        if !state.searchPattern.isEmpty {
            _ = executeSearch()
        }

        // rendering loop in EditorApp handles viewport visibility
    }

    private func updatePrompt() {
        let prefix = state.searchDirection == .forward ? "/" : "?"
        state.statusMessage = prefix + state.searchPattern
    }

    private func executeSearch() -> Bool {
        let pattern = state.searchPattern
        guard !pattern.isEmpty else { return false }

        if state.searchDirection == .forward {
            return searchForward(pattern: pattern)
        } else {
            return searchBackward(pattern: pattern)
        }
    }

    private func searchForward(pattern: String) -> Bool {
        let lines = state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let currentLine = state.cursor.position.line
        let currentCol = state.cursor.position.column

        // Search from current position to end
        for lineIdx in currentLine..<lines.count {
            let line = lineIdx < lines.count ? lines[lineIdx] : ""
            let startCol = lineIdx == currentLine ? currentCol + 1 : 0

            if startCol < line.count {
                let searchStart = line.index(line.startIndex, offsetBy: startCol)
                if let range = line.range(of: pattern, range: searchStart..<line.endIndex) {
                    let col = line.distance(from: line.startIndex, to: range.lowerBound)
                    state.cursor.move(to: Position(line: lineIdx, column: col))
                    state.updateStatusMessage()
                    return true
                }
            }
        }

        // Wrap around to beginning
        for lineIdx in 0...currentLine {
            let line = lineIdx < lines.count ? lines[lineIdx] : ""
            let endCol = lineIdx == currentLine ? currentCol : line.count

            if let range = line.range(of: pattern) {
                let col = line.distance(from: line.startIndex, to: range.lowerBound)
                if lineIdx < currentLine || col <= endCol {
                    state.cursor.move(to: Position(line: lineIdx, column: col))
                    state.statusMessage = "search hit BOTTOM, continuing at TOP"
                    return true
                }
            }
        }

        return false
    }

    private func searchBackward(pattern: String) -> Bool {
        let lines = state.buffer.text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let currentLine = state.cursor.position.line
        let currentCol = state.cursor.position.column

        // Search from current position to beginning
        for lineIdx in stride(from: currentLine, through: 0, by: -1) {
            let line = lineIdx < lines.count ? lines[lineIdx] : ""

            // Find last occurrence before current column
            var lastMatch: Int? = nil
            var searchStart = line.startIndex
            while let range = line.range(of: pattern, range: searchStart..<line.endIndex) {
                let col = line.distance(from: line.startIndex, to: range.lowerBound)
                if lineIdx == currentLine && col >= currentCol {
                    break
                }
                lastMatch = col
                searchStart = line.index(after: range.lowerBound)
                if searchStart >= line.endIndex { break }
            }

            if let col = lastMatch {
                state.cursor.move(to: Position(line: lineIdx, column: col))
                state.updateStatusMessage()
                return true
            }
        }

        // Wrap around to end
        for lineIdx in stride(from: lines.count - 1, through: currentLine, by: -1) {
            let line = lineIdx < lines.count ? lines[lineIdx] : ""

            // Find last occurrence
            var lastMatch: Int? = nil
            var searchStart = line.startIndex
            while let range = line.range(of: pattern, range: searchStart..<line.endIndex) {
                let col = line.distance(from: line.startIndex, to: range.lowerBound)
                if lineIdx == currentLine && col < currentCol {
                    searchStart = line.index(after: range.lowerBound)
                    if searchStart >= line.endIndex { break }
                    continue
                }
                lastMatch = col
                searchStart = line.index(after: range.lowerBound)
                if searchStart >= line.endIndex { break }
            }

            if let col = lastMatch {
                state.cursor.move(to: Position(line: lineIdx, column: col))
                state.statusMessage = "search hit TOP, continuing at BOTTOM"
                return true
            }
        }

        return false
    }

    /// Search for next occurrence (called by n in normal mode)
    func searchNext() -> Bool {
        guard !state.lastSearchPattern.isEmpty else {
            state.statusMessage = "E486: Pattern not found"
            return false
        }

        state.searchPattern = state.lastSearchPattern
        state.searchDirection = state.lastSearchDirection
        let found = executeSearch()
        state.searchPattern = ""

        if !found {
            state.statusMessage = "E486: Pattern not found: \(state.lastSearchPattern)"
        }
        return found
    }

    /// Search for previous occurrence (called by N in normal mode)
    func searchPrevious() -> Bool {
        guard !state.lastSearchPattern.isEmpty else {
            state.statusMessage = "E486: Pattern not found"
            return false
        }

        state.searchPattern = state.lastSearchPattern
        // Reverse direction
        state.searchDirection = state.lastSearchDirection == .forward ? .backward : .forward
        let found = executeSearch()
        state.searchPattern = ""
        // Restore original direction
        state.searchDirection = state.lastSearchDirection

        if !found {
            state.statusMessage = "E486: Pattern not found: \(state.lastSearchPattern)"
        }
        return found
    }

    override func enter() {
        // Set cursor to line for search mode (ANSI: CSI 6 SP q)
        print("\u{001B}[6 q", terminator: "")
        fflush(stdout)

        let prefix = state.searchDirection == .forward ? "/" : "?"
        state.statusMessage = prefix

        initialCursorPosition = state.cursor.position
    }

    override func exit() {
        state.statusMessage = ""
        initialCursorPosition = nil
    }
}
