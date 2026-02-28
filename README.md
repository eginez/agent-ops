# Agent Ops

Scripts and global operating practices for agent projects.

## Purpose

Defines standardized development, testing, and safety practices used across agent projects, plus tooling to run agents autonomously in sandboxed environments.

## Structure

- `ops/` — authoritative agent operation docs (symlinked into Opencode config)
- `scripts/` — tooling for running and managing agent sandboxes

## Opt-out

If a project contains a `.agentops.off` file at repo root, global ops MUST NOT be applied.

## Scripts

### `scripts/sandbox-bootstrap.sh`

Creates (or reuses) a Docker Sandbox for a project and copies your local Opencode config into it. Run this once before using the loop.

```bash
bash scripts/sandbox-bootstrap.sh --name rudder --workdir /path/to/project
```

### `scripts/run_loop.py`

Runs the agent autonomously in a loop inside a Docker Sandbox. Each iteration starts a fresh Opencode session. The agent is expected to emit one of the following promise sentinels in its output to control the loop:

| Sentinel | Effect |
|---|---|
| `<promise>PROGRESS</promise>` | Continue to next iteration |
| `<promise>COMPLETE</promise>` | Stop — all tasks done |
| `<promise>BLOCKED:reason</promise>` | Stop — needs human input |
| `<promise>DECIDE:question</promise>` | Stop — needs a decision |

**Usage:**

```bash
# Bootstrap the sandbox first (once)
bash scripts/sandbox-bootstrap.sh --name rudder --workdir /path/to/project

# Run the loop
python3 scripts/run_loop.py --sandbox rudder
python3 scripts/run_loop.py --sandbox rudder --once       # single iteration
python3 scripts/run_loop.py --sandbox rudder -n 5         # 5 iterations

# Or set the sandbox via env
RUDDER_SANDBOX=rudder python3 scripts/run_loop.py
```

**Requirements:** Python 3, `docker sandbox` CLI, a bootstrapped sandbox.
