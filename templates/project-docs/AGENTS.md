# AGENTS.md — {{PROJECT_NAME}}

## What Is This Project?

{{PROJECT_DESCRIPTION}}

**Example use cases:**

- {{USE_CASE_1}}
- {{USE_CASE_2}}

## Tech Stack

## Key Design Decisions

<!--
  List 4-8 key design decisions. These should be the non-obvious choices
  that a new contributor (human or agent) would need to understand.
  Format: **Decision** — rationale.
-->

1. **{{DECISION_1}}** — {{RATIONALE_1}}
2. **{{DECISION_2}}** — {{RATIONALE_2}}
3. **{{DECISION_3}}** — {{RATIONALE_3}}

## Project Structure

```
{{PROJECT_NAME}}/
├── AGENTS.md                    # You are here — start every session by reading this
├── documents/                   # Project documentation (read these before coding)
│   ├── architecture/
│   │   ├── OVERVIEW.md          # High-level system architecture
│   ├── tasks/
│   │   ├── tasks.json           # Task registry — status of all tasks
│   │   └── TASK-*.md            # Individual task specifications
│   └── guides/
│       ├── CODING_STANDARDS.md  # Code style, testing requirements
│       └── SESSION_PROTOCOL.md  # How to start and end a coding session
├── {{SRC_DIR}}/                 # Application source code
├── progress.txt                 # Cross-session progress log
```

## Session Protocol (Quick Reference)

Every coding session must follow this protocol. Full details in `documents/guides/SESSION_PROTOCOL.md`.

**Start of session:**

1. Read this file (`AGENTS.md`)
2. Read `progress.txt` for recent work summary
3. Read `documents/tasks/tasks.json` to find the next task
4. Check recent commits: `git log --oneline -10`
5. Verify the project builds: `{{BUILD_COMMAND}}`
6. Pick ONE task and work on it

**End of session:**

1. Ensure `{{BUILD_COMMAND}}` passes
2. Ensure `{{TEST_COMMAND}}` passes
3. Commit with a descriptive message
4. Update `progress.txt` with what was done and what's next
5. Update `documents/tasks/tasks.json` — mark completed tasks as `"passes": true`

## Document Index

Read these documents in this order when starting fresh:

1. `documents/architecture/OVERVIEW.md` — understand the system
2. `documents/guides/CODING_STANDARDS.md` — understand code quality rules
3. `documents/guides/SESSION_PROTOCOL.md` — understand session workflow
4. `documents/tasks/tasks.json` — find your next task
