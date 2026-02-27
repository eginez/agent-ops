# Sandbox Development

## Principle

Development happens inside Docker Sandbox VM using OpenCode, via the `docker sandbox ...` command

## Why

- Sandboxes run in microVMs with a private Docker daemon.
- Workspace is isolated from host files outside the repo.
- Network access can be controlled per sandbox.

## Rules

- Repo-only mount for safety.
- Use repo-local scratch: `tmp/`.
- No secrets written in repo.
- Workspace syncs at the same absolute path between host and sandbox.

## Common Flow

1. Start sandbox with OpenCode: `docker sandbox run opencode /path/to/project`
2. Work inside the sandbox container
3. Use `exec` for additional shell access: `docker sandbox exec <sandbox> <command>`
4. List sandboxes when needed: `docker sandbox ls`

## Supported Agents

- Default agent is OpenCode: `docker sandbox run opencode /path/to/project`

## Configure Local Agent

Goal: make your host OpenCode config available inside the sandbox without mounting your home directory.

1. Use your host config file: `~/.config/opencode/opencode.json`.
2. Create a sandbox: `docker sandbox create --name opencode-<project> opencode /path/to/project`.
3. In the sandbox, place config at `~/.config/opencode/opencode.json`:

```console
$ docker sandbox exec <sandbox> mkdir -p ~/.config/opencode
$ docker sandbox exec -i <sandbox> sh -c "cat > ~/.config/opencode/opencode.json" < ~/.config/opencode/opencode.json
```

Notes:
- If the config needs secrets, keep them out of the file and pass them as sandbox env vars.
- Any extra tools referenced by your workflows must be installed inside the sandbox.
- If the local provider is a network endpoint, allowlist the host for the sandbox.

Example allowlist:

```console
$ docker sandbox network proxy <sandbox> --allow-host llm.services.eginez.xyz
```

## Bootstrap Script

Use `scripts/sandbox-bootstrap.sh` to create or reuse a sandbox, copy config, and run a quick check:

```console
$ ./scripts/sandbox-bootstrap.sh [sandbox-name]
$ ./scripts/sandbox-bootstrap.sh --config /path/to/opencode.json --name my-sandbox
$ ./scripts/sandbox-bootstrap.sh --allow-host llm.services.eginez.xyz
$ docker sandbox run <sandbox-name>

If no name is provided, the script uses `opencode-<repo>`.
You can also set `OPENCODE_CONFIG` to override the config path.
By default, the script can prompt to allowlist the config baseURL host; use `-y` to disable.
```

## Notes

- Sandboxes are ephemeral.
- Sandboxes persist per workspace until removed.
- Install tools in the dev container when needed.
- Scratch space should be in repo (`tmp/`) for persistence.
- Sandboxes do not appear in `docker ps`.
- Use multiple sandboxes for separate projects.
- MicroVM sandboxes require macOS or Windows; Linux uses legacy container sandboxes (Docker Desktop 4.57+).
