import Foundation

/// Handler for Visual mode
class VisualMode: BaseModeHandler {
    var startPosition: Position = Position()
    var forcedEndPosition: Position? = nil
    var isLineVisual: Bool = false
    var isBlockVisual: Bool = false

    override func handleInput(_ char: Character) -> Bool {
        // Any input clears the forced selection and makes it follow the cursor again
        forcedEndPosition = nil
        
        switch char {
        case "\u{1B}", "\u{03}":
            // Escape or Ctrl+C - return to normal mode
            // Ctrl+C (0x03) is the same byte as Ctrl+Shift+C in terminals
            state.setMode(.normal)
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
            state.saveUndoState()
            let (start, end) = selectionRange()
            state.buffer.deleteRange(from: start, to: end)
            state.cursor.move(to: start)
            state.isDirty = true
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
            state.saveUndoState()
            let (start, end) = selectionRange()
            state.buffer.deleteRange(from: start, to: end)
            state.cursor.move(to: start)
            state.isDirty = true
            state.setMode(.insert)
            return true

        default:
            return false
        }
    }

    override func enter() {
        startPosition = state.cursor.position
        isLineVisual = state.currentMode == .visualLine
        isBlockVisual = state.currentMode == .visualBlock
    }

    override func exit() {
        startPosition = Position()
        forcedEndPosition = nil
    }

    func selectionRange() -> (Position, Position) {
        let start = startPosition
        let end = forcedEndPosition ?? state.cursor.position

        // Correctly order start and end positions
        var (rangeStart, rangeEnd) = (start < end) ? (start, end) : (end, start)

        if isLineVisual {
            rangeStart.column = 0
            let lastLineLength = state.buffer.lineLength(rangeEnd.line)
            rangeEnd.column = max(0, lastLineLength - 1)
        } else if isBlockVisual {
            // Block mode logic (rectangular)
            // For now, return start/end as corners
        }

        return (rangeStart, rangeEnd)
    }
}
