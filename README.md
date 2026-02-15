# videre

`videre` is a fast modal terminal editor implemented in Go.

## Build

```sh
GOCACHE=/tmp/videre-go-cache go build -o videre ./cmd/videre
```

Or with `make`:

```sh
make
```

## Run

```sh
./videre path/to/file
```

Or run directly with Go:

```sh
GOCACHE=/tmp/videre-go-cache go run ./cmd/videre -- path/to/file
```

## Install

```sh
sudo make install
```

## Repository Layout

- `cmd/videre/main.go`: editor entrypoint and core logic
- `go.mod`: Go module definition

## License

MIT. See `LICENSE`.
