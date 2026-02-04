import XCTest
@testable import vite

final class EditorStateTests: XCTestCase {
    func testMoveCursorDownDoesNotExceedEOF() {
        let state = EditorState()
        state.buffer = TextBuffer("one\ntwo")
        state.cursor.position.line = 1
        state.cursor.position.column = 0
        state.cursor.preferredColumn = 0

        state.moveCursorDown(count: 1)

        XCTAssertEqual(state.cursor.position.line, 1)
    }

    func testClampCursorToBufferForRender() {
        let state = EditorState()
        state.buffer = TextBuffer("only")
        state.cursor.position.line = 10
        state.cursor.position.column = 10
        state.cursor.preferredColumn = 10

        state.clampCursorToBufferForRender()

        XCTAssertEqual(state.cursor.position.line, 0)
        XCTAssertEqual(state.cursor.position.column, 3)
        XCTAssertEqual(state.cursor.preferredColumn, 3)
    }

    func testClampCursorToBufferForRenderWithTrailingEmptyLine() {
        let state = EditorState()
        state.buffer = TextBuffer("one\ntwo\n")
        state.cursor.position.line = 99
        state.cursor.position.column = 50
        state.cursor.preferredColumn = 50

        state.clampCursorToBufferForRender()

        XCTAssertEqual(state.cursor.position.line, 2)
        XCTAssertEqual(state.cursor.position.column, 0)
        XCTAssertEqual(state.cursor.preferredColumn, 0)
    }
}
