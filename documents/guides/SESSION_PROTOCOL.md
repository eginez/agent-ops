# Session Protocol

This document defines the exact protocol a coding agent must follow at the start and end of every session. Following this protocol ensures clean handoffs between sessions and prevents the common failure modes of long-running agent work (one-shotting, premature completion, broken state).

## Starting a Session

Execute these steps in order:

### 1. Orient yourself

```bash
pwd
```

### 2. Read the project overview

Read `AGENTS.md` at the project root for the full project context.

### 3. Check recent progress

```bash
cat progress.txt
git log --oneline -15
```

### 4. Verify the project builds

```bash
make build
make test
```

If either fails, **fix the build/tests FIRST** before doing anything else. Do not start new work on a broken codebase.

### 5. Read the task list

Read `documents/tasks/tasks.json`. Find the highest-priority task where `"passes": false`.

### 6. Read the task specification

Read the corresponding `documents/tasks/TASK-<id>.md` for full requirements.

### 7. Work on ONE task

Implement the task. Do not start a second task until the first is complete and verified.

## During a Session

- **Commit frequently** — after each meaningful unit of progress, commit with a descriptive message
- **Test as you go** — run `make test` after significant changes, not just at the end
- **Don't refactor unrelated code** — stay focused on the current task
- **If blocked, document it** — if you hit an issue that requires human input, note it in `progress.txt` and move to the next task

## Ending a Session

Execute these steps in order:

### 1. Ensure clean build

```bash
make build
make test
make vet
```

Fix any issues before proceeding.

### 2. Commit all changes

```bash
git add -A
git commit -m "feat: <descriptive message about what was accomplished>"
```

### 3. Update task status

Edit `documents/tasks/tasks.json`:

- Set `"passes": true` for any task you completed AND verified
- Do NOT mark a task as passing unless you've tested it
- It is unacceptable to remove or edit task definitions

### 4. Update progress log

Append to `progress.txt`:

```
## Session: <date>

### Completed
- <what was done, in plain language>

### Current State
- <what the project can do now that it couldn't before>

### Next Steps
- <what the next agent session should work on>

### Issues / Blockers
- <anything that needs human attention, or "None">
```

### 5. Final commit

```bash
git add -A
git commit -m "docs: update progress and task status"
```

### 6. Signal Exit

Output exactly one of these as the last thing you do:

- All tasks passing:      `<promise>COMPLETE</promise>`
- Task done, more remain: `<promise>PROGRESS</promise>`
- Blocked, need human:    `<promise>BLOCKED:reason</promise>`
- Need design decision:   `<promise>DECIDE:question</promise>`

## Task Completion Criteria

A task is only complete when ALL of the following are true:

1. The feature/change described in the task spec is implemented
2. `make build` passes
3. `make test` passes (including any new tests for this task)
4. `make vet` passes
5. The task's specific acceptance criteria (from its TASK-*.md file) are met
6. You have manually verified the behavior

## Emergency Recovery

If you find the codebase in a broken state at the start of a session:

1. Check `git log --oneline -5` to see what happened
2. Check `progress.txt` for context
3. Try `git stash` or `git revert HEAD` if the last commit broke things
4. Fix the build before doing anything else
5. Document what went wrong in `progress.txt`

## Development Environment (informational only)

Development happens inside a Docker Sandbox VM. The sandbox is created and managed by the human — the agent works inside it.

**Why sandboxes:**

- Sandboxes run in microVMs with a private Docker daemon.
- Workspace is isolated from host files outside the repo.
- Network access can be controlled per sandbox.

**Rules:**

- Repo-only mount for safety. Do not access files outside the workspace.
- Use repo-local scratch space (`tmp/`) for temporary files.
- No secrets written in the repo.
- Workspace syncs at the same absolute path between host and sandbox.
- Install tools in the sandbox when needed — sandboxes persist per workspace until removed.
