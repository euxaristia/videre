# videre-go

Go rewrite of videre (in-progress) with modal core, row model, undo/redo, search, syntax coloring, marks, yank/delete/paste, and vi-style motions.

## Build

```sh
cd go
GOCACHE=/tmp/videre-go-cache go build ./cmd/videre
```

## Run

```sh
cd go
GOCACHE=/tmp/videre-go-cache go run ./cmd/videre -- path/to/file
```

## Parity notes

Implemented:
- Normal/Insert/Visual/Visual-line modes
- h/j/k/l + arrow movement, word/file/line motions
- :w, :q, :q!, :wq
- / search and n/N
- undo/redo (u, Ctrl-R)
- yank/delete/paste for visual selections
- marks (m{a-z}, '{a-z})
- status and message bars

Still missing for strict 1:1:
- mouse protocol + context menu
- full language DB (currently focused subset)
- OSC52 / wl-copy / xclip clipboard integration
- bracketed paste event parsing
- full bracket/paragraph/char-find operator parity
