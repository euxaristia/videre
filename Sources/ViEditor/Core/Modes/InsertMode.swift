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

        case "\n":
            // Enter
            state.insertNewLine()
            state.updateStatusMessage()
            return true

        case "\t":
            // Tab - insert spaces
            for _ in 0..<4 {
                state.insertCharacter(" ")
            }
            state.updateStatusMessage()
            return true

        default:
            // Regular character
            state.insertCharacter(char)
            state.updateStatusMessage()
            return true
        }
    }

    override func enter() {
        // Cursor styling can be changed here for insert mode
    }

    override func exit() {
        // Move cursor back one position (vi behavior)
        if state.cursor.position.column > 0 {
            state.moveCursorLeft()
        }
    }
}
