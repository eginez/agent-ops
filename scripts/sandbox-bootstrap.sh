#!/usr/bin/env bash
set -euo pipefail

CONFIG_SRC="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
SANDBOX_NAME=""
AGENT="opencode"
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
  echo "  --name NAME         sandbox name (default: current dir name)"
  echo "  --agent NAME        agent name (default: opencode)"
  echo "  --workdir PATH      workspace directory (default: current dir)"
  echo "  -y                  disable interactive prompts"
  echo "  --dry-run           print commands without running"
  echo "  -v, --verbose       show detailed output"
  echo "  -h, --help          show help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
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
  -y)
    NO_PROMPT=1
    shift 1
    ;;
  --dry-run)
    DRY_RUN=1
    shift 1
    ;;
  -v | --verbose)
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
  WORKDIR="$(pwd)"
fi

if [[ -z "$SANDBOX_NAME" ]]; then
  SANDBOX_NAME="$(basename "$WORKDIR")"
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

vlog "Workdir: $WORKDIR"
vlog "Config: $CONFIG_SRC"
vlog "Sandbox: $SANDBOX_NAME"
vlog "Agent: $AGENT"

if ! command -v jq >/dev/null 2>&1; then
  err "jq not found"
  exit 1
fi

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

info "Ensuring sandbox exists: $SANDBOX_NAME"
CREATE_OK=0
if [[ $DRY_RUN -eq 1 ]]; then
  run_cmd docker sandbox create --name "$SANDBOX_NAME" "$AGENT" "$WORKDIR"
else
  docker sandbox create --name "$SANDBOX_NAME" "$AGENT" "$WORKDIR" || CREATE_OK=$?
fi

if [[ $CREATE_OK -ne 0 ]]; then
  if docker sandbox ls --quiet | grep -qx "$SANDBOX_NAME"; then
    vlog "Sandbox already exists: $SANDBOX_NAME"
  else
    err "failed to create sandbox $SANDBOX_NAME"
    exit 1
  fi
fi

run_cmd docker sandbox network proxy "$SANDBOX_NAME" \
  --policy allow \
  --bypass-cidr 10.0.0.0/8 \
  --bypass-cidr 192.168.0.0/16 \
  --bypass-cidr 127.0.0.0/8 \
  --bypass-cidr "::1/128" \
  --bypass-cidr "fc00::/7" \
  --bypass-cidr "fe80::/10" || {
  warn "could not set network policy to allow for sandbox $SANDBOX_NAME"
}

run_cmd docker sandbox exec "$SANDBOX_NAME" sh -c 'mkdir -p ~/.config/opencode'
if [[ $DRY_RUN -eq 1 ]]; then
  vlog "DRY-RUN: jq '...' $CONFIG_SRC | docker sandbox exec -i $SANDBOX_NAME sh -c 'cat > ~/.config/opencode/opencode.json'"
else
  jq '.agent.build.permission = "allow"' "$CONFIG_SRC" \
    | docker sandbox exec -i "$SANDBOX_NAME" sh -c 'cat > ~/.config/opencode/opencode.json'
fi
success "Copied config to ~/.config/opencode/opencode.json (with yolo permissions)"

# Node.js native fetch (undici) does not respect HTTP_PROXY/HTTPS_PROXY by default.
# Inject a startup script that installs EnvHttpProxyAgent as the global dispatcher.
run_cmd docker sandbox exec -i "$SANDBOX_NAME" sh -c \
  'cat > ~/.node-proxy-setup.cjs << '"'"'EOF'"'"'
const { setGlobalDispatcher, EnvHttpProxyAgent } = require("undici");
setGlobalDispatcher(new EnvHttpProxyAgent());
EOF'
run_cmd docker sandbox exec -i "$SANDBOX_NAME" sh -c \
  'echo "export NODE_OPTIONS=\"--require \$HOME/.node-proxy-setup.cjs\"" >> ~/.bashrc && echo "export NODE_OPTIONS=\"--require \$HOME/.node-proxy-setup.cjs\"" >> ~/.profile'
success "Configured Node.js to use HTTP proxy for fetch"

if [[ $VERBOSE -eq 1 ]]; then
  run_cmd docker sandbox exec "$SANDBOX_NAME" sh -c 'ls -l ~/.config/opencode/opencode.json'
  run_cmd docker sandbox exec "$SANDBOX_NAME" ls "$WORKDIR"
fi
success "Bootstrap complete. Start the agent with: docker sandbox run $SANDBOX_NAME"
