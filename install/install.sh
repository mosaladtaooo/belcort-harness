#!/bin/bash
# BELCORT Harness — Installer
# Copies harness files into ~/.claude/ and sets up hooks.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
CLAUDE_DIR="${HOME}/.claude"

echo "══════════════════════════════════════════"
echo "  BELCORT Harness — Installation"
echo "══════════════════════════════════════════"
echo ""
echo "Repo:   $REPO_ROOT"
echo "Target: $CLAUDE_DIR"
echo ""

# Confirm
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Ensure base directories exist
mkdir -p "$CLAUDE_DIR/skills/harness"
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/hooks"

# Backup existing files before overwriting
BACKUP_DIR="$CLAUDE_DIR/.harness-backup-$(date +%s)"
mkdir -p "$BACKUP_DIR"

backup_if_exists() {
  local target="$1"
  if [ -f "$target" ]; then
    local rel="${target#$CLAUDE_DIR/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp "$target" "$BACKUP_DIR/$rel"
    echo "  backed up: $rel"
  fi
}

echo ""
echo "→ Backing up existing harness files (if any)..."
backup_if_exists "$CLAUDE_DIR/skills/harness/SKILL.md"
backup_if_exists "$CLAUDE_DIR/agents/planner.md"
backup_if_exists "$CLAUDE_DIR/agents/generator.md"
backup_if_exists "$CLAUDE_DIR/agents/evaluator.md"
backup_if_exists "$CLAUDE_DIR/hooks/session-start.sh"
backup_if_exists "$CLAUDE_DIR/hooks/pre-tool-use.sh"

# Install files
echo ""
echo "→ Installing harness files..."
cp "$REPO_ROOT/skill/SKILL.md" "$CLAUDE_DIR/skills/harness/SKILL.md"
echo "  installed: skills/harness/SKILL.md"

cp "$REPO_ROOT/agents/planner.md" "$CLAUDE_DIR/agents/planner.md"
cp "$REPO_ROOT/agents/generator.md" "$CLAUDE_DIR/agents/generator.md"
cp "$REPO_ROOT/agents/evaluator.md" "$CLAUDE_DIR/agents/evaluator.md"
echo "  installed: agents/{planner,generator,evaluator}.md"

cp "$REPO_ROOT/hooks/session-start.sh" "$CLAUDE_DIR/hooks/session-start.sh"
cp "$REPO_ROOT/hooks/pre-tool-use.sh" "$CLAUDE_DIR/hooks/pre-tool-use.sh"
chmod +x "$CLAUDE_DIR/hooks/session-start.sh" "$CLAUDE_DIR/hooks/pre-tool-use.sh"
echo "  installed: hooks/{session-start,pre-tool-use}.sh"

# Instructions for CLAUDE.md
echo ""
echo "══════════════════════════════════════════"
echo "  Manual step required"
echo "══════════════════════════════════════════"
echo ""
echo "Add the contents of this file to your ~/.claude/CLAUDE.md:"
echo "  $REPO_ROOT/CLAUDE.md.snippet"
echo ""
echo "Append it, don't overwrite — you likely have other global config there."
echo ""

# Instructions for settings.json hooks registration
echo "══════════════════════════════════════════"
echo "  Hook registration"
echo "══════════════════════════════════════════"
echo ""
echo "Edit ~/.claude/settings.json and add these entries under 'hooks':"
echo ""
cat <<'EOF'
  "hooks": {
    "SessionStart": [
      { "command": "~/.claude/hooks/session-start.sh" }
    ],
    "PreToolUse": [
      { "command": "~/.claude/hooks/pre-tool-use.sh" }
    ]
  }
EOF
echo ""

# Verify
echo "══════════════════════════════════════════"
echo "  Installation complete"
echo "══════════════════════════════════════════"
echo ""
echo "Backup of previous files (if any): $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Complete the manual steps above"
echo "  2. Run: $SCRIPT_DIR/verify.sh"
echo "  3. In a project directory, run /harness:sprint \"<your first prompt>\""
echo ""
