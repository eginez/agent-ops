# Agent Ops

A starter kit for software projects built with coding agents. Provides a documentation template that gives agents the structure they need to work autonomously across sessions, plus scripts to run agents in sandboxed environments.

## Installation

### Pre-built Binaries

Download the latest pre-built binary from GitHub Releases. Each commit to `main` is automatically built and released with a tag matching the commit hash (e.g., `vabc1234`).

```bash
# Download the latest release
curl -L -o agent-loop https://github.com/eginez/agent-ops/releases/latest/download/agent-loop-linux-amd64 && chmod +x agent-loop
```

Or download a specific version directly:

```bash
curl -L -o agent-loop https://github.com/eginez/agent-ops/releases/download/vabc1234/agent-loop-linux-amd64
chmod +x agent-loop
```

Verify the downloaded binary:

```bash
./agent-loop --version
```

## Quick Start

```bash
# 1. Download the latest pre-built binary
curl -L -o agent-loop https://github.com/eginez/agent-ops/releases/latest/download/agent-loop-linux-amd64
chmod +x agent-loop

# 2. Scaffold docs into your project
bash scripts/scaffold-docs.sh /path/to/your-project

# 3. Fill in the {{PLACEHOLDER}} values in AGENTS.md and the documents/ tree

# 4. Bootstrap a sandbox for the project
bash scripts/sandbox-bootstrap.sh --name my-project --workdir /path/to/your-project

# 5. Run the agent loop
./agent-loop -sandbox my-project
```

## Structure

```
agent-ops/
├── go.mod
├── src/
│   └── cmd/
│       └── agent-loop/
│           └── main.go              # Agent loop (Go)
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
    └── run_loop.py                  # Agent loop (Python, legacy)
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

### `agent-loop` (Go)

Runs an agent autonomously in a loop, optionally inside a Docker Sandbox. Each iteration starts a fresh OpenCode session. The agent is expected to emit a promise sentinel in its output to signal the loop what to do next:

| Sentinel | Effect |
|---|---|
| `<promise>PROGRESS</promise>` | Continue to next iteration |
| `<promise>COMPLETE</promise>` | Stop — all tasks done |
| `<promise>BLOCKED:reason</promise>` | Stop — needs human input |
| `<promise>DECIDE:question</promise>` | Stop — needs a design decision |

**Build:**

```bash
GOOS=linux GOARCH=amd64 go build -o agent-loop-linux-amd64 ./src/cmd/agent-loop
```

**Run:**

```bash
# Sandbox mode (default) — requires a bootstrapped sandbox
./agent-loop -sandbox my-project              # unlimited iterations
./agent-loop -sandbox my-project -once        # single iteration
./agent-loop -sandbox my-project -n 5         # cap at 5 iterations
./agent-loop my-project                       # positional sandbox name

# No-sandbox mode — runs opencode directly in the local working directory
./agent-loop -no-sandbox
./agent-loop -no-sandbox -workdir /path/to/project

# Custom prompt
./agent-loop -no-sandbox -prompt "Fix all failing tests"
./agent-loop -no-sandbox -prompt @prompts/my-task.txt
```

**Options:**

| Flag | Description |
|---|---|
| `-n N` | Cap the loop at N iterations (default: unlimited) |
| `-once` | Run a single iteration |
| `-no-sandbox` | Skip Docker Sandbox; run `opencode` locally |
| `-workdir PATH` | Working directory when using `-no-sandbox` (default: cwd) |
| `-sandbox NAME` | Sandbox name (also accepts positional arg or `RUDDER_SANDBOX` env var) |
| `-prompt TEXT` | Override the built-in agent prompt; prefix with `@` to read from a file |

**Stopping the loop:**

Press `Ctrl-C` at any time. `agent-loop` will kill the running opencode process (inside the sandbox via `pkill -9 -f opencode`, or locally) and exit cleanly.

**Requirements:** Go 1.21+. Docker Sandbox and a bootstrapped sandbox are only required without `-no-sandbox`.

### `run_loop.py` (legacy)

The original Python implementation of the agent loop. Kept for reference. See `agent-loop` above for the current version.

```bash
python3 scripts/run_loop.py --sandbox my-project
```

**Requirements:** Python 3.

## Opt-out

If a project contains a `.agentops.off` file at the repo root, global ops are not applied.

## Development

### Building from Source

```bash
GOOS=linux GOARCH=amd64 go build -o agent-loop-linux-amd64 ./src/cmd/agent-loop
```

### Running Tests

```bash
make test
```

### Versioning

The binary version is derived from the Git commit hash. When built from source, `./agent-loop --version` outputs the short commit hash of the build. GitHub Releases are automatically created for each commit pushed to `main`, tagged with `v<short-hash>`.
