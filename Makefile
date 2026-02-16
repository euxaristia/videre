TARGET ?= videre
GO ?= go
GOCACHE ?= /tmp/videre-go-cache
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

COMMIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS := -X main.Version=$(COMMIT_SHA)

.PHONY: all build run test clean install uninstall go-build

all: build

build:
	GOCACHE=$(GOCACHE) $(GO) build -ldflags "$(LDFLAGS)" -o $(TARGET) ./cmd/videre

go-build: build

run:
	GOCACHE=$(GOCACHE) $(GO) run -ldflags "$(LDFLAGS)" ./cmd/videre -- $(ARGS)

test:
	GOCACHE=$(GOCACHE) $(GO) test -ldflags "$(LDFLAGS)" ./...

benchmark:
	@GOCACHE=$(GOCACHE) $(GO) test -bench . -benchmem ./cmd/videre | awk ' \
		BEGIN { \
			printf "\033[1;34m%-45s | %10s | %15s | %15s | %10s\033[0m\n", "BENCHMARK", "ITERATIONS", "TIME", "MEMORY", "ALLOCS"; \
			print "----------------------------------------------+------------+-----------------+-----------------+----------" \
		} \
		/^Benchmark/ { \
			printf "%-45s | %10s | %11s %-3s | %11s %-3s | %10s\n", $$1, $$2, $$3, $$4, $$5, $$6, $$7; \
			next \
		} \
		{ print }'

install: build
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(BINDIR)/$(TARGET)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(TARGET)

clean:
	rm -f $(TARGET)
	$(GO) clean ./...
