import Foundation

/// Handler for Search mode (/ and ? search)
class SearchMode: BaseModeHandler {
    private var motionEngine: MotionEngine {
        MotionEngine(buffer: state.buffer, cursor: state.cursor)
    }

    override func handleInput(_ char: Character) -> Bool {
        switch char {
        case "\u{1B}":
            // Escape - cancel search
            state.searchPattern = ""
            state.setMode(.normal)
            return true

        case "\n", "\r":
            // Enter - execute search
            if !state.searchPattern.isEmpty {
                state.lastSearchPattern = state.searchPattern
                state.lastSearchDirection = state.searchDirection
                if !executeSearch() {
                    state.statusMessage = "E486: Pattern not found: \(state.searchPattern)"
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
            }
            return true

        default:
            // Add character to search pattern
            state.searchPattern.append(char)
            updatePrompt()
            return true
        }
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
    }

    override func exit() {
        state.statusMessage = ""
    }
}
