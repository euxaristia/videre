import Foundation

/// Handler for Insert mode
class InsertMode: BaseModeHandler {
    override func handleInput(_ char: Character) -> Bool {
        switch char {
        case "\u{1B}":
            // Escape - return to normal mode
            state.setMode(.normal)
            return true

        case "\u{7F}", "\u{08}":
            // Backspace (DEL or Ctrl-H)
            state.deleteBackward()
            state.updateStatusMessage()
            return true

        case "⌦":
            // Delete key - delete character at cursor (to the right)
            state.deleteCharacter()
            state.updateStatusMessage()
            return true

        case "\n":
            // Enter
            state.insertNewLine()
            state.updateStatusMessage()
            return true

        case "\t":
            // Tab - insert spaces
            for _ in 0..<4 {
                state.insertCharacter(" ")
                state.moveCursorRight(count: 1)
            }
            state.updateStatusMessage()
            return true

        // Arrow key navigation in insert mode
        case "←":
            state.moveCursorLeft()
            state.updateStatusMessage()
            return true
        case "→":
            state.moveCursorRight()
            state.updateStatusMessage()
            return true
        case "↑":
            state.moveCursorUp()
            state.updateStatusMessage()
            return true
        case "↓":
            state.moveCursorDown()
            state.updateStatusMessage()
            return true

        default:
            // Regular character
            state.insertCharacter(char)
            state.moveCursorRight(count: 1)
            state.updateStatusMessage()
            return true
        }
    }

    override func enter() {
        // Change cursor to thin bar for insert mode (ANSI: CSI 6 SP q)
        print("\u{001B}[6 q", terminator: "")
        fflush(stdout)
    }

    override func exit() {
        // Restore block cursor for normal mode (ANSI: CSI 2 SP q)
        print("\u{001B}[2 q", terminator: "")
        fflush(stdout)

        // Move cursor back one position (vi behavior)
        if state.cursor.position.column > 0 {
            state.moveCursorLeft()
        }
    }
}
