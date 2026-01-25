import Foundation

/// Represents a snapshot of editor state for undo/redo
struct UndoState {
    let text: String
    let cursorPosition: Position
}

/// Manages undo/redo history for the editor
class UndoManager {
    private var undoStack: [UndoState] = []
    private var redoStack: [UndoState] = []
    private let maxHistory: Int

    init(maxHistory: Int = 1000) {
        self.maxHistory = maxHistory
    }

    /// Save the current state before making changes
    func saveState(text: String, cursor: Position) {
        // Don't save duplicate states
        if let last = undoStack.last, last.text == text && last.cursorPosition == cursor {
            return
        }

        undoStack.append(UndoState(text: text, cursorPosition: cursor))

        // Limit history size
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }

        // Clear redo stack when new changes are made
        redoStack.removeAll()
    }

    /// Undo the last change and return the previous state
    func undo(currentText: String, currentCursor: Position) -> UndoState? {
        guard let previousState = undoStack.popLast() else { return nil }

        // Save current state to redo stack
        redoStack.append(UndoState(text: currentText, cursorPosition: currentCursor))

        return previousState
    }

    /// Redo the last undone change
    func redo(currentText: String, currentCursor: Position) -> UndoState? {
        guard let redoState = redoStack.popLast() else { return nil }

        // Save current state back to undo stack
        undoStack.append(UndoState(text: currentText, cursorPosition: currentCursor))

        return redoState
    }

    /// Check if undo is available
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Check if redo is available
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Clear all history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Number of undo states available
    var undoCount: Int {
        undoStack.count
    }

    /// Number of redo states available
    var redoCount: Int {
        redoStack.count
    }
}
