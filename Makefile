TARGET ?= videre
GO ?= go
GOCACHE ?= /tmp/videre-go-cache
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: all build run test clean install uninstall go-build

all: build

build:
	GOCACHE=$(GOCACHE) $(GO) build -o $(TARGET) ./cmd/videre

go-build: build

run:
	GOCACHE=$(GOCACHE) $(GO) run ./cmd/videre -- $(ARGS)

test:
	GOCACHE=$(GOCACHE) $(GO) test ./...

install: build
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(BINDIR)/$(TARGET)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(TARGET)

clean:
	rm -f $(TARGET)
	$(GO) clean ./...
