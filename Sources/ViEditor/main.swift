import Foundation

// MARK: - Entry Point

let editorState = EditorState()

// Load file if provided
if CommandLine.arguments.count > 1 {
    let filePath = CommandLine.arguments[1]
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: filePath) {
        do {
            editorState.buffer = TextBuffer(try String(contentsOfFile: filePath, encoding: .utf8))
            editorState.filePath = filePath
            editorState.isDirty = false
        } catch {
            print("E211: File not found: \"\(filePath)\"")
            exit(1)
        }
    } else {
        // File doesn't exist - start with empty buffer but set the filename
        // This matches vim behavior of creating a new file with that name
        editorState.filePath = filePath
        editorState.isDirty = false
    }
}

// Start editor
let editor = ViEditor(state: editorState)
editor.run()
