# Architecture Overview

## System Summary

Agent Ops is a development tool that enables autonomous coding agent workflows. It provides:

1. A **documentation template** that gives agents the structure they need to work autonomously across sessions
2. An **agent-loop binary** that runs OpenCode sessions in a loop with promise sentinel-based control flow
3. **Docker sandbox tooling** for reproducible, isolated agent execution

The system operates through these high-level autonomous steps:

1. Initialize and orient the agent using AGENTS.md
2. Check progress and recent commits for session continuity
3. Load the task registry and identify the next task to work on
4. Execute the task with frequent commits
5. Verify build/test/lint status before ending session
6. Signal completion or progress via promise sentinels

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Agent Loop (Go)                              │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  - Manages autonomous agent sessions                          │  │
│  │  - Parses promise sentinels from agent output                │  │
│  │  - Controls loop iteration count and timing                  │  │
│  │  - Handles signals (Ctrl-C) for clean shutdown               │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         │                                                       │
         ▼                                                       ▼
┌────────────────────────┐                              ┌────────────────────────┐
│   Docker Sandbox VM    │                              │   Local Execution      │
│                        │                              │                        │
│  ┌──────────────────┐  │                              │  ┌──────────────────┐  │
│  │  OpenCode CLI    │  │                              │  │  OpenCode CLI    │  │
│  └──────────────────┘  │                              │  └──────────────────┘  │
│        │               │                              │        │               │
│        ▼               │                              │        ▼               │
│  ┌──────────────────┐  │                              │  ┌──────────────────┐  │
│  │  Project Workspace│ │                              │  │  Project Workspace│ │
│  └──────────────────┘  │                              │  └──────────────────┘  │
└────────────────────────┘                              └────────────────────────┘
```

### Layer Breakdown

1. **Interface Layer (agent-loop binary)**
   - CLI flags and argument parsing
   - Prompt generation and customization
   - Progress output with ANSI colors
   - Signal handling for graceful shutdown

2. **Service Layer**
   - Docker Sandbox integration
   - OpenCode CLI invocation
   - Git command execution
   - File system operations

3. **State Layer**
   - `progress.txt` — cross-session progress log
   - `documents/tasks/tasks.json` — task registry
   - `documents/tasks/TASK-*.md` — individual task specs
   - Git commit history for audit trail

### Promise Sentinel Flow

```
Agent Output → Parse Sentinels → Decision
    │               │                  │
    │               ├─ PROGRESS ──────┼─→ Continue loop
    │               ├─ COMPLETE ──────┼─→ Stop (all done)
    │               ├─ BLOCKED:reason ┼─→ Stop (needs human)
    │               └─ DECIDE:question┼─→ Stop (needs decision)
    ▼
