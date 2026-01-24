# Modal Editing

Vite follows the Vi/Vim modal editing paradigm, where the editor operates in distinct modes with different behaviors.

## What is Modal Editing?

In traditional editors, keys always insert text. In modal editors:
- **Normal Mode**: Keys are commands (move, delete, copy)
- **Insert Mode**: Keys insert text
- **Other Modes**: Specialized behaviors (visual selection, command entry)

### Philosophy

Modal editing separates **navigation** from **insertion**:
- Most time is spent reading/navigating (Normal mode)
- Text insertion is brief (Insert mode)
- By default, optimize for navigation

**Benefits:**
- Powerful single-key commands (`dd`, `yy`, `p`)
- Composable operators and motions (`d3w`, `y$`)
- Keep hands on home row (no Ctrl/Alt chords)

## The Four Modes

### 1. Normal Mode ⚡

**Purpose**: Navigate and execute commands

**How to enter**: Press `ESC` from any mode

**Common commands:**

| Category | Commands | Description |
|----------|----------|-------------|
| **Motion** | `h` `j` `k` `l` | Left, down, up, right |
| | `w` `b` `e` | Word forward, backward, end |
| | `0` `^` `$` | Line start, first non-space, end |
| | `gg` `G` | File start, end |
| | `f{char}` `F{char}` | Find character forward/back |
| **Edit** | `x` | Delete character |
| | `dd` | Delete line |
| | `dw` | Delete word |
| | `d$` | Delete to end of line |
| | `yy` | Yank (copy) line |
| | `p` `P` | Paste after/before |
| **Mode Switch** | `i` `a` | Insert before/after cursor |
| | `I` `A` | Insert at line start/end |
| | `o` `O` | Open line below/above |
| | `v` `V` | Visual mode |
| | `:` | Command mode |

**State tracking:**
- Count prefix (e.g., `3` in `3dd`)
- Pending operator (e.g., `d` in `dw`)
- Pending command (e.g., `g` in `gg`)

**Implementation**: `Core/Modes/NormalMode.swift`

### 2. Insert Mode ✏️

**Purpose**: Insert text

**How to enter**: From Normal mode:
- `i` - Insert at cursor
- `a` - Append after cursor
- `I` - Insert at line start
- `A` - Append at line end
- `o` - Open line below
- `O` - Open line above

**How to exit**: Press `ESC` (returns to Normal mode)

**Available commands:**

| Key | Action |
|-----|--------|
| `ESC` | Exit to Normal mode |
| `Backspace` | Delete character before cursor |
| `Enter` | Insert newline |
| `Tab` | Insert 4 spaces |
| Arrow keys | Navigate (like Neovim) |
| Printable chars | Insert character |

**Behavior:**
- Characters are inserted at cursor
- Cursor advances after each character
- Exiting moves cursor left by 1 (Vi behavior)

**Implementation**: `Core/Modes/InsertMode.swift`

### 3. Visual Mode 👁️

**Purpose**: Select text for operations

**How to enter**: Press `v` (character) or `V` (line) from Normal mode

**Status**: Currently implemented but limited
- Enters Visual mode
- No operations yet implemented
- Roadmap: `d`, `y`, `c`, `>`, `<` on selections

**How to exit**: Press `ESC`

**Planned commands:**
- `d` - Delete selection
- `y` - Yank selection
- `c` - Change selection
- `>` - Indent
- `<` - Unindent

**Implementation**: `Core/Modes/VisualMode.swift`

### 4. Command Mode ⌨️

**Purpose**: Execute colon commands

**How to enter**: Press `:` from Normal mode

**How to exit**:
- Press `Enter` (execute command)
- Press `ESC` (cancel)

**Available commands:**

| Command | Action |
|---------|--------|
| `:w` | Write (save) file |
| `:w {file}` | Save as filename |
| `:e {file}` | Edit (open) file |
| `:q` | Quit (error if unsaved) |
| `:q!` | Quit without saving |
| `:wq` | Write and quit |
| `:{number}` | Go to line number |

**Command parsing:**
- Split on first space: `cmd arg`
- Example: `:w myfile.txt` → cmd=`w`, arg=`myfile.txt`

**Error messages:**
- Vim-compatible error codes
- Example: `E37: No write since last change`

**Implementation**: `Core/Modes/CommandMode.swift`

## Mode Transitions

```
┌─────────────────────────────────────────────┐
│                                             │
│                 NORMAL MODE                 │
│              (default/home base)            │
│                                             │
└─┬─────┬─────────────┬────────────────┬──────┘
  │     │             │                │
  │ i,a │         :   │            v,V │
  │ I,A │             │                │
  │ o,O │             │                │
  ↓     ↓             ↓                ↓
┌────────┐      ┌──────────┐    ┌─────────┐
│ INSERT │      │ COMMAND  │    │ VISUAL  │
│  MODE  │      │   MODE   │    │  MODE   │
└────────┘      └──────────┘    └─────────┘
    │                 │               │
    │ESC              │ESC/Enter      │ESC
    └─────────────────┴───────────────┘
                      ↓
                 NORMAL MODE
```

**Rule**: `ESC` always returns to Normal mode

## Implementation Details

### Mode Protocol

All modes conform to `ModeHandler`:

```swift
protocol ModeHandler {
    func handleInput(_ char: Character) -> Bool
    func enter()
    func exit()
}

class BaseModeHandler: ModeHandler {
    let state: EditorState

    func handleInput(_ char: Character) -> Bool {
        fatalError("Must override")
    }

    func enter() {}
    func exit() {}
}
```

### Mode Switching

Mode changes go through `EditorState`:

```swift
func setMode(_ mode: EditorMode) {
    // Call exit() on old mode
    currentMode.exit()

    // Switch mode
    currentMode = mode

    // Call enter() on new mode
    currentMode.enter()

    // Update status
    updateStatusMessage()
}
```

### Input Dispatch

`InputDispatcher` routes input to the active mode:

```swift
func dispatch(_ event: KeyEvent, editor: ViEditor) {
    switch state.currentMode {
    case .normal:
        editor.normalMode.handleInput(event.character)
    case .insert:
        editor.insertMode.handleInput(event.character)
    case .visual:
        editor.visualMode.handleInput(event.character)
    case .command:
        editor.commandMode.handleInput(event.character)
    }
}
```

## Modal Editing Patterns

### Pattern 1: Navigate and Edit

```
1. Start in Normal mode
2. Navigate to target: 5j (down 5 lines)
3. Switch to Insert: i
4. Type changes
5. Return to Normal: ESC
6. Save: :w
```

### Pattern 2: Operator-Motion Composition

```
1. Normal mode
2. Delete 3 words: 3dw
   - '3' sets count prefix
   - 'd' sets operator (delete)
   - 'w' executes motion (word forward)
3. Result: 3 words deleted, stay in Normal mode
```

### Pattern 3: Repeatable Edits

```
1. Normal mode
2. Change word: ciw
3. Type replacement: "newtext"
4. ESC to Normal
5. Move to next word: w
6. Repeat change: . (planned feature)
```

### Pattern 4: Bulk Operations

```
1. Normal mode
2. Visual mode: V
3. Select 5 lines: 5j
4. Delete: d (planned)
5. Back to Normal mode
```

## Why Modal Editing?

### Advantages

**1. Efficiency**
- Single-key commands: `dd` vs `Ctrl+Shift+K`
- Composable grammar: `d5w` vs "select 5 words, delete"
- Stay on home row: no Ctrl/Alt acrobatics

**2. Expressiveness**
- Operators (`d`, `y`, `c`) × Motions (`w`, `$`, `f{char}`)
- Counts multiply everything: `3d2w` (delete 6 words)
- Semantic commands: "delete to end of line" = `d$`

**3. Discoverability**
- Commands have mnemonic names: `d` = delete, `y` = yank, `w` = word
- Consistent grammar across all operators
- Predictable behavior

### Learning Curve

**Initial**: Steeper than modeless editors
- Must remember mode state
- `ESC` becomes muscle memory
- hjkl navigation feels odd at first

**After 1 week**: Productivity matches modeless editors

**After 1 month**: Significantly faster
- Muscle memory for common commands
- Comfortable with operator-motion grammar
- Can edit without thinking about modes

**After 6 months**: Efficiency gains compound
- Complex edits in single commands
- Rarely touch the mouse
- Mode switching becomes unconscious

## Customization

### Adding a New Mode

1. Create mode handler:
   ```swift
   class MyMode: BaseModeHandler {
       override func handleInput(_ char: Character) -> Bool {
           // Handle input
       }
   }
   ```

2. Add to `EditorMode` enum:
   ```swift
   enum EditorMode {
       case normal, insert, visual, command, myMode
   }
   ```

3. Register in `ViEditor`:
   ```swift
   var myMode: MyMode

   init(state: EditorState) {
       self.myMode = MyMode(state: state)
       // ...
   }
   ```

4. Update `InputDispatcher`:
   ```swift
   case .myMode:
       editor.myMode.handleInput(event.character)
   ```

### Mode-Specific Behavior

Override `enter()` and `exit()`:

```swift
class InsertMode: BaseModeHandler {
    override func enter() {
        // Called when entering Insert mode
        // Could change cursor shape, etc.
    }

    override func exit() {
        // Called when leaving Insert mode
        // Vi behavior: move cursor left
        if state.cursor.position.column > 0 {
            state.moveCursorLeft()
        }
    }
}
```

## Common Pitfalls

### Pitfall 1: Stuck in Insert Mode

**Symptom**: Keys insert "jjjjj" instead of moving down

**Cause**: Still in Insert mode

**Solution**: Press `ESC` to return to Normal mode

### Pitfall 2: Unexpected Deletions

**Symptom**: Pressed `d` and nothing happened, then `w` deleted a word

**Cause**: `d` starts an operator, waiting for motion

**Solution**: Press `ESC` to cancel operator, or complete the command

### Pitfall 3: Can't Type Colon

**Symptom**: Pressing `:` doesn't insert a colon

**Cause**: In Normal mode, `:` enters Command mode

**Solution**: Enter Insert mode first (`i`), then type `:`

## Further Reading

- [Keybindings Reference](Keybindings)
- [Normal Mode Commands](Commands)
- [Motions Guide](Motions)
- [Operators Guide](Operators)

## Related Documentation

- [Architecture](Architecture)
- [Quick Start](Quick-Start)
- [API: Mode Handlers](API-Modes)
