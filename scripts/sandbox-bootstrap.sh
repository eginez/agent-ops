#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
SANDBOX_NAME=""
AGENT="opencode"
ALLOW_HOSTS=()
NO_PROMPT=0
DRY_RUN=0
VERBOSE=0
WORKDIR=""

usage() {
  echo "Usage: $(basename "$0") [options] [sandbox-name]"
  echo
  echo "Create or reuse a sandbox for this repo, then copy OpenCode config into it."
  echo
  echo "Options:"
  echo "  --config PATH       override config path"
  echo "  --name NAME         sandbox name (default: opencode-<repo>)"
  echo "  --agent NAME        agent name (default: opencode)"
  echo "  --workdir PATH      workspace directory (default: repo root)"
  echo "  --allow-host HOST   allowlist host (repeatable)"
  echo "  -y                  disable interactive prompts"
  echo "  --dry-run           print commands without running"
  echo "  -v, --verbose       show detailed output"
  echo "  -h, --help          show help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --config)
      CONFIG_SRC="$2"
      shift 2
      ;;
    --name)
      SANDBOX_NAME="$2"
      shift 2
      ;;
    --agent)
      AGENT="$2"
      shift 2
      ;;
    --workdir)
      WORKDIR="$2"
      shift 2
      ;;
    --allow-host)
      ALLOW_HOSTS+=("$2")
      shift 2
      ;;
    -y)
      NO_PROMPT=1
      shift 1
      ;;
    --dry-run)
      DRY_RUN=1
      shift 1
      ;;
    -v|--verbose)
      VERBOSE=1
      shift 1
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option $1" >&2
      usage
      exit 2
      ;;
    *)
      if [[ -z "$SANDBOX_NAME" ]]; then
        SANDBOX_NAME="$1"
        shift 1
      else
        echo "Error: unexpected argument $1" >&2
        usage
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$WORKDIR" ]]; then
  WORKDIR="$REPO_DIR"
fi

if [[ -z "$SANDBOX_NAME" ]]; then
  SANDBOX_NAME="${AGENT}-$(basename "$WORKDIR")"
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  COLOR_GREEN="$(tput setaf 2)"
  COLOR_YELLOW="$(tput setaf 3)"
  COLOR_RED="$(tput setaf 1)"
  COLOR_BLUE="$(tput setaf 4)"
  COLOR_RESET="$(tput sgr0)"
else
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_BLUE=""
  COLOR_RESET=""
fi

log() {
  echo "$*"
}

info() {
  log "${COLOR_BLUE}info${COLOR_RESET} $*"
}

success() {
  log "${COLOR_GREEN}ok${COLOR_RESET} $*"
}

warn() {
  log "${COLOR_YELLOW}warn${COLOR_RESET} $*" >&2
}

err() {
  log "${COLOR_RED}error${COLOR_RESET} $*" >&2
}

vlog() {
  if [[ $VERBOSE -eq 1 ]]; then
    log "$*"
  fi
}

vlog "Repo: $REPO_DIR"
vlog "Workdir: $WORKDIR"
vlog "Config: $CONFIG_SRC"
vlog "Sandbox: $SANDBOX_NAME"
vlog "Agent: $AGENT"

if ! command -v docker >/dev/null 2>&1; then
  err "docker CLI not found"
  exit 1
fi

if ! docker sandbox version >/dev/null 2>&1; then
  err "docker sandbox command not available"
  exit 1
fi

if [[ ! -d "$WORKDIR" ]]; then
  err "workdir not found at $WORKDIR"
  exit 1
fi

if [[ ! -f "$CONFIG_SRC" ]]; then
  err "config not found at $CONFIG_SRC"
  exit 1
fi

if [[ ! "$SANDBOX_NAME" =~ ^[A-Za-z0-9._+-]+$ ]]; then
  err "invalid sandbox name '$SANDBOX_NAME'"
  err "Allowed: letters, numbers, dots, underscores, plus, minus"
  exit 1
fi

run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'DRY-RUN: %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi
  "$@"
}

CONFIG_BASE_LINE="$(grep -Eo '"baseURL"\s*:\s*"[^"]+"' "$CONFIG_SRC" | { IFS= read -r line; printf '%s' "$line"; })"
if [[ -n "$CONFIG_BASE_LINE" ]]; then
  CONFIG_BASE_URL="${CONFIG_BASE_LINE#*\"}"
  CONFIG_BASE_URL="${CONFIG_BASE_URL#*\"}"
  CONFIG_BASE_URL="${CONFIG_BASE_URL%\"}"
  CONFIG_BASE_HOST="${CONFIG_BASE_URL#*://}"
  CONFIG_BASE_HOST="${CONFIG_BASE_HOST%%/*}"
  if [[ -n "$CONFIG_BASE_HOST" ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
      info "Allowlist suggestion:"
      log "  docker sandbox network proxy $SANDBOX_NAME --allow-host $CONFIG_BASE_HOST"
    fi
    if [[ $NO_PROMPT -eq 0 && $DRY_RUN -eq 0 ]]; then
      read -r -p "Allowlist host $CONFIG_BASE_HOST? [y/N] " reply
      if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
        ALLOW_HOSTS+=("$CONFIG_BASE_HOST")
      fi
    fi
  fi
fi


info "Ensuring sandbox exists: $SANDBOX_NAME"
CREATE_OUT=""
CREATE_OK=0
if [[ $DRY_RUN -eq 1 ]]; then
  run_cmd docker sandbox create --name "$SANDBOX_NAME" "$AGENT" "$WORKDIR"
else
  CREATE_OUT="$(docker sandbox create --name "$SANDBOX_NAME" "$AGENT" "$WORKDIR" 2>&1)" || CREATE_OK=$?
  if [[ $CREATE_OK -eq 0 && $VERBOSE -eq 1 && -n "$CREATE_OUT" ]]; then
    log "$CREATE_OUT"
  fi
fi

if [[ $CREATE_OK -ne 0 ]]; then
  if docker sandbox ls --quiet | grep -qx "$SANDBOX_NAME"; then
    vlog "Sandbox already exists: $SANDBOX_NAME"
  else
    err "failed to create sandbox $SANDBOX_NAME"
    exit 1
  fi
fi

if [[ ${#ALLOW_HOSTS[@]} -gt 0 ]]; then
  for host in "${ALLOW_HOSTS[@]}"; do
    run_cmd docker sandbox network proxy "$SANDBOX_NAME" --allow-host "$host" || {
      warn "could not allowlist host $host"
    }
  done
fi

run_cmd docker sandbox exec "$SANDBOX_NAME" sh -c 'mkdir -p ~/.config/opencode'
if [[ $DRY_RUN -eq 1 ]]; then
  vlog "DRY-RUN: docker sandbox exec -i $SANDBOX_NAME sh -c 'cat > ~/.config/opencode/opencode.json' < $CONFIG_SRC"
else
  docker sandbox exec -i "$SANDBOX_NAME" sh -c 'cat > ~/.config/opencode/opencode.json' < "$CONFIG_SRC"
fi
success "Copied config to ~/.config/opencode/opencode.json"

if [[ $VERBOSE -eq 1 ]]; then
  run_cmd docker sandbox exec "$SANDBOX_NAME" sh -c 'ls -l ~/.config/opencode/opencode.json'
  run_cmd docker sandbox exec "$SANDBOX_NAME" ls "$WORKDIR"
fi
success "Bootstrap complete. Start the agent with: docker sandbox run $SANDBOX_NAME"
