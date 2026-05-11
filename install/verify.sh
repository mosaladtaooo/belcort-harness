#!/bin/bash
# BELCORT Harness — Legacy Installation Verifier
# Checks the deprecated shell-install layout. Plugin installs should use
# /harness:doctor instead.

CLAUDE_DIR="${HOME}/.claude"
ERRORS=0

check() {
  local path="$1"
  local desc="$2"
  if [ -f "$path" ] || [ -d "$path" ]; then
    echo "  ✓ $desc"
  else
    echo "  ✗ $desc — MISSING ($path)"
    ERRORS=$((ERRORS + 1))
  fi
}

check_executable() {
  local path="$1"
  local desc="$2"
  if [ -x "$path" ]; then
    echo "  ✓ $desc (executable)"
  elif [ -f "$path" ]; then
    echo "  ✗ $desc — NOT EXECUTABLE ($path)"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✗ $desc — MISSING ($path)"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "══════════════════════════════════════════"
echo "  BELCORT Harness — Legacy Verification"
echo "══════════════════════════════════════════"
echo "This verifier is for the deprecated shell installer."
echo "Plugin users should run /harness:doctor from Claude Code."
echo ""
echo ""

echo "Skill:"
check "$CLAUDE_DIR/skills/harness/SKILL.md" "skills/harness/SKILL.md"

echo ""
echo "Agents:"
check "$CLAUDE_DIR/agents/planner.md" "agents/planner.md"
check "$CLAUDE_DIR/agents/generator.md" "agents/generator.md"
check "$CLAUDE_DIR/agents/evaluator.md" "agents/evaluator.md"

echo ""
echo "Hooks:"
check_executable "$CLAUDE_DIR/hooks/session-start.sh" "hooks/session-start.sh"
check_executable "$CLAUDE_DIR/hooks/pre-tool-use.sh" "hooks/pre-tool-use.sh"

echo ""
echo "Global config:"
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  if grep -q "BELCORT Harness Engine" "$CLAUDE_DIR/CLAUDE.md"; then
    echo "  ✓ CLAUDE.md mentions BELCORT Harness Engine"
  else
    echo "  ✗ CLAUDE.md exists but doesn't reference the harness — did you append CLAUDE.md.snippet?"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ✗ CLAUDE.md not found — create it and append CLAUDE.md.snippet"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Settings (hooks registration):"
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if grep -q "session-start.sh" "$CLAUDE_DIR/settings.json"; then
    echo "  ✓ settings.json references session-start.sh"
  else
    echo "  ✗ settings.json doesn't register session-start.sh hook"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ✗ settings.json not found"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "══════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
  echo "  ✓ All checks passed. Harness is installed."
else
  echo "  ✗ $ERRORS issue(s) found. See above."
fi
echo "══════════════════════════════════════════"

exit $ERRORS
