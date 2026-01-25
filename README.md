# vite ⚡

A lightning-fast, lightweight vi text editor built in pure Swift. vite brings the power of modal editing to the terminal with a clean, minimal design inspired by the legendary vi/Vim editors.

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" />
  <img alt="Platforms" src="https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-4CAF50" />
  <img alt="SPM" src="https://img.shields.io/badge/Build-SPM-informational" />
  <img alt="Editor" src="https://img.shields.io/badge/Editor-vi%2FVim-brightgreen" />
  <img alt="Architecture" src="https://img.shields.io/badge/Buffer-Gap%20Buffer-blue" />
</p>

---

## Highlights

- **True modal editing**
  - Normal, Insert, Visual, and Command modes
  - Classic vi keybindings with modern enhancements
  - Arrow key support alongside hjkl navigation
- **Efficient text storage**
  - Gap buffer data structure for O(1) insertions at cursor
  - Optimized for real-world editing patterns
  - Minimal memory overhead
- **Rich motion & operator system**
  - Word motions: `w`, `b`, `e`
  - Character search: `f`, `F`, `t`, `T`, `;`
  - Line motions: `0`, `^`, `$`, `gg`, `G`, `{line number}`
  - Operators: delete (`d`), yank (`y`), change (`c`)
  - Composable commands: `dw`, `3dd`, `y$`, `ct{char}`, etc.
- **Neovim-inspired UI**
  - Faint line numbers for distraction-free editing
  - Clean status line showing filename, position, and scroll indicator
  - Responsive terminal rendering with resize support
- **Vim-compatible file operations**
  - Commands: `:w`, `:e`, `:q`, `:wq`, `:q!`
  - Error messages match Vim's format
  - Unsaved change protection

## How it works

vite implements a classic vi-style editor with modern refinements:

- **Gap Buffer**: Text is stored using a gap buffer—a dynamic array with an efficient "gap" at the cursor position, enabling O(1) character insertions
- **Mode System**: Four distinct modes (Normal, Insert, Visual, Command) control input interpretation
- **Motion Engine**: Cursor movements are calculated by a dedicated motion engine supporting word boundaries, line positions, and character searches
- **Operator Engine**: Commands like `d3w` (delete 3 words) are parsed into operator-motion pairs and executed atomically
- **Register Manager**: Yanked/deleted text is stored in a register system for paste operations (`p`, `P`)

Architecture highlights:
- Protocol-based mode handlers for clean separation
- ANSI escape sequence parsing for arrow keys
- SIGWINCH signal handling for terminal resize events
- POSIX terminal control via `termios` for raw input mode

## Platform Support

**Supported:**
- ✅ macOS (13+)
- ✅ Linux (any distro with Swift 5.9+)

**Not Yet Supported:**
- ❌ Windows - Uses POSIX APIs (`termios`, `ioctl`, ANSI escape sequences) not available on Windows
- Future: Windows support would require either Windows Console API integration or a cross-platform terminal library

**Technical Note:**
vite does **not** use SwiftTUI or any framework. It's pure Swift with direct POSIX terminal control for maximum performance and minimal dependencies.

## Install

**Requirements:**
- Swift 5.9+ (macOS or Linux)
- Terminal with ANSI escape sequence support

**Build with Swift Package Manager:**

```sh
git clone https://github.com/euxaristia/vite.git
cd vite
swift build -c release
```

The binary will be at `.build/release/vite`.

**Optional: Install to PATH:**

```sh
cp .build/release/vite /usr/local/bin/vi
# or symlink:
ln -s "$(pwd)/.build/release/vite" /usr/local/bin/vi
```

## Usage

**Open a file:**

```sh
vi myfile.txt
```

**Start with empty buffer:**

```sh
vi
```

### Quick Reference

**Normal Mode:**

| Command | Action |
|---------|--------|
| `h` `j` `k` `l` | Move left, down, up, right |
| `w` `b` `e` | Next word, previous word, end of word |
| `0` `^` `$` | Line start, first non-whitespace, line end |
| `gg` `G` | File start, file end |
| `{n}G` | Go to line n |
| `f{char}` `F{char}` | Find character forward/backward |
| `t{char}` `T{char}` | Till character forward/backward |
| `;` | Repeat last find/till |
| `i` `a` | Insert before/after cursor |
| `I` `A` | Insert at line start/end |
| `o` `O` | Open line below/above |
| `x` | Delete character |
| `d{motion}` | Delete with motion (e.g., `dw`, `d$`, `3dd`) |
| `y{motion}` | Yank (copy) with motion (e.g., `yw`, `yy`) |
| `c{motion}` | Change with motion (e.g., `cw`, `cc`) |
| `p` `P` | Paste after/before cursor |
| `v` `V` | Enter visual mode |
| `:` | Enter command mode |

**Insert Mode:**

| Key | Action |
|-----|--------|
| `ESC` | Return to Normal mode |
| Arrow keys | Navigate (Neovim-style) |
| `Backspace` | Delete character before cursor |
| `Enter` | Insert newline |
| `Tab` | Insert 4 spaces |

**Command Mode:**

| Command | Action |
|---------|--------|
| `:w` | Write (save) file |
| `:w {filename}` | Save as filename |
| `:e {filename}` | Edit (open) file |
| `:q` | Quit (fails if unsaved changes) |
| `:q!` | Quit without saving |
| `:wq` | Write and quit |
| `:{number}` | Go to line number |

**Count Prefixes:**

Most commands accept numeric prefixes:
- `3j` - Move down 3 lines
- `5w` - Move forward 5 words
- `2dd` - Delete 2 lines
- `4x` - Delete 4 characters

## Features in Detail

### Gap Buffer Text Storage

vite uses a gap buffer—a technique from classic editors like Emacs:

```
"Hello world"
       ↑ cursor

Stored as: "Hello _____ world"  (gap at cursor)
              ↑     ↑
            before  after
```

Benefits:
- Insertions at cursor are O(1)
- Deletions at cursor are O(1)
- Moving cursor requires gap relocation but is optimized for locality
- Simple, fast, and memory-efficient

### Terminal Handling

- **Raw mode**: Disables line buffering and echo for immediate key response
- **SIGWINCH**: Handles terminal resize without corrupting display
- **Escape sequences**: Parses arrow keys (`ESC[A/B/C/D`) into navigation commands
- **ANSI rendering**: Faint line numbers, inverse video cursor, clean status bar

### vi Compatibility

vite implements core vi behavior with high fidelity:
- Cursor positioning follows vi rules (e.g., moving left from insert mode)
- Operators compose with motions using the same grammar
- Error messages match Vim's format (e.g., `E37`, `E212`)
- Empty buffers show tildes (`~`) like Vim

## Project Structure

```
Sources/vite/
├── main.swift                    # Entry point
├── UI/
│   ├── EditorApp.swift          # Main editor loop & terminal control
│   └── EditorView.swift         # Viewport (legacy)
├── Core/
│   ├── Modes/
│   │   ├── Mode.swift           # Base mode protocol
│   │   ├── NormalMode.swift     # Normal mode handler
│   │   ├── InsertMode.swift     # Insert mode handler
│   │   ├── VisualMode.swift     # Visual mode handler
│   │   └── CommandMode.swift    # Command mode handler
│   └── TextBuffer/
│       ├── TextBuffer.swift     # Gap buffer implementation
│       ├── GapBuffer.swift      # Low-level gap buffer
│       └── Cursor.swift         # Cursor position & movement
├── Engine/
│   ├── MotionEngine.swift       # Motion calculations (w/b/e/f/t/etc.)
│   └── OperatorEngine.swift     # Operator-motion execution (d/y/c)
└── Models/
    ├── EditorState.swift        # Central state container
    └── Register.swift           # Register manager (yank/paste)
```

## Roadmap

- [ ] Platform support
  - [ ] Windows support (requires Windows Console API or cross-platform abstraction)
- [ ] Extended motion support
  - [ ] `{` `}` paragraph motions
  - [ ] `%` matching bracket
  - [ ] `/` `/` search
- [ ] Visual mode operations (currently enters but no-op)
- [ ] Multiple registers (named: `"a`, `"b`, etc.)
- [ ] Undo/redo (`u`, `Ctrl-R`)
- [ ] Macros (`q{register}`)
- [ ] Configuration file (`~/.viterc`)
- [ ] Syntax highlighting
- [ ] Multiple windows/splits
- [ ] Plugins via Swift packages

## Contributing

Contributions welcome! If you're planning a significant change (e.g., new motion type, mode extensions), please open an issue first to discuss the design.

**Dev quickstart:**

```sh
swift build
swift run vite test.txt

# Run with release optimizations:
swift build -c release
.build/release/vite test.txt
```

**Coding guidelines:**
- Keep mode handlers focused (one mode per file)
- Motion calculations belong in `MotionEngine`
- Operator execution belongs in `OperatorEngine`
- Use protocols for extensibility
- Follow existing vi semantics where possible

## Troubleshooting

**Terminal echo stuck after crash?**
- Run `reset` or `stty sane` in your shell
- vite restores terminal state on clean exit and SIGINT, but hard kills can leave TTY misconfigured

**Arrow keys not working?**
- Ensure your terminal emits standard escape sequences
- Test with: `cat -v` then press arrow keys—should see `^[[A/B/C/D`

**Line numbers not faint?**
- Your terminal may not support ANSI dim mode (`ESC[2m`)
- Try a modern terminal: iTerm2, Alacritty, kitty, or GNOME Terminal

## License

Copyright © 2026 euxaristia. All rights reserved.

---

Built with Swift, inspired by vi, powered by gap buffers. ⚡✨