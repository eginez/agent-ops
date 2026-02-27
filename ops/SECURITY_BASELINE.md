# Security Baseline

## Secrets

- Never commit secrets.
- Keep secrets outside repo.
- Use host env vars or secure vault for credentials.

## Sandbox

- Repo-only mounts for safety.
- No bind mounts for secrets.
- Sandbox env vars for sensitive data.

## Network

- Use allowlists where possible.
- Prefer offline tests (fixtures/mocks).
- Block internal network by default.

## Least Privilege

- Tools should only access what they need.
- Deny by default, allow explicitly.
- Audit all tool permissions.

## Data Handling

- Remove personal info from logs.
- Sanitize output before storing.
- Delete temporary files after use.
