# AGENTS.md — Agent Ops

## What Is This Project?

Agent Ops is a starter kit for software projects built with coding agents. It provides a documentation template that gives agents the structure they need to work autonomously across sessions, plus scripts to run agents in sandboxed environments.

**Example use cases:**

- Bootstrap a new project with agent-friendly documentation structure
- Run autonomous agents in Docker sandboxes with consistent configurations
- Enable multi-session agent work with progress tracking and task management

## Tech Stack

- **Language:** Go 1.21+ (agent-loop binary)
- **Agent Integration:** OpenCode CLI
- **Containerization:** Docker Sandbox
- **Build System:** Make

## Key Design Decisions

1. **Template-based documentation** — The `templates/project-docs/` directory provides a consistent structure that has been refined across dozens of autonomous agent sessions, preventing common failures like broken builds and lost context.

2. **Promise sentinels** — Agents signal session outcomes using `<promise>...</promise>` tags in their output, allowing the agent-loop to make decisions about continuation, completion, or escalation.

3. **Sandbox-first approach** — Development runs in isolated Docker sandboxes for reproducibility and security, though no-sandbox mode is available for local development.

4. **Progress tracking via text files** — Simple `progress.txt` and `tasks.json` files provide cross-session continuity without requiring a database or external system.

5. **Commit-driven workflow** — Each session commits changes, ensuring a clear audit trail and enabling recovery from broken states.

## Project Structure

```
agent-ops/
├── AGENTS.md                    # You are here — start every session by reading this
├── progress.txt                 # Cross-session progress log
├── documents/                   # Project documentation (read these before coding)
│   ├── architecture/
│   │   └── OVERVIEW.md          # High-level system architecture
│   ├── tasks/
│   │   ├── tasks.json           # Task registry — status of all tasks
│   │   └── TASK-*.md            # Individual task specifications
│   └── guides/
│       ├── CODING_STANDARDS.md  # Code style, testing requirements
│       └── SESSION_PROTOCOL.md  # How to start and end a coding session
├── src/
│   └── cmd/agent-loop/
│       └── main.go              # Agent loop implementation
├── templates/                   # Documentation templates for new projects
│   └── project-docs/
├── scripts/                     # Tooling for sandboxes and agent loops
├── Makefile                     # Build and test commands
├── go.mod                       # Go module definition
└── README.md                    # Project overview for humans
```

## Session Protocol (Quick Reference)

Every coding session must follow this protocol. Full details in `documents/guides/SESSION_PROTOCOL.md`.

**Start of session:**

1. Read this file (`AGENTS.md`)
2. Read `progress.txt` for recent work summary
3. Read `documents/tasks/tasks.json` to find the next task
4. Check recent commits: `git log --oneline -10`
5. Verify the project builds: `make build`
6. Pick ONE task and work on it

**End of session:**

1. Ensure `make build` passes
2. Ensure `make test` passes
3. Commit with a descriptive message
4. Update `progress.txt` with what was done and what's next
5. Update `documents/tasks/tasks.json` — mark completed tasks as `"passes": true`

## Document Index

Read these documents in this order when starting fresh:

1. `documents/architecture/OVERVIEW.md` — understand the system
2. `documents/guides/CODING_STANDARDS.md` — understand code quality rules
3. `documents/guides/SESSION_PROTOCOL.md` — understand session workflow
4. `documents/tasks/tasks.json` — find your next task
