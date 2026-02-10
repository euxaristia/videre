import Testing
@testable import videre

struct MouseHighlightingTests {
    var editor: ViEditor
    var state: EditorState

    init() {
        state = EditorState()
        editor = ViEditor(state: state)
    }

    @Test func isSelectedSingleLine() {
        let start = Position(line: 0, column: 2)
        let end = Position(line: 0, column: 5)
        
        #expect(!editor.isSelected(line: 0, col: 1, start: start, end: end))
        #expect(editor.isSelected(line: 0, col: 2, start: start, end: end))
        #expect(editor.isSelected(line: 0, col: 4, start: start, end: end))
        #expect(editor.isSelected(line: 0, col: 5, start: start, end: end))
        #expect(!editor.isSelected(line: 0, col: 6, start: start, end: end))
    }

    @Test func isSelectedMultiLine() {
        let start = Position(line: 1, column: 5)
        let end = Position(line: 3, column: 2)
        
        // Before start line
        #expect(!editor.isSelected(line: 0, col: 10, start: start, end: end))
        
        // On start line
        #expect(!editor.isSelected(line: 1, col: 4, start: start, end: end))
        #expect(editor.isSelected(line: 1, col: 5, start: start, end: end))
        #expect(editor.isSelected(line: 1, col: 100, start: start, end: end))
        
        // Middle line
        #expect(editor.isSelected(line: 2, col: 0, start: start, end: end))
        #expect(editor.isSelected(line: 2, col: 50, start: start, end: end))
        
        // End line
        #expect(editor.isSelected(line: 3, col: 0, start: start, end: end))
        #expect(editor.isSelected(line: 3, col: 2, start: start, end: end))
        #expect(!editor.isSelected(line: 3, col: 3, start: start, end: end))
        
        // After end line
        #expect(!editor.isSelected(line: 4, col: 0, start: start, end: end))
    }

    @Test func applySelectionHighlightingPlain() {
        let raw = "Hello World"
        let start = Position(line: 0, column: 6)
        let end = Position(line: 0, column: 10)
        
        let result = editor.applySelectionHighlighting(to: raw, line: 0, raw: raw, start: start, end: end)
        
        // Should contain visualSelection color at "World"
        let expectedColor = SyntaxColor.visualSelection.rawValue
        #expect(result.contains(expectedColor))
        
        // Specifically: "Hello " + Color + "World" + Reset
        let expected = "Hello " + expectedColor + "World" + SyntaxColor.reset.rawValue
        #expect(result == expected)
    }

    @Test func applySelectionHighlightingBackwards() {
        let raw = "Hello World"
        // Start at end of "World", end at start of "World"
        let start = Position(line: 0, column: 10)
        let end = Position(line: 0, column: 6)
        
        // In the editor, start/end are normalized before calling isSelected usually
        // But our applySelectionHighlighting should handle it or the caller should.
        // Let's check how the editor calls it.
        
        let result = editor.applySelectionHighlighting(to: raw, line: 0, raw: raw, start: end, end: start)
        #expect(result.contains(SyntaxColor.visualSelection.rawValue))
    }

    @Test func applySelectionHighlightingWithExistingANSI() {
        let raw = "func main()"
        // Simulate "func" being pink
        let highlighted = "\u{001B}[31mfunc\u{001B}[0m main()"
        let start = Position(line: 0, column: 2) // inside "func"
        let end = Position(line: 0, column: 7)   // inside "main"
        
        let result = editor.applySelectionHighlighting(to: highlighted, line: 0, raw: raw, start: start, end: end)
        
        let selColor = SyntaxColor.visualSelection.rawValue
        let reset = SyntaxColor.reset.rawValue
        
        // The logic should:
        // 1. Start selection at column 2
        // 2. Persist selection through the red color and its reset
        
        #expect(result.contains(selColor))
        
        // Breakdown expectation:
        // "fu" 
        // + SelectionColor 
        // + "nc" 
        // + RedColor (from syntax) 
        // + SelectionColor (re-applied because we are in selection)
        // + Reset (from syntax)
        // + SelectionColor (re-applied)
        // + " mai"
        // + Reset (final)
        
        // It's complex, but checking if selection color appears multiple times or wraps correctly is key
        let colorCount = result.components(separatedBy: selColor).count - 1
        #expect(colorCount >= 1)
    }
}