# Welcome to Vite Wiki

Vite is a lightning-fast Vi text editor built in pure Swift, featuring modal editing, efficient gap buffer storage, and a rich motion/operator system.

## Quick Navigation

### Getting Started
- [Installation Guide](Installation)
- [Quick Start Tutorial](Quick-Start)
- [Configuration](Configuration)

### Core Concepts
- [Modal Editing](Modal-Editing)
- [Gap Buffer Architecture](Gap-Buffer)
- [Motion System](Motions)
- [Operators](Operators)

### API Documentation
- [EditorState API](API-EditorState)
- [TextBuffer API](API-TextBuffer)
- [Mode Handlers](API-Modes)
- [Motion Engine](API-MotionEngine)
- [Operator Engine](API-OperatorEngine)

### Guides
- [Terminal Control](Terminal-Control)
- [Keybindings](Keybindings)
- [Command Reference](Commands)
- [Extending Vite](Extending)

### Advanced Topics
- [Architecture Overview](Architecture)
- [Contributing Guide](Contributing)
- [Performance Optimization](Performance)

## Features

- **Modal Editing**: Normal, Insert, Visual, and Command modes
- **Efficient Text Storage**: Gap buffer for O(1) insertions
- **Rich Motions**: w/b/e, f/F/t/T, 0/^/$, gg/G, and more
- **Composable Operators**: d/y/c with motion combinations
- **Neovim UI**: Faint line numbers, clean status line
- **File Operations**: :w, :e, :q, :wq commands
- **Register System**: Yank/paste with unnamed register

## Requirements

- **Swift**: 5.9 or later
- **Platforms**: macOS, Linux
- **Terminal**: ANSI escape sequence support

## Project Links

- [GitHub Repository](https://github.com/euxaristia/Vite)
- [Issue Tracker](https://github.com/euxaristia/Vite/issues)
- [Releases](https://github.com/euxaristia/Vite/releases)
