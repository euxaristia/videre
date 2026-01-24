import Foundation

// MARK: - Entry Point

let editorState = EditorState()

// Load file if provided
if CommandLine.arguments.count > 1 {
    let filePath = CommandLine.arguments[1]
    do {
        editorState.buffer = TextBuffer(try String(contentsOfFile: filePath, encoding: .utf8))
        editorState.filePath = filePath
        editorState.isDirty = false
    } catch {
        print("Error loading file: \(error)")
        exit(1)
    }
}

// Start editor
let editor = ViEditor(state: editorState)
editor.run()
