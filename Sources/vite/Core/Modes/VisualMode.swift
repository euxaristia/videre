import Foundation

/// Handler for Visual mode
class VisualMode: BaseModeHandler {
    var startPosition: Position = Position()
    var isLineVisual: Bool = false

    override func handleInput(_ char: Character) -> Bool {
        switch char {
        case "\u{1B}":
            // Escape - return to normal mode
            state.setMode(.normal)
            return true

        case "\u{01}":
            // Ctrl+A: Select All
            state.selectAll()
            return true

        case "h":
            state.moveCursorLeft()
            return true
        case "j":
            state.moveCursorDown()
            return true
        case "k":
            state.moveCursorUp()
            return true
        case "l":
            state.moveCursorRight()
            return true

        case "w":
            let motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
            let pos = motionEngine.nextWord()
            state.cursor.move(to: pos)
            return true
        case "b":
            let motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
            let pos = motionEngine.previousWord()
            state.cursor.move(to: pos)
            return true
        case "e":
            let motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
            let pos = motionEngine.endOfWord()
            state.cursor.move(to: pos)
            return true

        case "0":
            let motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
            let pos = motionEngine.lineStart()
            state.cursor.move(to: pos)
            return true
        case "$":
            let motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
            let pos = motionEngine.lineEnd()
            state.cursor.move(to: pos)
            return true

        case "d", "x":
            // Delete selection
            let (start, end) = selectionRange()
            state.buffer.deleteRange(from: start, to: end)
            state.cursor.move(to: start)
            state.setMode(.normal)
            return true

        case "y":
            // Yank selection
            let (start, end) = selectionRange()
            let text = state.buffer.substring(from: start, to: end)
            state.registerManager.setUnnamedRegister(.characters(text))
            state.setMode(.normal)
            return true

        case "c":
            // Change selection
            let (start, end) = selectionRange()
            state.buffer.deleteRange(from: start, to: end)
            state.cursor.move(to: start)
            state.setMode(.insert)
            return true

        default:
            return false
        }
    }

    override func enter() {
        startPosition = state.cursor.position
        isLineVisual = state.currentMode == .visual
    }

    override func exit() {
        startPosition = Position()
    }

    private func selectionRange() -> (Position, Position) {
        let start = startPosition
        let end = state.cursor.position

        if start.line < end.line || (start.line == end.line && start.column < end.column) {
            return (start, end)
        } else {
            return (end, start)
        }
    }
}
