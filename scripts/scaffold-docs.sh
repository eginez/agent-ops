#!/usr/bin/env bash
set -euo pipefail

# scaffold-docs.sh — Copy the project documentation template into a target directory.
#
# Usage:
#   bash scripts/scaffold-docs.sh /path/to/your-project
#   bash scripts/scaffold-docs.sh .

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/project-docs"

if [ $# -lt 1 ]; then
    echo "Usage: scaffold-docs.sh <target-directory>"
    echo ""
    echo "Copies the project documentation template into the target directory."
    echo "Will NOT overwrite existing files — safe to run on an existing project."
    exit 1
fi

TARGET="$1"

if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory"
    exit 1
fi

# Create directory structure
mkdir -p "$TARGET/documents/architecture"
mkdir -p "$TARGET/documents/guides"
mkdir -p "$TARGET/documents/tasks"

# Copy files, skipping any that already exist
copy_if_missing() {
    local src="$1"
    local dst="$2"
    if [ -f "$dst" ]; then
        echo "  SKIP  $dst (already exists)"
    else
        cp "$src" "$dst"
        echo "  CREATE $dst"
    fi
}

echo "Scaffolding project docs into $TARGET ..."
echo ""

copy_if_missing "$TEMPLATE_DIR/AGENTS.md"                                    "$TARGET/AGENTS.md"
copy_if_missing "$TEMPLATE_DIR/progress.txt"                                 "$TARGET/progress.txt"
copy_if_missing "$TEMPLATE_DIR/documents/architecture/OVERVIEW.md"           "$TARGET/documents/architecture/OVERVIEW.md"
copy_if_missing "$TEMPLATE_DIR/documents/guides/SESSION_PROTOCOL.md"         "$TARGET/documents/guides/SESSION_PROTOCOL.md"
copy_if_missing "$TEMPLATE_DIR/documents/guides/CODING_STANDARDS.md"         "$TARGET/documents/guides/CODING_STANDARDS.md"
copy_if_missing "$TEMPLATE_DIR/documents/tasks/tasks.json"                   "$TARGET/documents/tasks/tasks.json"

echo ""
echo "Done. Next steps:"
echo "  1. Fill in {{PLACEHOLDER}} values in AGENTS.md"
echo "  2. Fill in the architecture overview in documents/architecture/OVERVIEW.md"
echo "  3. Define your tasks in documents/tasks/tasks.json"
echo "  4. Seed progress.txt with your project's starting state"
echo "  5. Point your agent at AGENTS.md"
