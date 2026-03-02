# Coding Standards

## General Principles

1. **One module, one concern** — each package/module does one thing
2. **Interfaces at boundaries** — every external dependency is behind an interface
3. **Test everything that matters** — if it touches state, or external services, it has tests
4. **Small files** — keep files under 300 lines. Split if larger.
5. **Clear over clever** — write readable code, not tricky code
6. Mock where necessary, if you need to interact with external dependencies, mock them.

## File & Package Organization

<!--
  Adapt this to your language. The pattern is universal:
  - Entry points (CLI, API routes) contain no business logic
  - Internal packages are unexported / private
  - Tests live next to the code they test
  - Fixture data lives in a testdata/ or fixtures/ directory
-->

## Naming

<!--
  Define naming conventions for your language.
  Include: packages/modules, interfaces, implementations, functions, files.
-->

## Error Handling

- Use typed/sentinel errors for expected failure modes
- Never ignore errors silently — log them if you can't return them

## Testing

- Mock external dependencies using interfaces (never mock the filesystem for state tests — use a temp directory)
- Integration tests are tagged/separated and test real external connections
- Every change must pass testing and linting

## State / Persistence

## Security

- Never commit secrets. Keep secrets outside the repo.
- Use host env vars or secure vault for credentials.
- Repo-only mounts in sandboxes — no bind mounts for secrets.
- Use allowlists for network access where possible.
- Prefer offline tests (fixtures/mocks) over live calls.
- Tools should only access what they need — deny by default, allow explicitly.
- Remove personal info from logs. Sanitize output before storing.
- Delete temporary files after use.

## Dependencies

- Minimize external dependencies — prefer stdlib where possible
- Pin all dependency versions
- Evaluate dependencies by: maintenance activity, license, binary/bundle size impact

## Git Conventions

- Commit messages: conventional format (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`)
- One logical change per commit
- Always run build and testing  before committing

## Code Review Checklist (for the coding agent)

Before marking a task as complete, verify:

- [ ] Code compiles/builds
- [ ] Tests pass
- [ ] No lint issues
- [ ] Files under 300 lines
- [ ] New interfaces have both mock and real implementations (or TODO for real)
- [ ] State/schema changes are backward-compatible (new fields have defaults)
- [ ] Error messages are actionable (tell the user what went wrong and what to do)
