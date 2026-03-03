BINARY    := agent-loop-linux-amd64
SRC       := ./src/cmd/agent-loop
VERSION   := $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")
LDFLAGS   := -ldflags "-X main.version=$(VERSION)"

.PHONY: all build clean install test vet fmt

all: build

## build: compile the agent-loop binary into the repo root
build:
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY) $(SRC)

## install: install the binary to $GOPATH/bin (or ~/go/bin)
install:
	go install $(LDFLAGS) $(SRC)

## clean: remove the compiled binary
clean:
	rm -f $(BINARY) agent-loop

## test: run all tests
test:
	go test ./...

## vet: run go vet
vet:
	go vet ./...

## fmt: format all Go source files
fmt:
	gofmt -w ./src/

## help: print this help message
help:
	@grep -E '^## ' Makefile | sed 's/## /  /'
