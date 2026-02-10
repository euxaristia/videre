import Testing
@testable import videre

struct EditorStateTests {
    @Test func moveCursorDownDoesNotExceedEOF() {
        let state = EditorState()
        state.buffer = TextBuffer("one\ntwo")
        state.cursor.position.line = 1
        state.cursor.position.column = 0
        state.cursor.preferredColumn = 0

        state.moveCursorDown(count: 1)

        #expect(state.cursor.position.line == 1)
    }

    @Test func clampCursorToBufferForRender() {
        let state = EditorState()
        state.buffer = TextBuffer("only")
        state.cursor.position.line = 10
        state.cursor.position.column = 10
        state.cursor.preferredColumn = 10

        state.clampCursorToBufferForRender()

        #expect(state.cursor.position.line == 0)
        #expect(state.cursor.position.column == 3)
        #expect(state.cursor.preferredColumn == 3)
    }

    @Test func clampCursorToBufferForRenderWithTrailingEmptyLine() {
        let state = EditorState()
        state.buffer = TextBuffer("one\ntwo\n")
        state.cursor.position.line = 99
        state.cursor.position.column = 50
        state.cursor.preferredColumn = 50

        state.clampCursorToBufferForRender()

        #expect(state.cursor.position.line == 2)
        #expect(state.cursor.position.column == 0)
        #expect(state.cursor.preferredColumn == 0)
    }
}