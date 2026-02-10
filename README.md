# videre 👁

A lightning-fast, minimalist vi text editor written in pure C. videre brings the power of modal editing to the terminal with a clean, efficient design inspired by the legendary vi/Vim editors.

<p align="center">
  <img alt="C" src="https://img.shields.io/badge/C-99-blue?logo=c" />
  <img alt="Platforms" src="https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS-4CAF50" />
  <img alt="License" src="https://img.shields.io/badge/License-MIT-brightgreen" />
  <img alt="Editor" src="https://img.shields.io/badge/Editor-vi%2FVim-brightgreen" />
</p>

---

## Highlights

- **Pure C implementation**
  - Zero dependencies beyond standard C libraries
  - Ultra-fast startup and minimal memory footprint
  - Portable across POSIX systems (Linux, macOS, BSD)
- **True modal editing**
  - Normal, Insert, Visual, and Command modes
  - Classic vi keybindings with modern enhancements
- **Rich motion & operator system**
  - Word motions (`w`, `b`, `e`, `W`, `B`, `E`)
  - Character search (`f`, `F`, `t`, `T`, `;`, `,`)
  - Paragraph motions (`{`, `}`) and matching brackets (`%`)
  - Marks support (`m{a-z}` and `'{a-z}`)
  - Vertical movement with `preferredColumn` preservation
- **Modern Terminal Features**
  - **Native Clipboard**: OSC 52 support for "standard" terminal copy/paste notifications
  - **Bracketed Paste**: Native terminal paste support for large blocks of text
  - **Context Menu**: Neovim-style right-click menu for quick actions (Cut, Copy, Paste, Undo, Redo)
  - **Flicker-Free**: Optimized rendering loop for smooth interaction on all hardware
- **Development Productivity**
  - **Git Integration**: Live branch and dirty status in the status bar
  - **Syntax Highlighting**: Built-in support for 47+ languages
  - **Undo/Redo**: Full edit history management

## Install

**Requirements:**
- A C compiler (gcc or clang)
- `make`
- A terminal with ANSI escape sequence support (e.g., Ghostty, Alacritty, Kitty)

**Build from source:**

```sh
git clone https://github.com/euxaristia/videre.git
cd videre
make
```

**Install to system:**

```sh
sudo make install
```

## Usage

```sh
videre [filename]
```

### Quick Reference

| Command | Action |
|---------|--------|
| `h` `j` `k` `l` | Move left, down, up, right |
| `w` `b` `e` | Next word, previous word, end of word |
| `0` `^` `$` | Line start, first non-whitespace, line end |
| `gg` `G` | File start, file end |
| `f` `F` `t` `T` | Character search commands |
| `m{a-z}` | Set mark a-z |
| `'{a-z}` | Jump to mark a-z |
| `Ctrl+A` | Increment next number |
| `Ctrl+X` | Decrement next number |
| `u` `Ctrl+R` | Undo / Redo |
| `v` `V` | Enter Visual / Visual Line mode |
| `>` `<` | Indent / Unindent selection |
| `y` `d` `p` | Yank, Delete, Paste |
| `:` | Enter command mode |

## Contributing

Contributions welcome! videre is designed to be a "clean" and hackable codebase.

**Tests:**
```sh
make test           # Unit tests
make security-test  # Security/Vulnerability suite
```

## License

MIT License. See `LICENSE` for details.

---

Built with precision, inspired by vi, powered by pure C. 💨✨