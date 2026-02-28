#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# rudder-loop.sh — Ralph Loop
#
# Runs OpenCode inside a Docker Sandbox, one fresh context per iteration.
# Sandbox creation is handled by scripts/sandbox-bootstrap.sh.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BOOTSTRAP="${SCRIPT_DIR}/sandbox-bootstrap.sh"

MAX_ITERATIONS=10
SANDBOX_NAME="${RUDDER_SANDBOX:-}"
LOG_DIR="${PROJECT_DIR}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [sandbox-name]

Run the Ralph Loop: iterate OpenCode sessions inside a Docker Sandbox.
Each iteration gets a fresh context window.

Options:
  -n, --iterations N       Number of iterations (default: 10)
  --once                   Run a single iteration
  --sandbox NAME           Sandbox name (required if not set via arg or env)
  --help                   Show this help

Arguments:
  sandbox-name             Sandbox name (overrides --sandbox and RUDDER_SANDBOX)

Environment:
  RUDDER_SANDBOX           Set sandbox name
  OPENCODE_CONFIG          Override default opencode config path
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -n | --iterations)
    MAX_ITERATIONS="$2"
    shift 2
    ;;
  --once)
    MAX_ITERATIONS=1
    shift
    ;;
  --sandbox)
    SANDBOX_NAME="$2"
    shift 2
    ;;
  --help) usage ;;
  -*)
    echo "Unknown option: $1"
    usage
    ;;
  *)
    if [[ -z "${_SANDBOX_POSITIONAL:-}" ]]; then
      SANDBOX_NAME="$1"
      _SANDBOX_POSITIONAL=1
      shift
    else
      echo "Unexpected argument: $1"
      usage
    fi
    ;;
  esac
done

if [[ -z "$SANDBOX_NAME" ]]; then
  echo "Error: sandbox name is required (positional arg or --sandbox NAME or RUDDER_SANDBOX env)" >&2
  usage
fi

mkdir -p "${LOG_DIR}"

# ---- Prompt ----

generate_prompt() {
  cat <<'PROMPT_EOF'
  You are autonomous agent, your task is to complete a development task. Start by reading the AGENTS.md and 
  then look for documents/guides/SESSION_PROTOCOL.md` — understand session workflow. Begin work now
PROMPT_EOF
}

# ---- Run One Iteration ----

run_iteration() {
  local i=$1
  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local log_file="${LOG_DIR}/iteration-${i}-${timestamp}.log"

  echo -e "${BLUE}[loop]${NC} ═══════════════════════════════════════════"
  echo -e "${BLUE}[loop]${NC} Iteration ${i} of ${MAX_ITERATIONS}"
  echo -e "${BLUE}[loop]${NC} ═══════════════════════════════════════════"

  local prompt
  prompt=$(generate_prompt)

  docker sandbox exec -it "${SANDBOX_NAME}" \
    opencode run --dir . "${prompt}" 2>&1 | tee "${log_file}"

  local exit_code=${PIPESTATUS[0]}

  # Parse status signal
  if grep -q '<promise>COMPLETE</promise>' "${log_file}"; then
    echo -e "${GREEN}[loop]${NC} ✅ ALL TASKS COMPLETE"
    return 1
  elif grep -q '<promise>BLOCKED:' "${log_file}"; then
    local reason
    reason=$(grep -o '<promise>BLOCKED:[^<]*</promise>' "${log_file}" | sed 's/<promise>BLOCKED://;s/<\/promise>//')
    echo -e "${RED}[loop]${NC} 🚫 BLOCKED: ${reason}"
    return 1
  elif grep -q '<promise>DECIDE:' "${log_file}"; then
    local question
    question=$(grep -o '<promise>DECIDE:[^<]*</promise>' "${log_file}" | sed 's/<promise>DECIDE://;s/<\/promise>//')
    echo -e "${YELLOW}[loop]${NC} ❓ DECISION NEEDED: ${question}"
    return 1
  elif grep -q '<promise>PROGRESS</promise>' "${log_file}"; then
    echo -e "${GREEN}[loop]${NC} ✔ Task completed, continuing..."
    return 0
  else
    echo -e "${YELLOW}[loop]${NC} ⚠ No status signal (exit code: ${exit_code})"
    if [[ ${exit_code} -ne 0 ]]; then
      echo -e "${RED}[loop]${NC} Agent exited with error. Stopping."
      return 1
    fi
    echo -e "${YELLOW}[loop]${NC} Continuing anyway..."
    return 0
  fi
}

# ---- Main ----

main() {
  echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      Rudder Loop — Ralph Style       ║${NC}"
  echo -e "${BLUE}║  Iterations: $(printf '%-3s' ${MAX_ITERATIONS})                      ║${NC}"
  echo -e "${BLUE}║  Sandbox: $(printf '%-25s' ${SANDBOX_NAME})║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
  echo ""

  for ((i = 1; i <= MAX_ITERATIONS; i++)); do
    if ! run_iteration "$i"; then
      echo -e "${BLUE}[loop]${NC} Loop stopped at iteration ${i}."
      break
    fi

    if [[ $i -lt $MAX_ITERATIONS ]]; then
      echo -e "${BLUE}[loop]${NC} Pausing 5s..."
      sleep 5
    fi
  done

  echo ""
  echo -e "${BLUE}[loop]${NC} Done. Logs: ${LOG_DIR}/"
  echo -e "${BLUE}[loop]${NC} Progress:   cat progress.txt"
  echo -e "${BLUE}[loop]${NC} Remaining:  cat documents/tasks/tasks.json | jq '.tasks[] | select(.passes==false)'"
}

main
