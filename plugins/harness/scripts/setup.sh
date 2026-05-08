#!/usr/bin/env bash
# BELCORT Harness — Project-local Setup (v2)
# Creates .harness/ with baseline templates and installs the project CLAUDE.md.
# Idempotent; safe to run multiple times.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEMPLATES="$PLUGIN_ROOT/templates"

if [ ! -d "$TEMPLATES" ]; then
  echo "ERROR: templates directory not found at $TEMPLATES" >&2
  exit 1
fi

# 1. Create .harness/ structure
mkdir -p .harness/spec .harness/evaluator .harness/features .harness/progress

# 2. Copy baseline templates if not already present (never overwrite user customisations)
copy_if_missing() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    echo "  keep: $dst (already exists, not overwriting)"
  else
    cp "$src" "$dst"
    echo "  new:  $dst"
  fi
}

copy_if_missing "$TEMPLATES/manifest.yaml"                          ".harness/manifest.yaml"
copy_if_missing "$TEMPLATES/ROADMAP.md"                             ".harness/ROADMAP.md"
copy_if_missing "$TEMPLATES/progress/changelog.md"                  ".harness/progress/changelog.md"
copy_if_missing "$TEMPLATES/progress/decisions.md"                  ".harness/progress/decisions.md"
copy_if_missing "$TEMPLATES/progress/known-issues.md"               ".harness/progress/known-issues.md"
copy_if_missing "$TEMPLATES/evaluator/criteria.md.txt"              ".harness/evaluator/criteria.md"
copy_if_missing "$TEMPLATES/evaluator/examples.md.txt"              ".harness/evaluator/examples.md"
copy_if_missing "$TEMPLATES/evaluator/tuning-log.md.txt"            ".harness/evaluator/tuning-log.md"

# 3. Install or patch project-local CLAUDE.md
PROJECT_CLAUDE_MD="./CLAUDE.md"
SNIPPET="$TEMPLATES/CLAUDE.md.project.txt"
BEGIN_MARKER="<!-- BELCORT-HARNESS BEGIN v2 -->"
END_MARKER="<!-- BELCORT-HARNESS END -->"

if [ ! -f "$SNIPPET" ]; then
  echo "ERROR: project snippet template missing at $SNIPPET" >&2
  exit 1
fi

touch "$PROJECT_CLAUDE_MD"

# Strip any existing BELCORT-HARNESS block (any version)
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
awk '
  /<!-- BELCORT-HARNESS BEGIN/ { skip=1; next }
  /<!-- BELCORT-HARNESS END -->/ { skip=0; next }
  !skip { print }
' "$PROJECT_CLAUDE_MD" > "$TMP"

# Append fresh block
{
  cat "$TMP"
  [ -s "$TMP" ] && echo ""
  echo "$BEGIN_MARKER"
  cat "$SNIPPET"
  echo "$END_MARKER"
} > "$PROJECT_CLAUDE_MD"

echo ""
echo "BELCORT Harness installed in this project."
echo "  .harness/            - harness state directory"
echo "  ./CLAUDE.md          - project-local activation rules (scoped to this project only)"
echo ""
echo "Next: run '/harness:doctor' to verify the environment, then '/harness:sprint \"<what to build>\"' to start."

# 4. Legacy global-install check (non-fatal warning)
if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q "<!-- BELCORT-HARNESS BEGIN" "$HOME/.claude/CLAUDE.md"; then
  echo ""
  echo "NOTE: A legacy global BELCORT-HARNESS block was detected at ~/.claude/CLAUDE.md."
  echo "      In v2+ the harness rules install project-local, not globally. You can remove"
  echo "      the legacy global block by running: bash '$PLUGIN_ROOT/scripts/uninstall-rules.sh'"
fi
