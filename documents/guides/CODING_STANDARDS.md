# Coding Standards

## Code Quality

### Go Standards

1. Follow [Effective Go](https://go.dev/doc/effective_go) and [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
2. Use `gofmt` for formatting (`make fmt`)
3. Run `go vet` before committing (`make vet`)
4. Write unit tests for all new functionality
5. Use `t.Parallel()` for tests that can run concurrently

### Naming Conventions

- **Variables/Functions:** `camelCase` (e.g., `agentLoop`, `parseDuration`)
- **Types/Interfaces:** `PascalCase` (e.g., `LoopResult`, `SentinelParser`)
- **Constants:** `UPPER_SNAKE_CASE` (e.g., `COLOR_BLUE`)
- **Package names:** lowercase, single word (e.g., `main`, `agentloop`)

### Error Handling

- Always check errors and handle them appropriately
- Use `fmt.Errorf` with context: `return fmt.Errorf("parseDuration: %w", err)`
- Wrap errors with `fmt.Errorf("...: %w", err)` for error chains
- Use `slog.Error` for logging errors

## Testing

### Test Structure

```go
func TestXxx(t *testing.T) {
    t.Parallel()
    // test cases
}

func TestXxx_Subcase(t *testing.T) {
    // subtest cases
}
```

### Test Requirements

1. **Unit tests** for all public functions
2. **Integration tests** for multi-component workflows
3. **Table-driven tests** for multiple similar cases
4. **Mock external dependencies** to ensure test reliability

### Running Tests

```bash
make test          # run all tests
go test ./... -v   # verbose output
go test -race      # race detector
```

## Security

### Secrets Management

- Never commit secrets, keys, or credentials
- Use environment variables for sensitive configuration
- Never log secrets or redact them properly

### Input Validation

- Validate all user inputs
- Sanitize file paths to prevent path traversal
- Use `exec.Command` with explicit path arguments

### Sandbox Best Practices

- Sandboxes are isolated but not a security boundary
- Assume sandboxed code can access the repo
- Never mount secrets or host files into sandboxes

## Documentation

### Comments

- Document all public functions
- Use godoc format:
  ```go
  // FunctionName describes what it does.
  // Additional details about implementation or usage.
  ```
- Update comments when code changes

### README.md

- Clear project description
- Installation instructions
- Quick start guide
- Configuration options

## Build & Release

### Build Requirements

- Build for Linux/amd64: `make build`
- Version is derived from Git commit hash
- Binary should be named `agent-loop-linux-amd64`

### Versioning

- Version = short Git commit hash
- Tags format: `vabc1234` (where abc1234 is the commit hash)
- Pre-release tags: `vabc1234-pre`

## Workflow

### Pre-Commit Checklist

- [ ] `make build` succeeds
- [ ] `make test` passes
- [ ] `make vet` passes
- [ ] `make fmt` applied
- [ ] Git log reviewed
- [ ] Progress updated in `progress.txt`

### Commit Message Format

```
<type>: <description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `chore`, `test`, `refactor`

Example: `feat: add --every flag for scheduled loop execution`
