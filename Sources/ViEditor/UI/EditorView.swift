import Foundation

/// Viewport for rendering editor content
class Viewport {
    let state: EditorState
    var width: Int = 80
    var height: Int = 24

    init(state: EditorState) {
        self.state = state
    }

    func render() {
        // This will be called from the main render loop
        // Rendering is now handled in EditorApp.run()
    }
}
