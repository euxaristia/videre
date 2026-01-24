import Foundation

/// Handler for Command mode (: commands)
class CommandMode: BaseModeHandler {
    override func handleInput(_ char: Character) -> Bool {
        switch char {
        case "\u{1B}":
            // Escape
            state.setMode(.normal)
            state.pendingCommand = ""
            state.statusMessage = ""
            return true

        case "\n":
            // Execute command
            executeCommand(state.pendingCommand)
            state.setMode(.normal)
            state.pendingCommand = ""
            return true

        case "\u{7F}", "\u{08}":
            // Backspace
            if state.pendingCommand.count > 1 {
                state.pendingCommand.removeLast()
                state.statusMessage = state.pendingCommand
            }
            return true

        default:
            // Add character to command
            state.pendingCommand.append(char)
            state.statusMessage = state.pendingCommand
            return true
        }
    }

    private func executeCommand(_ commandStr: String) {
        let command = commandStr.trimmingCharacters(in: CharacterSet(charactersIn: ":")).trimmingCharacters(in: .whitespaces)

        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first ?? ""
        let arg = parts.count > 1 ? parts[1] : ""

        switch cmd {
        case "q", "quit":
            if state.isDirty {
                state.statusMessage = "No write since last change (add ! to override)"
            } else {
                state.statusMessage = ":q - exiting"
                // Signal exit via a property (handled by main loop)
            }

        case "q!", "quit!":
            state.statusMessage = ":q! - exiting"
            // Signal exit

        case "w", "write":
            if let filePath = state.filePath {
                do {
                    try state.buffer.text.write(toFile: filePath, atomically: true, encoding: .utf8)
                    state.isDirty = false
                    state.statusMessage = "\"\(filePath)\" \(state.buffer.lineCount) lines written"
                } catch {
                    state.statusMessage = "Error writing file: \(error)"
                }
            } else if !arg.isEmpty {
                do {
                    try state.buffer.text.write(toFile: arg, atomically: true, encoding: .utf8)
                    state.filePath = arg
                    state.isDirty = false
                    state.statusMessage = "\"\(arg)\" \(state.buffer.lineCount) lines written"
                } catch {
                    state.statusMessage = "Error writing file: \(error)"
                }
            } else {
                state.statusMessage = "No file name"
            }

        case "wq":
            if let filePath = state.filePath {
                do {
                    try state.buffer.text.write(toFile: filePath, atomically: true, encoding: .utf8)
                    state.isDirty = false
                    state.statusMessage = "Exiting"
                    // Signal exit
                } catch {
                    state.statusMessage = "Error writing file: \(error)"
                }
            } else {
                state.statusMessage = "No file name"
            }

        case "e", "edit":
            if !arg.isEmpty {
                do {
                    state.buffer = TextBuffer(try String(contentsOfFile: arg, encoding: .utf8))
                    state.filePath = arg
                    state.cursor.moveToBeginningOfFile()
                    state.isDirty = false
                    state.statusMessage = "Loaded \(arg)"
                } catch {
                    state.statusMessage = "Error loading file: \(error)"
                }
            }

        case "set":
            handleSetCommand(arg)

        default:
            if let lineNum = Int(cmd) {
                let pos = MotionEngine(buffer: state.buffer, cursor: state.cursor).goToLine(lineNum - 1)
                state.cursor.move(to: pos)
                state.statusMessage = ""
            } else {
                state.statusMessage = "Unknown command: \(cmd)"
            }
        }
    }

    private func handleSetCommand(_ arg: String) {
        // Placeholder for set commands
        state.statusMessage = "set command not yet implemented"
    }

    override func enter() {
        state.statusMessage = ":"
    }

    override func exit() {
        state.statusMessage = ""
        state.pendingCommand = ""
    }
}
