# Agent Ops Manual

Global operating manual for all agent projects.

## Purpose

Defines standardized development, testing, and safety practices used across projects.

## Structure

- `ops/` contains the authoritative docs.

## Opt-out

If a project contains a `.agentops.off` file at repo root, global ops MUST NOT be applied.

## Usage

1. Symlink `ops/` into your Opencode config directory (see Opencode docs for path).
2. Opencode loads these docs by default unless opt-out marker is present.
