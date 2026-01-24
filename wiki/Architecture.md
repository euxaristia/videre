# Architecture Overview

Vite is architected around clean separation of concerns, protocol-based design, and efficient data structures.

## System Architecture

```
┌─────────────────────────────────────────────┐
│             ViEditor (Main Loop)            │
│  - Terminal setup/teardown                  │
│  - Input reading & dispatch                 │
│  - Render loop                              │
│  - Signal handling (SIGWINCH)               │
└──────────────┬──────────────────────────────┘
               │
               ├──> InputDispatcher ───> Mode Handlers
               │         │                     │
               │         │          ┌──────────┴─────────┐
               │         └─────────>│   NormalMode       │
               │                    │   InsertMode       │
               │                    │   VisualMode       │
               │                    │   CommandMode      │
               │                    └────────────────────┘
               │
               └──> EditorState
                         │
                         ├──> TextBuffer (Gap Buffer)
                         ├──> Cursor
                         ├──> RegisterManager
                         ├──> MotionEngine
                         └──> OperatorEngine
```

## Core Components

### 1. ViEditor (UI/EditorApp.swift)

The main editor class that orchestrates everything:

- **Terminal Control**: Raw mode setup via `termios`
- **Input Loop**: Reads characters with `read()`
- **Render Loop**: Updates screen with ANSI escape sequences
- **Signal Handling**: Responds to `SIGWINCH` for terminal resize
- **Escape Sequence Parsing**: Converts arrow keys to motion characters

**Key Methods:**
- `run()` - Main event loop
- `setupTerminal()` - Configure raw mode
- `readCharacter()` - Parse input including escape sequences
- `render()` - Redraw screen
- `updateTerminalSize()` - Query terminal dimensions via `ioctl`

### 2. EditorState (Models/EditorState.swift)

Central state container holding all editor state:

```swift
class EditorState {
    var buffer: TextBuffer           // Text content
    var cursor: Cursor               // Cursor position
    var currentMode: EditorMode      // Active mode
    var statusMessage: String        // Status bar text
    var filePath: String?            // Current file
    var isDirty: Bool                // Unsaved changes
    var registerManager: RegisterManager
    var shouldExit: Bool
}
```

**Responsibilities:**
- Manages mode transitions
- Provides high-level text operations
- Tracks file state and modifications
- Updates status messages

### 3. TextBuffer (Core/TextBuffer/)

Gap buffer implementation for efficient text editing:

```swift
class TextBuffer {
    private var gapBuffer: GapBuffer

    // O(1) insert at cursor
    func insertCharacter(_ char: Character, at position: Position)

    // O(1) delete at cursor
    func deleteCharacter(at position: Position)

    // Line-oriented operations
    func line(_ index: Int) -> String
    func insertLine(_ text: String, at index: Int)
    func deleteLine(_ index: Int)
}
```

**Gap Buffer Internals:**
- Maintains a "gap" at cursor position
- Moving cursor relocates the gap
- Insertions/deletions happen at gap edges
- Efficient for sequential editing patterns

See [Gap Buffer](Gap-Buffer) for detailed explanation.

### 4. Mode Handlers (Core/Modes/)

Protocol-based architecture for input handling:

```swift
protocol ModeHandler {
    func handleInput(_ char: Character) -> Bool
    func enter()
    func exit()
}

class BaseModeHandler: ModeHandler {
    let state: EditorState
}
```

**Mode Implementations:**

- **NormalMode**: Command parsing, operator-motion combinations
- **InsertMode**: Character insertion, arrow key navigation
- **VisualMode**: Selection management (basic implementation)
- **CommandMode**: Colon-command parsing and execution

Each mode is self-contained and stateful.

### 5. Motion Engine (Engine/MotionEngine.swift)

Calculates cursor positions for all motion commands:

```swift
class MotionEngine {
    func nextWord(_ count: Int) -> Position
    func previousWord(_ count: Int) -> Position
    func endOfWord(_ count: Int) -> Position
    func findCharacterForward(_ char: Character, count: Int) -> Position?
    func goToLine(_ line: Int) -> Position
    // ... and more
}
```

**Motion Categories:**
- **Word**: `w`, `b`, `e`
- **Line**: `0`, `^`, `$`
- **File**: `gg`, `G`, `{n}G`
- **Character**: `f`, `F`, `t`, `T`, `;`

### 6. Operator Engine (Engine/OperatorEngine.swift)

Executes operators combined with motions:

```swift
class OperatorEngine {
    var pendingOperator: OperatorType  // d, y, c, or none
    var pendingCount: Int              // Count prefix

    func deleteWithMotion(_ char: Character)
    func yankWithMotion(_ char: Character)
    func changeWithMotion(_ char: Character)
}
```

**Operator Grammar:**
```
[count] operator [count] motion
  3       d         2       w      → delete 6 words (3 × 2)
          y         y              → yank line
  5       c         $              → change to end of line, repeat 5 times
```

### 7. Register Manager (Models/Register.swift)

Manages yank/paste storage:

```swift
enum RegisterContent {
    case characters(String)  // Character-wise yank
    case lines([String])     // Line-wise yank
}

class RegisterManager {
    func setUnnamedRegister(_ content: RegisterContent)
    func getUnnamedRegister() -> RegisterContent
}
```

Currently implements the unnamed register (`""`). Named registers (`"a`-`"z`) are on the roadmap.

## Data Flow

### Example: Typing "3dw" (Delete 3 Words)

1. **User presses '3'**
   - `readCharacter()` returns `'3'`
   - `InputDispatcher` → `NormalMode.handleInput('3')`
   - `NormalMode` stores `countPrefix = 3`

2. **User presses 'd'**
   - `NormalMode.handleInput('d')`
   - Sets `OperatorEngine.pendingOperator = .delete`
   - Stores `pendingCount = 3`

3. **User presses 'w'**
   - `NormalMode.handleInput('w')`
   - Calls `OperatorEngine.deleteWithMotion('w')`
   - `OperatorEngine`:
     - Calls `MotionEngine.nextWord(3)` → calculates end position
     - Calls `TextBuffer.deleteRange(from: cursor, to: endPos)`
     - Updates cursor position
   - Resets state (`pendingOperator = .none`, `countPrefix = 0`)

4. **Screen Update**
   - `render()` is called in next loop iteration
   - Clears screen, redraws buffer with new content
   - Updates status line

## Terminal Rendering

Vite uses ANSI escape sequences for rendering:

```swift
// Move to home position
print("\u{001B}[H", terminator: "")

// Clear screen
print("\u{001B}[2J", terminator: "")

// Dim text (faint line numbers)
print("\u{001B}[2m4  \u{001B}[0m", terminator: "")

// Inverse video (cursor)
print("\u{001B}[7m█\u{001B}[0m", terminator: "")

// Move to specific position
print("\u{001B}[24;1H", terminator: "")  // Row 24, Col 1

// Clear to end of line
print("\u{001B}[K")
```

**Rendering Strategy:**
1. Clear screen
2. Render visible lines (limited to terminal height)
3. Render faint tildes for empty lines
4. Render status bar at bottom
5. Flush output (`fflush(stdout)`)

**Optimization:**
- Only renders lines visible in terminal window
- Truncates long lines to terminal width
- Uses `\u{001B}[K` to clear line artifacts after resize

## Design Principles

### 1. Separation of Concerns

Each component has a single responsibility:
- `TextBuffer` knows nothing about cursor or modes
- `MotionEngine` calculates positions but doesn't modify text
- `OperatorEngine` coordinates but delegates to motion/buffer
- Modes handle input but delegate operations

### 2. Protocol-Based Extensibility

New modes can be added by conforming to `ModeHandler`:

```swift
class MyCustomMode: BaseModeHandler {
    override func handleInput(_ char: Character) -> Bool {
        // Custom logic
    }
}
```

### 3. Immutable Position Passing

Cursor positions are passed by value (`struct Position`), preventing accidental mutation:

```swift
struct Position {
    var line: Int
    var column: Int
}
```

### 4. Centralized State

All mutable state lives in `EditorState`, making it easy to:
- Serialize for undo/redo (future feature)
- Test individual components
- Reason about data flow

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Insert at cursor | O(1) | Gap buffer advantage |
| Delete at cursor | O(1) | Gap buffer advantage |
| Move cursor | O(n) | Gap relocation (n = distance) |
| Navigate word | O(m) | m = word length |
| Delete range | O(k) | k = range size |
| Render screen | O(lines) | Only visible lines |
| Search character | O(n) | n = line length |

**Memory:**
- Gap buffer overhead: ~2× content size (worst case)
- Typical overhead: ~1.2× (gap grows dynamically)

## Threading Model

Vite is **single-threaded** and **synchronous**:
- No locks or synchronization needed
- Simple mental model
- Predictable behavior

Input → Process → Render is a tight loop.

## Platform Abstractions

Cross-platform support via conditional compilation:

```swift
#if os(Linux)
import Glibc
ioctl(fd, UInt(TIOCGWINSZ), &ws)
#else
import Darwin
ioctl(fd, TIOCGWINSZ, &ws)
#endif
```

**Platform differences:**
- `ioctl` constants (Linux uses `UInt` wrapper)
- Signal handling (same API, different includes)
- `termios` flags (same structure)

## Future Architectural Enhancements

### Planned Additions

1. **Command Layer**: Abstraction for undoable operations
2. **Event System**: Hooks for plugins
3. **Configuration**: `.viterc` parser and settings registry
4. **Async I/O**: Background file loading for large files
5. **Syntax Engine**: Pluggable highlighting system

### Backward Compatibility

Architecture is designed for extension without breaking changes:
- Protocols allow multiple implementations
- Centralized state enables versioning
- Engines are swappable

## References

- [Gap Buffer Implementation](Gap-Buffer)
- [Mode System](Modal-Editing)
- [Motion Engine](API-MotionEngine)
- [Operator Engine](API-OperatorEngine)
