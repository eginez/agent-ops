#!/usr/bin/env python3
"""
rudder-loop.py — Ralph Loop

Runs OpenCode inside a Docker Sandbox, one fresh context per iteration.
Sandbox creation is handled by scripts/sandbox-bootstrap.sh.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

# Colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_DIR = SCRIPT_DIR.parent


def shlex_split(command: str) -> list:
    import shlex
    return shlex.split(command)


def generate_prompt() -> str:
    return (
        "You are autonomous agent, your task is to complete a development task. "
        "Start by reading the AGENTS.md and then look for "
        "documents/guides/SESSION_PROTOCOL.md — understand session workflow. Begin work now"
    )


def get_workspace_path(sandbox_name: str) -> str:
    """Get the workspace path for the sandbox from docker sandbox ls."""
    ls_result = subprocess.run(
        ["docker", "sandbox", "ls", "--json"], capture_output=True, text=True
    )
    try:
        sandboxes = json.loads(ls_result.stdout)
        workspace_path = next(
            (s["workspaces"] for s in sandboxes["vms"] if s["name"] == sandbox_name),
            None,
        )
        if workspace_path:
            return workspace_path[0]
    except (json.JSONDecodeError, StopIteration):
        pass
    raise RuntimeError(f"Could not find workspace for sandbox: {sandbox_name}")


def run_iteration(sandbox_name: str, iteration: int, max_iterations: int) -> bool:
    """Run one iteration of the loop. Returns True if we should continue."""
    print(f"{BLUE}[loop]{NC} ═══════════════════════════════════════════")
    print(f"{BLUE}[loop]{NC} Iteration {iteration} of {max_iterations}")
    print(f"{BLUE}[loop]{NC} ═══════════════════════════════════════════")

    workspace_path = get_workspace_path(sandbox_name)
    prompt = generate_prompt()

    cmd = (
        ["docker", "sandbox", "exec", sandbox_name]
        + shlex_split(f'opencode run --dir {workspace_path} "{prompt}"')
    )

    print(f"{BLUE}[loop]{NC} Starting agent in {workspace_path}...")

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert proc.stdout is not None

    buf = ""

    for line in proc.stdout:
        print(line, end="", flush=True)
        buf += line

        if "<promise>COMPLETE</promise>" in buf:
            print(f"\n{GREEN}[loop]{NC} ALL TASKS COMPLETE")
            proc.wait()
            return False
        elif "<promise>BLOCKED:" in buf:
            match = re.search(r"<promise>BLOCKED:([^<]+)</promise>", buf)
            reason = match.group(1) if match else "unknown"
            print(f"\n{RED}[loop]{NC} BLOCKED: {reason}")
            proc.wait()
            return False
        elif "<promise>DECIDE:" in buf:
            match = re.search(r"<promise>DECIDE:([^<]+)</promise>", buf)
            question = match.group(1) if match else "unknown"
            print(f"\n{YELLOW}[loop]{NC} DECISION NEEDED: {question}")
            proc.wait()
            return False
        elif "<promise>PROGRESS</promise>" in buf:
            print(f"\n{GREEN}[loop]{NC} Task completed, continuing...")
            proc.wait()
            return True

    proc.wait()

    if proc.returncode != 0:
        print(f"{RED}[loop]{NC} Agent exited with code {proc.returncode}")
        return False

    print(f"{RED}[loop]{NC} Agent finished without a promise sentinel")
    return False


def main():
    parser = argparse.ArgumentParser(
        description="Run the Ralph Loop: iterate OpenCode sessions inside a Docker Sandbox."
    )
    parser.add_argument("-n", "--iterations", type=int, default=10)
    parser.add_argument("--once", action="store_true", help="Run a single iteration")
    parser.add_argument(
        "--sandbox",
        type=str,
        default=os.environ.get("RUDDER_SANDBOX"),
    )
    parser.add_argument("sandbox_name", nargs="?", default=None)

    args = parser.parse_args()

    if args.once:
        args.iterations = 1

    sandbox_name = args.sandbox_name or args.sandbox
    if not sandbox_name:
        print("Error: sandbox name is required", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    max_iterations = args.iterations

    print(f"{BLUE}╔══════════════════════════════════════╗{NC}")
    print(f"{BLUE}║      Rudder Loop — Ralph Style       ║{NC}")
    print(f"{BLUE}║  Iterations: {max_iterations:<3}                      ║{NC}")
    print(f"{BLUE}║  Sandbox: {sandbox_name:<25}║{NC}")
    print(f"{BLUE}╚══════════════════════════════════════╝{NC}")
    print()

    for i in range(1, max_iterations + 1):
        if not run_iteration(sandbox_name, i, max_iterations):
            print(f"{BLUE}[loop]{NC} Loop stopped at iteration {i}.")
            break

        if i < max_iterations:
            print(f"{BLUE}[loop]{NC} Pausing 5s...")
            time.sleep(5)

    print()
    print(f"{BLUE}[loop]{NC} Done.")
    print(f"{BLUE}[loop]{NC} Progress:   cat progress.txt")
    print(f"{BLUE}[loop]{NC} Remaining:  cat documents/tasks/tasks.json | jq '.tasks[] | select(.passes==false)'")


if __name__ == "__main__":
    main()
