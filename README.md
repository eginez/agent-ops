# Agent Ops

A starter kit for software projects built with coding agents. Provides a documentation template that gives agents the structure they need to work autonomously across sessions, plus scripts to run agents in sandboxed environments.

## Quick Start

```bash
# 1. Scaffold docs into your project
bash scripts/scaffold-docs.sh /path/to/your-project

# 2. Fill in the {{PLACEHOLDER}} values in AGENTS.md and the documents/ tree

# 3. Bootstrap a sandbox for the project
bash scripts/sandbox-bootstrap.sh --name my-project --workdir /path/to/your-project

# 4. Run the agent loop
python3 scripts/run_loop.py --sandbox my-project
```

## Structure

```
agent-ops/
├── templates/       # Project documentation templates
│   └── project-docs/
│       ├── AGENTS.md                              # Agent entry point
│       ├── progress.txt                           # Cross-session log
│       └── documents/
│           ├── architecture/
│           │   └── OVERVIEW.md                    # System architecture
│           ├── guides/
│           │   ├── SESSION_PROTOCOL.md            # Session start/end checklists, sandbox rules
│           │   └── CODING_STANDARDS.md            # Code quality rules, security baseline
│           └── tasks/
│               └── tasks.json                     # Task registry
└── scripts/         # Tooling for sandboxes and agent loops
    ├── scaffold-docs.sh
    ├── sandbox-bootstrap.sh
    └── run_loop.py
```

## Templates

The `templates/project-docs/` directory contains a documentation scaffold extracted from patterns that worked across dozens of autonomous agent sessions. Copy it into any project to give agents a consistent structure for:

- **Orientation** — `AGENTS.md` is the single entry point every session starts from.
- **Architecture** — `documents/architecture/OVERVIEW.md` describes the system so agents understand what they're building.
- **Session discipline** — `documents/guides/SESSION_PROTOCOL.md` defines start/end checklists, sandbox rules, and promise sentinels that prevent common agent failures (one-shotting, broken builds, lost context).
- **Code quality** — `documents/guides/CODING_STANDARDS.md` sets coding rules, testing expectations, and security baseline.
- **Task tracking** — `documents/tasks/tasks.json` gives agents an ordered, dependency-aware task list with binary pass/fail status.
- **Continuity** — `progress.txt` bridges sessions so each new agent knows what happened and what to do next.

## Scripts

### `scaffold-docs.sh`

Copies the project documentation template into a target directory. Will not overwrite existing files, so it's safe to run on a project that already has some docs.

```bash
bash scripts/scaffold-docs.sh /path/to/your-project
bash scripts/scaffold-docs.sh .
```

Creates `AGENTS.md`, `documents/` tree, `progress.txt`, and `tasks.json` with `{{PLACEHOLDER}}` values to fill in.

### `sandbox-bootstrap.sh`

Creates (or reuses) a Docker Sandbox for a project and copies your local OpenCode config into it. Run once before using the agent loop.

```bash
bash scripts/sandbox-bootstrap.sh --name my-project --workdir /path/to/project
bash scripts/sandbox-bootstrap.sh --name my-project    # uses current directory
bash scripts/sandbox-bootstrap.sh my-project            # positional name
```

**Options:**

| Flag | Description |
|---|---|
| `--name NAME` | Sandbox name (default: current directory name) |
| `--workdir PATH` | Workspace directory (default: current directory) |
| `--config PATH` | Override OpenCode config path (default: `~/.config/opencode/opencode.json`) |
| `--agent NAME` | Agent name (default: `opencode`) |
| `-y` | Disable interactive prompts |
| `--dry-run` | Print commands without running |
| `-v, --verbose` | Show detailed output |

**Requirements:** `docker` CLI with `docker sandbox` support, `jq`.

### `run_loop.py`

Runs an agent autonomously in a loop inside a Docker Sandbox. Each iteration starts a fresh OpenCode session. The agent is expected to emit a promise sentinel in its output to signal the loop what to do next:

| Sentinel | Effect |
|---|---|
| `<promise>PROGRESS</promise>` | Continue to next iteration |
| `<promise>COMPLETE</promise>` | Stop — all tasks done |
| `<promise>BLOCKED:reason</promise>` | Stop — needs human input |
| `<promise>DECIDE:question</promise>` | Stop — needs a design decision |

```bash
python3 scripts/run_loop.py --sandbox my-project           # up to 10 iterations
python3 scripts/run_loop.py --sandbox my-project --once     # single iteration
python3 scripts/run_loop.py --sandbox my-project -n 5       # 5 iterations
```

The sandbox name can also be set via the `RUDDER_SANDBOX` environment variable.

**Requirements:** Python 3, `docker sandbox` CLI, a bootstrapped sandbox.

## Opt-out

If a project contains a `.agentops.off` file at the repo root, global ops are not applied.
