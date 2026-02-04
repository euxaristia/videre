import Foundation

/// Protocol for mode handlers
protocol ModeHandler {
    func handleInput(_ char: Character) -> Bool
    func enter()
    func exit()
}

/// Base mode handler implementation
class BaseModeHandler: ModeHandler {
    let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    func handleInput(_ char: Character) -> Bool {
        false
    }

    func enter() {}
    func exit() {}
}
