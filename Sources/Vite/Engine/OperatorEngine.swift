import Foundation

/// Operator types
enum OperatorType {
    case delete      // d
    case yank        // y
    case change      // c
    case none
}

/// Engine for executing operators (d, y, c) with motions
class OperatorEngine {
    let state: EditorState
    let motionEngine: MotionEngine
    var pendingOperator: OperatorType = .none
    var pendingCount: Int = 1

    init(state: EditorState) {
        self.state = state
        self.motionEngine = MotionEngine(buffer: state.buffer, cursor: state.cursor)
    }

    // MARK: - Operator Execution

    func executeDelete(from start: Position, to end: Position) {
        state.buffer.deleteRange(from: start, to: end)
        // Move cursor to start of deletion
        state.cursor.move(to: start)
        state.updateStatusMessage()
    }

    func executeDeleteLine(_ count: Int = 1) {
        for _ in 0..<count {
            state.deleteCurrentLine()
        }
    }

    func executeYank(from start: Position, to end: Position) -> RegisterContent {
        let text = state.buffer.substring(from: start, to: end)
        return .characters(text)
    }

    func executeYankLine(_ count: Int = 1) -> RegisterContent {
        var lines: [String] = []
        let startLine = state.cursor.position.line

        for i in 0..<count {
            if startLine + i < state.buffer.lineCount {
                lines.append(state.buffer.line(startLine + i))
            }
        }

        return .lines(lines)
    }

    func executeChange(from start: Position, to end: Position) {
        executeDelete(from: start, to: end)
        state.setMode(.insert)
    }

    // MARK: - Operator + Motion Combinations

    func deleteWithMotion(_ char: Character) {
        switch char {
        case "d":
            // dd - delete entire line
            executeDeleteLine(pendingCount)
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            executeDelete(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "0":
            let start = motionEngine.lineStart()
            executeDelete(from: start, to: state.cursor.position)
            pendingCount = 1
        case "$":
            let end = motionEngine.lineEnd()
            executeDelete(from: state.cursor.position, to: end)
            pendingCount = 1
        case "^":
            let start = motionEngine.firstNonWhitespace()
            executeDelete(from: start, to: state.cursor.position)
            pendingCount = 1
        default:
            pendingCount = 1
        }

        pendingOperator = .none
    }

    func yankWithMotion(_ char: Character) {
        var content: RegisterContent = .characters("")

        switch char {
        case "y":
            // yy - yank entire line
            content = executeYankLine(pendingCount)
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            content = executeYank(from: end, to: state.cursor.position)
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            content = executeYank(from: state.cursor.position, to: end)
        case "0":
            let start = motionEngine.lineStart()
            content = executeYank(from: start, to: state.cursor.position)
        case "$":
            let end = motionEngine.lineEnd()
            content = executeYank(from: state.cursor.position, to: end)
        case "^":
            let start = motionEngine.firstNonWhitespace()
            content = executeYank(from: start, to: state.cursor.position)
        default:
            break
        }

        // Store in register
        if !content.isEmpty {
            state.registerManager.setUnnamedRegister(content)
        }

        pendingCount = 1
        pendingOperator = .none
    }

    func changeWithMotion(_ char: Character) {
        switch char {
        case "c":
            // cc - change entire line
            executeDeleteLine(pendingCount)
            state.setMode(.insert)
            pendingCount = 1
        case "w":
            let end = motionEngine.nextWord(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "b":
            let end = motionEngine.previousWord(pendingCount)
            executeChange(from: end, to: state.cursor.position)
            pendingCount = 1
        case "e":
            let end = motionEngine.endOfWord(pendingCount)
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "0":
            let start = motionEngine.lineStart()
            executeChange(from: start, to: state.cursor.position)
            pendingCount = 1
        case "$":
            let end = motionEngine.lineEnd()
            executeChange(from: state.cursor.position, to: end)
            pendingCount = 1
        case "^":
            let start = motionEngine.firstNonWhitespace()
            executeChange(from: start, to: state.cursor.position)
            pendingCount = 1
        default:
            pendingCount = 1
        }

        pendingOperator = .none
    }

    // MARK: - Helpers

    private func isEmpty(_ content: RegisterContent) -> Bool {
        switch content {
        case .characters(let str):
            return str.isEmpty
        case .lines(let lines):
            return lines.isEmpty
        }
    }
}

extension RegisterContent {
    var isEmpty: Bool {
        switch self {
        case .characters(let str):
            return str.isEmpty
        case .lines(let lines):
            return lines.isEmpty
        }
    }
}
