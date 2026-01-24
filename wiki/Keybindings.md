# Keybindings Reference

Complete reference of all keybindings in Vite, organized by mode.

## Normal Mode

### Cursor Movement

#### Basic Motion

| Key | Action | Example |
|-----|--------|---------|
| `h` | Move left | `h` → left 1 char |
| `j` | Move down | `j` → down 1 line |
| `k` | Move up | `k` → up 1 line |
| `l` | Move right | `l` → right 1 char |
| `←` | Move left (arrow) | Same as `h` |
| `↓` | Move down (arrow) | Same as `j` |
| `↑` | Move up (arrow) | Same as `k` |
| `→` | Move right (arrow) | Same as `l` |

**Count prefix supported**: `5j` = down 5 lines

#### Word Motion

| Key | Action | Example |
|-----|--------|---------|
| `w` | Next word start | `word1 word2`<br> &nbsp;&nbsp;&nbsp;`↑` → `↑` |
| `b` | Previous word start | `word1 word2`<br> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`↑` → `↑` |
| `e` | Next word end | `word1 word2`<br> &nbsp;&nbsp;&nbsp;`↑` → &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`↑` |

**Word definition**: Sequence of `[A-Za-z0-9_]`

**Count prefix**: `3w` = forward 3 words

#### Line Motion

| Key | Action | Description |
|-----|--------|-------------|
| `0` | Line start | Jump to column 0 |
| `^` | First non-whitespace | Skip leading spaces/tabs |
| `$` | Line end | Jump to last character |

**No count prefix** (these are absolute positions)

#### File Motion

| Key | Action | Description |
|-----|--------|-------------|
| `gg` | File start | Jump to line 1 |
| `G` | File end | Jump to last line |
| `{n}G` | Line n | `50G` = line 50 |

**Examples**:
- `gg` → top of file
- `G` → bottom of file
- `1G` → line 1 (same as `gg`)
- `100G` → line 100

#### Character Search

| Key | Action | Description |
|-----|--------|-------------|
| `f{char}` | Find forward | Find next `{char}` on line |
| `F{char}` | Find backward | Find previous `{char}` on line |
| `t{char}` | Till forward | Jump to before next `{char}` |
| `T{char}` | Till backward | Jump to after previous `{char}` |
| `;` | Repeat find | Repeat last `f/F/t/T` |

**Count prefix**: `3fx` = 3rd occurrence of 'x'

**Examples**:
- `fa` → find next 'a'
- `Fb` → find previous 'b'
- `t(` → jump to before next '('
- `T)` → jump to after previous ')'
- `;` → repeat last search

### Editing Commands

#### Insert Mode Entry

| Key | Action | Description |
|-----|--------|-------------|
| `i` | Insert | Insert at cursor |
| `a` | Append | Insert after cursor |
| `I` | Insert line start | Insert at beginning of line |
| `A` | Append line end | Insert at end of line |
| `o` | Open below | Open new line below cursor |
| `O` | Open above | Open new line above cursor |

#### Deletion

| Key | Action | Description |
|-----|--------|-------------|
| `x` | Delete char | Delete character under cursor |
| `X` | Delete back | Delete character before cursor (planned) |

**Count prefix**: `5x` = delete 5 characters

#### Operators

| Operator | Action | Description |
|----------|--------|-------------|
| `d{motion}` | Delete | Delete with motion |
| `y{motion}` | Yank | Copy with motion |
| `c{motion}` | Change | Delete and enter Insert |

**Common combinations**:

| Command | Action |
|---------|--------|
| `dd` | Delete line |
| `yy` | Yank line |
| `cc` | Change line |
| `dw` | Delete word |
| `yw` | Yank word |
| `cw` | Change word |
| `d$` | Delete to end of line |
| `y$` | Yank to end of line |
| `c$` | Change to end of line |
| `d0` | Delete to start of line |
| `dG` | Delete to end of file |
| `yG` | Yank to end of file |

**With count prefix**:
- `3dd` → delete 3 lines
- `d3w` → delete 3 words
- `3d2w` → delete 6 words (3 × 2)

#### Paste

| Key | Action | Description |
|-----|--------|-------------|
| `p` | Paste after | Paste after cursor/line |
| `P` | Paste before | Paste before cursor/line |

**Behavior**:
- Character-wise yank: paste after/before cursor
- Line-wise yank: paste below/above line

### Mode Switching

| Key | Target Mode | Description |
|-----|-------------|-------------|
| `i`, `a`, `I`, `A`, `o`, `O` | Insert | Enter insert mode |
| `v` | Visual | Visual character mode |
| `V` | Visual Line | Visual line mode (same as `v` currently) |
| `:` | Command | Enter command mode |
| `ESC` | Normal | Always returns to Normal (from any mode) |

### Count Prefixes

Numbers `1-9` can prefix most commands:

| Example | Expansion | Result |
|---------|-----------|--------|
| `3j` | `j` `j` `j` | Down 3 lines |
| `5w` | `w` `w` `w` `w` `w` | Forward 5 words |
| `2dd` | `dd` `dd` | Delete 2 lines |
| `4yy` | `yy` (x4) | Yank 4 lines |
| `10G` | — | Jump to line 10 |

**Rules**:
- Applies to motions, operators, and some commands
- `0` is line-start command, not part of count
- Count resets after command execution

## Insert Mode

| Key | Action | Description |
|-----|--------|-------------|
| `ESC` | Exit | Return to Normal mode |
| `Backspace` | Delete back | Delete character before cursor |
| `Enter` | Newline | Insert newline and move down |
| `Tab` | Spaces | Insert 4 spaces |
| `←` | Move left | Navigate left |
| `→` | Move right | Navigate right |
| `↑` | Move up | Navigate up |
| `↓` | Move down | Navigate down |
| Printable | Insert | Insert character |

**Note**: Arrow keys work like Neovim (navigate without leaving Insert mode)

## Visual Mode

| Key | Action | Status |
|-----|--------|--------|
| `ESC` | Exit | ✅ Implemented |
| `h` `j` `k` `l` | Extend selection | 🚧 Planned |
| `d` | Delete selection | 🚧 Planned |
| `y` | Yank selection | 🚧 Planned |
| `c` | Change selection | 🚧 Planned |

**Current status**: Visual mode can be entered but has no operations yet.

## Command Mode

### File Operations

| Command | Action | Description |
|---------|--------|-------------|
| `:w` | Write | Save current file |
| `:w {file}` | Write as | Save as filename |
| `:e {file}` | Edit | Open file |
| `:q` | Quit | Exit (error if unsaved) |
| `:q!` | Force quit | Exit without saving |
| `:wq` | Write & quit | Save and exit |

### Navigation

| Command | Action | Description |
|---------|--------|-------------|
| `:{number}` | Go to line | Jump to line number |

**Examples**:
- `:50` → line 50
- `:1` → line 1 (same as `gg` in Normal)

### Settings (Planned)

| Command | Action | Status |
|---------|--------|--------|
| `:set number` | Show line numbers | 🚧 Planned |
| `:set nonumber` | Hide line numbers | 🚧 Planned |

### Command Editing

| Key | Action |
|-----|--------|
| `ESC` | Cancel command |
| `Enter` | Execute command |
| `Backspace` | Delete character |

## Special Keys

### Control Keys

| Sequence | Hex | Action | Status |
|----------|-----|--------|--------|
| `Ctrl-C` | `0x03` | Signal interrupt | ✅ (handled by shell) |
| `ESC` | `0x1B` | Return to Normal | ✅ Implemented |
| `Backspace` | `0x7F` | Delete backward | ✅ Implemented |
| `Enter` | `0x0A` | Newline | ✅ Implemented |
| `Tab` | `0x09` | Insert spaces | ✅ Implemented |

### Escape Sequences

| Sequence | Key | Status |
|----------|-----|--------|
| `ESC[A` | ↑ | ✅ Implemented |
| `ESC[B` | ↓ | ✅ Implemented |
| `ESC[C` | → | ✅ Implemented |
| `ESC[D` | ← | ✅ Implemented |
| `ESC[3~` | Delete | 🚧 Planned |
| `ESC[H` | Home | 🚧 Planned |
| `ESC[F` | End | 🚧 Planned |

## Operator-Motion Grammar

Vite follows Vi's composable command grammar:

```
[count] operator [count] motion
```

### Examples

| Input | Parsed As | Result |
|-------|-----------|--------|
| `dw` | delete + word | Delete to next word |
| `3dd` | 3 × delete line | Delete 3 lines |
| `d3w` | delete + 3 words | Delete 3 words |
| `2d2w` | 2 × (delete 2 words) | Delete 4 words |
| `y$` | yank + end-of-line | Copy to end of line |
| `c0` | change + line-start | Delete to start, enter Insert |
| `5yy` | 5 × yank line | Copy 5 lines |

### Supported Combinations

| Operator | Motions | Examples |
|----------|---------|----------|
| `d` | `w`, `b`, `e`, `0`, `^`, `$`, `G`, `gg`, line | `dw`, `d$`, `dG` |
| `y` | Same as delete | `yw`, `y$`, `yG` |
| `c` | Same as delete | `cw`, `c$`, `cG` |

### Doubled Operators

| Command | Equivalent | Action |
|---------|------------|--------|
| `dd` | `d` + entire line | Delete line |
| `yy` | `y` + entire line | Yank line |
| `cc` | `c` + entire line | Change line |

## Planned Keybindings

### Coming Soon

| Feature | Keys | Status |
|---------|------|--------|
| Undo | `u` | 🚧 Planned |
| Redo | `Ctrl-R` | 🚧 Planned |
| Repeat | `.` | 🚧 Planned |
| Join lines | `J` | 🚧 Planned |
| Replace char | `r{char}` | 🚧 Planned |
| Delete char back | `X` | 🚧 Planned |

### Future Enhancements

| Feature | Keys | Status |
|---------|------|--------|
| Macros | `q{reg}`, `@{reg}` | 📋 Roadmap |
| Marks | `m{char}`, `'{char}` | 📋 Roadmap |
| Search | `/`, `n`, `N` | 📋 Roadmap |
| Replace | `:s/old/new/` | 📋 Roadmap |
| Paragraph motion | `{`, `}` | 📋 Roadmap |
| Matching bracket | `%` | 📋 Roadmap |

## Customization

### Adding Keybindings

Keybindings are defined in mode handlers. To add a new binding:

**1. Edit the mode handler** (`Core/Modes/NormalMode.swift`):

```swift
case "H":  // New binding for "move to top of screen"
    state.cursor.moveToBeginningOfFile()
    state.updateStatusMessage()
    return true
```

**2. Rebuild**:

```sh
swift build
```

### Overriding Keybindings

All bindings are in code (no config file yet). To change:

1. Locate binding in `handleInput()` method
2. Modify action
3. Rebuild

**Future**: `.viterc` configuration file for user bindings.

## Reference Card

Quick printable reference:

```
NORMAL MODE
  hjkl         Move cursor       dd           Delete line
  wb e         Word motions      yy           Yank line
  0 ^ $        Line motions      p P          Paste
  gg G {n}G    File motions      x            Delete char
  f F t T ;    Find char         i a I A o O  Insert mode

OPERATORS
  d{motion}    Delete            3dd          Delete 3 lines
  y{motion}    Yank              dw d$ dG     Delete word/end/file
  c{motion}    Change            y3w y$ yy    Yank combinations

COMMANDS
  :w           Save              :e file      Open file
  :q :q!       Quit              :wq          Save & quit
  :{n}         Line n            :w file      Save as

INSERT MODE
  ESC          Normal mode       Backspace    Delete back
  Enter        Newline           Arrows       Navigate
```

## See Also

- [Modal Editing Guide](Modal-Editing)
- [Motions Reference](Motions)
- [Operators Reference](Operators)
- [Command Reference](Commands)
