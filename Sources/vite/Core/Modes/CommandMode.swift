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
            // Don't call setMode here as it will overwrite statusMessage
            // Instead, just change mode directly without updating status
            state.currentMode = .normal
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
        let command = commandStr.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespaces)

        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first ?? ""
        let arg = parts.count > 1 ? parts[1] : ""

        switch cmd {
        case "q", "quit":
            if state.isDirty {
                state.statusMessage = "E37: No write since last change (add ! to override)"
            } else {
                state.shouldExit = true
            }

        case "q!", "quit!":
            state.shouldExit = true

        case "w", "write":
            if let filePath = state.filePath {
                do {
                    try state.buffer.text.write(toFile: filePath, atomically: true, encoding: .utf8)
                    state.isDirty = false
                    state.statusMessage = "\"\(filePath)\" \(state.buffer.lineCount) lines written"
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(filePath)"
                }
            } else if !arg.isEmpty {
                do {
                    try state.buffer.text.write(toFile: arg, atomically: true, encoding: .utf8)
                    state.filePath = arg
                    state.isDirty = false
                    state.statusMessage = "\"\(arg)\" \(state.buffer.lineCount) lines written"
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(arg)"
                }
            } else {
                state.statusMessage = "E32: No file name"
            }

        case "wq":
            if let filePath = state.filePath {
                do {
                    try state.buffer.text.write(toFile: filePath, atomically: true, encoding: .utf8)
                    state.isDirty = false
                    state.shouldExit = true
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(filePath)"
                }
            } else if !arg.isEmpty {
                do {
                    try state.buffer.text.write(toFile: arg, atomically: true, encoding: .utf8)
                    state.filePath = arg
                    state.isDirty = false
                    state.shouldExit = true
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(arg)"
                }
            } else {
                state.statusMessage = "E32: No file name"
            }

        case "wq!":
            if let filePath = state.filePath {
                do {
                    try state.buffer.text.write(toFile: filePath, atomically: true, encoding: .utf8)
                    state.isDirty = false
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(filePath)"
                }
            } else if !arg.isEmpty {
                do {
                    try state.buffer.text.write(toFile: arg, atomically: true, encoding: .utf8)
                    state.filePath = arg
                    state.isDirty = false
                } catch {
                    state.statusMessage = "E212: Can't open file for writing: \(arg)"
                }
            } else {
                state.statusMessage = "E32: No file name"
            }
            state.shouldExit = true

        case "h", "help":
            loadHelp()

        case "e", "edit":
            if !arg.isEmpty {
                do {
                    state.buffer = TextBuffer(try String(contentsOfFile: arg, encoding: .utf8))
                    state.filePath = arg
                    state.cursor.moveToBeginningOfFile()
                    state.isDirty = false
                    state.statusMessage = "\"\(arg)\" \(state.buffer.lineCount) lines"
                    // Update syntax highlighting for new file
                    let language = SyntaxHighlighter.shared.detectLanguage(from: arg)
                    SyntaxHighlighter.shared.setLanguage(language)
                } catch {
                    state.statusMessage = "E211: File not found: \(arg)"
                }
            } else {
                state.statusMessage = "E471: Argument required"
            }

        case "set":
            handleSetCommand(arg)

        default:
            if let lineNum = Int(cmd) {
                let pos = MotionEngine(buffer: state.buffer, cursor: state.cursor).goToLine(
                    lineNum - 1)
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

    private func loadHelp() {
        let helpText = """
            VITE - help

                Move around:  Use the cursor keys, or "h" to go left,
                              "j" to go down, "k" to go up, "l" to go right.
            Close this window: Use ":q<Enter>".
              Get out of vite: Use ":qa!<Enter>" (careful, all changes are lost!).

            Get specific help: It is possible to go directly to whatever you want help
                              on, by giving an argument to the :help command.
                              (Not yet implemented in vite)

                   WHAT              EXAMPLE
                   Normal mode       :help x
                   Visual mode       :help v_u
                   Insert mode       :help i_<Esc>
                   Command-line      :help :quit

            Maintainer: euxaristia
            """
        state.buffer = TextBuffer(helpText)
        state.filePath = "help.txt"
        state.cursor.moveToBeginningOfFile()
        state.isDirty = false
        state.showWelcomeMessage = false
        state.statusMessage = "help.txt [Help][RO]"
    }

    override func enter() {
        state.statusMessage = ":"
    }

    override func exit() {
        state.statusMessage = ""
        state.pendingCommand = ""
    }
}
