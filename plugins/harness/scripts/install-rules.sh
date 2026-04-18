#!/bin/bash
# BELCORT Harness — CLAUDE.md Installer
# Idempotently patches ~/.claude/CLAUDE.md with harness behavioral rules.
# Re-runs safely (replaces existing block in place); removable via uninstall-rules.sh.

set -euo pipefail

# Plugin root detection: prefer CLAUDE_PLUGIN_ROOT (set by Claude Code when invoked
# from a plugin command/hook); fall back to script-relative path for direct invocation.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SNIPPET="$PLUGIN_ROOT/CLAUDE.md.snippet.txt"
TARGET="$HOME/.claude/CLAUDE.md"
VERSION="1.2"

if [ ! -f "$SNIPPET" ]; then
  echo "ERROR: snippet not found at $SNIPPET" >&2
  echo "       (expected CLAUDE.md.snippet.txt at plugin root)" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"
touch "$TARGET"

BEGIN_MARKER="<!-- BELCORT-HARNESS BEGIN v${VERSION} -->"
END_MARKER="<!-- BELCORT-HARNESS END -->"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Strip any existing harness block (any version), preserve everything else
awk '
  /<!-- BELCORT-HARNESS BEGIN/ { skip=1; next }
  /<!-- BELCORT-HARNESS END -->/ { skip=0; next }
  !skip { print }
' "$TARGET" > "$TMP"

# Check if block was already present before our edit
if grep -q "<!-- BELCORT-HARNESS BEGIN v${VERSION} -->" "$TARGET" 2>/dev/null; then
  ACTION="Upgraded to"
  # Check if content actually differs
  EXISTING="$(awk '/<!-- BELCORT-HARNESS BEGIN/,/<!-- BELCORT-HARNESS END -->/' "$TARGET" | \
              sed -e '1d' -e '$d')"
  if [ "$EXISTING" = "$(cat "$SNIPPET")" ]; then
    echo "BELCORT Harness rules v${VERSION} already up to date at $TARGET"
    exit 0
  fi
elif grep -q "<!-- BELCORT-HARNESS BEGIN" "$TARGET" 2>/dev/null; then
  ACTION="Migrated to"
else
  ACTION="Installed"
fi

# Append new block
{
  cat "$TMP"
  # Ensure one blank line separator if target had content
  [ -s "$TMP" ] && echo ""
  echo "$BEGIN_MARKER"
  cat "$SNIPPET"
  echo "$END_MARKER"
} > "$TARGET"

echo "$ACTION BELCORT Harness rules v${VERSION} at $TARGET"
echo "Rules are active in new Claude Code sessions (CLAUDE.md auto-loads)."
echo "To remove: run scripts/uninstall-rules.sh"
