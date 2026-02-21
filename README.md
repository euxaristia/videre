# videre

`videre` is a fast, modal terminal editor with a vi-first workflow and minimal runtime dependencies.

It is built for keyboard-driven editing, quick startup, and a clean full-screen terminal UI.  
The current codebase is a Go rewrite focused on parity with the original C behavior.

## Why `videre`

- Modal editing that stays close to muscle memory
- Tight terminal feedback with a low-friction UI
- Single-binary workflow with simple build/run/install paths
- Practical feature set: motions, visual selections, search, marks, yoinks, paste, and command mode

## Features

- Modes: Normal, Insert, Visual, Visual Line, and `:` command entry
- Navigation: `hjkl`, arrows, word motions, paragraph motions, `%`, `gg`, `G`, `{n}G`
- Editing: `i a I A o O`, `x`, `d`, `y`, `c` (including operator+motion forms and count prefixes)
- Search: `/`, `n`, `N`, `f/F/t/T`, `;`, `,`
- Commands: `:w`, `:q`, `:q!`, `:qa!`, `:wq`, `:e <file>`, `:{number}`, `:help`
- Extras: mouse support, context menu, clipboard integration, syntax highlighting, status line

## Build

```sh
COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
go build -ldflags "-X main.Version=${COMMIT_SHA}" -o videre ./cmd/videre
```

## Run

```sh
./videre path/to/file
```

or:

```sh
COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
go run -ldflags "-X main.Version=${COMMIT_SHA}" ./cmd/videre -- path/to/file
```

## Install

```sh
COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
go install -ldflags "-X main.Version=${COMMIT_SHA}" ./cmd/videre
```

## Uninstall

```sh
rm -f "${GOBIN:-$(go env GOPATH)/bin}/videre"
```

## Benchmarking

Performance is measured using Go's built-in benchmarking tool:

```sh
go test -bench . -benchmem ./cmd/videre
```

This tests core operations including file loading, text insertion, cursor movement, and screen rendering.

## Project Layout

- `cmd/videre/main.go`: editor implementation and entrypoint
- `videre.1`: man page
- `help.txt`: in-editor help buffer content

## Notes

- Linux/macOS terminals are the primary target.
- On crash/hard-kill, restore terminal state with `reset` or `stty sane`.

## License

GPLv3. See `LICENSE`.
