#!/usr/bin/env python3
"""
rudder-loop.py — Ralph Loop

Runs OpenCode one fresh context per iteration, optionally inside a Docker Sandbox.
Sandbox creation is handled by scripts/sandbox-bootstrap.sh.
"""

import argparse
import itertools
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


def run_iteration(
    iteration: int,
    max_iterations: int | None,
    sandbox_name: str | None = None,
    use_sandbox: bool = True,
    workdir: str | None = None,
    prompt: str | None = None,
) -> bool:
    """Run one iteration of the loop. Returns True if we should continue."""
    iter_display = str(max_iterations) if max_iterations is not None else "∞"
    print(f"{BLUE}[loop]{NC} ═══════════════════════════════════════════")
    print(f"{BLUE}[loop]{NC} Iteration {iteration} of {iter_display}")
    print(f"{BLUE}[loop]{NC} ═══════════════════════════════════════════")

    prompt = prompt or generate_prompt()

    if use_sandbox:
        assert sandbox_name is not None, "sandbox_name required when use_sandbox=True"
        workspace_path = get_workspace_path(sandbox_name)
        cmd = ["docker", "sandbox", "exec", sandbox_name] + shlex_split(
            f'opencode run --dir {workspace_path} "{prompt}"'
        )
        print(f"{BLUE}[loop]{NC} Starting agent in {workspace_path}...")
    else:
        work_dir = workdir or os.getcwd()
        cmd = shlex_split(f'opencode run --dir {work_dir} "{prompt}"')
        print(f"{BLUE}[loop]{NC} Starting agent in {work_dir}...")

    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
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
        description="Run the Ralph Loop: iterate OpenCode sessions, optionally inside a Docker Sandbox."
    )
    parser.add_argument(
        "-n",
        "--iterations",
        type=int,
        default=None,
        help="Maximum number of iterations (default: unlimited)",
    )
    parser.add_argument("--once", action="store_true", help="Run a single iteration")
    parser.add_argument(
        "--prompt", type=str, default=None,
        help="Prompt to pass to the agent each iteration (default: built-in session prompt)",
    )
    parser.add_argument(
        "--no-sandbox",
        action="store_true",
        help="Run without Docker Sandbox (uses --workdir or current directory)",
    )
    parser.add_argument(
        "--workdir",
        type=str,
        default=None,
        help="Working directory when running without a sandbox (default: current directory)",
    )
    parser.add_argument(
        "--sandbox",
        type=str,
        default=os.environ.get("RUDDER_SANDBOX"),
    )
    parser.add_argument("sandbox_name", nargs="?", default=None)

    args = parser.parse_args()

    if args.prompt and args.prompt.startswith("@"):
        prompt_file = Path(args.prompt[1:])
        if not prompt_file.is_file():
            print(f"Error: prompt file not found: {prompt_file}", file=sys.stderr)
            sys.exit(1)
        args.prompt = prompt_file.read_text()

    if args.once:
        args.iterations = 1

    use_sandbox = not args.no_sandbox
    sandbox_name: str | None = None

    if use_sandbox:
        sandbox_name = args.sandbox_name or args.sandbox
        if not sandbox_name:
            print(
                "Error: sandbox name is required (or use --no-sandbox to run locally)",
                file=sys.stderr,
            )
            parser.print_help()
            sys.exit(1)

    max_iterations: int | None = args.iterations
    iter_display = str(max_iterations) if max_iterations is not None else "∞"
    sandbox_display = sandbox_name if sandbox_name else "(none)"

    print(f"{BLUE}╔══════════════════════════════════════╗{NC}")
    print(f"{BLUE}║      Agentic Loop .                  ║{NC}")
    print(f"{BLUE}║  Iterations: {iter_display:<3}                      ║{NC}")
    print(f"{BLUE}║  Sandbox: {sandbox_display:<25}║{NC}")
    print(f"{BLUE}╚══════════════════════════════════════╝{NC}")
    print()

    counter = (
        range(1, max_iterations + 1)
        if max_iterations is not None
        else itertools.count(1)
    )

    for i in counter:
        should_continue = run_iteration(
            iteration=i,
            max_iterations=max_iterations,
            sandbox_name=sandbox_name,
            use_sandbox=use_sandbox,
            workdir=args.workdir,
            prompt=args.prompt,
        )
        if not should_continue:
            print(f"{BLUE}[loop]{NC} Loop stopped at iteration {i}.")
            break

        at_limit = max_iterations is not None and i >= max_iterations
        if not at_limit:
            print(f"{BLUE}[loop]{NC} Pausing 5s...")
            time.sleep(5)

    print()
    print(f"{BLUE}[loop]{NC} Done.")
    print(f"{BLUE}[loop]{NC} Progress:   cat progress.txt")
    print(
        f"{BLUE}[loop]{NC} Remaining:  cat documents/tasks/tasks.json | jq '.tasks[] | select(.passes==false)'"
    )


if __name__ == "__main__":
    main()
