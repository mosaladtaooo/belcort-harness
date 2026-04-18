#!/bin/bash
# BELCORT Harness — CLAUDE.md Uninstaller
# Removes the harness block from ~/.claude/CLAUDE.md (any version).
# Preserves everything else in the file.

set -euo pipefail

TARGET="$HOME/.claude/CLAUDE.md"

if [ ! -f "$TARGET" ]; then
  echo "Nothing to do — $TARGET does not exist."
  exit 0
fi

if ! grep -q "<!-- BELCORT-HARNESS BEGIN" "$TARGET"; then
  echo "Nothing to do — no BELCORT Harness block found in $TARGET."
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

awk '
  /<!-- BELCORT-HARNESS BEGIN/ { skip=1; next }
  /<!-- BELCORT-HARNESS END -->/ { skip=0; next }
  !skip { print }
' "$TARGET" > "$TMP"

# Collapse multiple trailing blank lines to at most one
awk 'NF { blanks=0; print; next } { blanks++; if (blanks==1) print }' "$TMP" > "$TARGET"

echo "Removed BELCORT Harness rules from $TARGET"
echo "The plugin itself is still installed. Disable/remove with: /plugin disable harness"
