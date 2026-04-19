#!/usr/bin/env bash
# BELCORT Harness — Environment Preflight
#
# Audits the local environment against everything the harness pipeline needs
# to run successfully. Blocks the pipeline if any CRITICAL check fails.
# Warns on RECOMMENDED misses but does not block.
#
# Exit codes:
#   0 — all critical checks passed (recommended may still be missing)
#   1 — one or more critical checks failed — pipeline must NOT proceed
#   2 — script itself errored (unreadable config, etc.)
#
# Usage:
#   doctor.sh              — human-readable report (default)
#   doctor.sh --strict     — also treat RECOMMENDED as failing (for CI)
#   doctor.sh --json       — machine-readable output for agents
#   doctor.sh --quiet      — print only on failure
#
# Designed to be copy-pasteable: every failure prints the exact fix command.

set -u

MODE="report"
STRICT=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --json)   MODE="json" ;;
    --strict) STRICT=1 ;;
    --quiet)  QUIET=1 ;;
    *) ;;
  esac
done

CRITICAL_FAIL=0
RECOMMENDED_FAIL=0
WARN_COUNT=0
REPORT=""
FIXES=""
JSON_ITEMS=""

add_result() {
  local severity="$1" status="$2" name="$3" detail="$4" fix="${5:-}"
  REPORT+=$'\n'"  [$severity] $status  $name"
  [ -n "$detail" ] && REPORT+=$'\n'"         $detail"
  case "$status" in
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac
  if [ "$status" = "FAIL" ]; then
    case "$severity" in
      CRITICAL) CRITICAL_FAIL=$((CRITICAL_FAIL + 1)) ;;
      RECOMMEND) RECOMMENDED_FAIL=$((RECOMMENDED_FAIL + 1)) ;;
    esac
    if [ -n "$fix" ]; then
      FIXES+=$'\n'"  # $name"$'\n'"  $fix"$'\n'
    fi
  fi
  if [ "$MODE" = "json" ]; then
    local esc_detail esc_fix
    esc_detail=$(printf '%s' "$detail" | sed 's/"/\\"/g')
    esc_fix=$(printf '%s' "$fix" | sed 's/"/\\"/g')
    [ -n "$JSON_ITEMS" ] && JSON_ITEMS+=","
    JSON_ITEMS+=$(printf '\n    {"severity":"%s","status":"%s","name":"%s","detail":"%s","fix":"%s"}' \
      "$severity" "$status" "$name" "$esc_detail" "$esc_fix")
  fi
}

# ─────────────────────────────────────────────────────────────
# CRITICAL: toolchain
# ─────────────────────────────────────────────────────────────

# Claude Code CLI
if command -v claude >/dev/null 2>&1; then
  CC_VER=$(claude --version 2>/dev/null | head -1 | awk '{print $NF}')
  add_result "CRITICAL" "PASS" "Claude Code CLI" "version: ${CC_VER:-unknown}"
else
  add_result "CRITICAL" "FAIL" "Claude Code CLI" \
    "\`claude\` not on PATH — harness dispatches subagents via \`claude -p\`" \
    "Install Claude Code: https://claude.com/claude-code"
fi

# Git
if command -v git >/dev/null 2>&1; then
  GIT_VER=$(git --version 2>/dev/null | awk '{print $3}')
  add_result "CRITICAL" "PASS" "git" "version: ${GIT_VER:-unknown}"
else
  add_result "CRITICAL" "FAIL" "git" \
    "git not installed — harness uses atomic commits + worktrees" \
    "macOS: xcode-select --install  |  Debian/Ubuntu: apt install git"
fi

# Node.js
if command -v node >/dev/null 2>&1; then
  NODE_VER_RAW=$(node --version 2>/dev/null | sed 's/v//')
  NODE_MAJOR="${NODE_VER_RAW%%.*}"
  if [ "${NODE_MAJOR:-0}" -ge 20 ] 2>/dev/null; then
    add_result "CRITICAL" "PASS" "Node.js ≥ 20" "version: ${NODE_VER_RAW}"
  else
    add_result "CRITICAL" "FAIL" "Node.js ≥ 20" \
      "found v${NODE_VER_RAW} — MCP servers (context7, playwright) need Node 20+" \
      "Install via nvm:  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && nvm install 20"
  fi
else
  add_result "CRITICAL" "FAIL" "Node.js ≥ 20" \
    "node not installed — MCP servers run as npx packages" \
    "macOS: brew install node  |  or via nvm: https://github.com/nvm-sh/nvm"
fi

# npx (usually bundled with node but check)
if command -v npx >/dev/null 2>&1; then
  add_result "CRITICAL" "PASS" "npx" "available"
else
  add_result "CRITICAL" "FAIL" "npx" \
    "npx not on PATH — required to launch MCP servers" \
    "Comes with Node.js — if missing, reinstall node"
fi

# ─────────────────────────────────────────────────────────────
# CRITICAL: MCP servers (the thing that burned the user last time)
# ─────────────────────────────────────────────────────────────

mcp_check() {
  local name="$1" pkg="$2" purpose="$3"
  if ! command -v claude >/dev/null 2>&1; then
    add_result "CRITICAL" "SKIP" "MCP: $name" "skipped — claude CLI not found"
    return
  fi
  # `claude mcp list` prints registered MCP servers; match case-insensitive on name or package
  local MCP_LIST
  MCP_LIST=$(claude mcp list 2>/dev/null || true)
  if printf '%s' "$MCP_LIST" | grep -qiE "(^|[[:space:]])${name}([[:space:]]|:|\$)|${pkg}"; then
    add_result "CRITICAL" "PASS" "MCP: $name" "registered ($purpose)"
  else
    add_result "CRITICAL" "FAIL" "MCP: $name" \
      "not registered — $purpose" \
      "claude mcp add $name -- npx -y $pkg"
  fi
}

mcp_check "context7"   "@upstash/context7-mcp@latest" "Planner+Generator docs lookup"
mcp_check "playwright" "@playwright/mcp@latest"       "Evaluator browser-driven QA"

# ─────────────────────────────────────────────────────────────
# CRITICAL: harness plugin presence
# ─────────────────────────────────────────────────────────────

CLAUDE_HOME="${HOME}/.claude"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

# Search every location the plugin could legitimately live:
# 1. $CLAUDE_PLUGIN_ROOT (set by Claude Code when invoked from plugin context)
# 2. ~/.claude/skills/harness/SKILL.md (legacy manual install)
# 3. ~/.claude/plugins/*/skills/harness/SKILL.md (pluginized install)
# 4. relative to this script (dev checkout)
PLUGIN_FOUND=""
PLUGIN_DETAIL=""

if [ -n "$PLUGIN_ROOT" ] && [ -f "$PLUGIN_ROOT/skills/harness/SKILL.md" ]; then
  PLUGIN_FOUND="$PLUGIN_ROOT/skills/harness/SKILL.md"
  PLUGIN_DETAIL="loaded via CLAUDE_PLUGIN_ROOT"
elif [ -f "$CLAUDE_HOME/skills/harness/SKILL.md" ]; then
  PLUGIN_FOUND="$CLAUDE_HOME/skills/harness/SKILL.md"
  PLUGIN_DETAIL="installed at ~/.claude/skills/harness/SKILL.md (legacy path)"
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../skills/harness/SKILL.md" ]; then
  PLUGIN_FOUND="$SCRIPT_DIR/../skills/harness/SKILL.md"
  PLUGIN_DETAIL="running from plugin checkout at $SCRIPT_DIR/.."
else
  # Search pluginized install locations under ~/.claude/plugins/
  for candidate in "$CLAUDE_HOME"/plugins/*/skills/harness/SKILL.md \
                   "$CLAUDE_HOME"/plugins/*/plugins/harness/skills/harness/SKILL.md; do
    if [ -f "$candidate" ]; then
      PLUGIN_FOUND="$candidate"
      PLUGIN_DETAIL="installed via plugin at ${candidate#$CLAUDE_HOME/}"
      break
    fi
  done
fi

if [ -n "$PLUGIN_FOUND" ]; then
  add_result "CRITICAL" "PASS" "Harness plugin" "$PLUGIN_DETAIL"
else
  add_result "CRITICAL" "FAIL" "Harness plugin" \
    "SKILL.md not found under CLAUDE_PLUGIN_ROOT, ~/.claude/skills, or ~/.claude/plugins/*" \
    "/plugin marketplace add mosaladtaooo/belcort-harness && /plugin install harness@belcort-harness"
fi

# CLAUDE.md rules (required for session-start behavior + 1% rule)
if [ -f "$CLAUDE_HOME/CLAUDE.md" ] && grep -q "BELCORT-HARNESS BEGIN" "$CLAUDE_HOME/CLAUDE.md" 2>/dev/null; then
  add_result "CRITICAL" "PASS" "Global harness rules" "installed in $CLAUDE_HOME/CLAUDE.md"
else
  add_result "CRITICAL" "FAIL" "Global harness rules" \
    "BELCORT-HARNESS block not found in ~/.claude/CLAUDE.md" \
    "Run: /harness:setup"
fi

# ─────────────────────────────────────────────────────────────
# CRITICAL (if inside a project): project writable + git
# ─────────────────────────────────────────────────────────────

if [ -d ".harness" ]; then
  if [ -w ".harness" ]; then
    add_result "CRITICAL" "PASS" "Project .harness/ writable" "exists and writable"
  else
    add_result "CRITICAL" "FAIL" "Project .harness/ writable" \
      ".harness/ exists but is not writable by current user" \
      "chmod -R u+w .harness/"
  fi
elif [ -w "." ]; then
  add_result "CRITICAL" "PASS" "Project directory writable" "no .harness/ yet, can create"
else
  add_result "CRITICAL" "FAIL" "Project directory writable" \
    "current directory not writable — harness needs to create .harness/" \
    "cd to a writable project directory"
fi

# Git repo state (warn not fail — some users start from a non-repo)
if command -v git >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
      add_result "RECOMMEND" "PASS" "Git working tree clean" "ready for atomic harness commits"
    else
      add_result "RECOMMEND" "WARN" "Git working tree clean" \
        "uncommitted changes present — harness commits may interleave with yours" \
        "git status  # review, then commit or stash before running /harness:sprint"
    fi
  else
    add_result "RECOMMEND" "WARN" "Git repository" \
      "not inside a git repo — harness worktrees and atomic commits are disabled" \
      "git init  # if you want full harness features"
  fi
fi

# ─────────────────────────────────────────────────────────────
# RECOMMENDED: optional plugins
# ─────────────────────────────────────────────────────────────

optional_plugin_check() {
  local plugin_name="$1" purpose="$2" install_cmd="$3"
  # Check both user-scope and plugin-scope skill directories
  if find "$CLAUDE_HOME/plugins" "$CLAUDE_HOME/skills" -maxdepth 4 -type d -iname "*${plugin_name}*" 2>/dev/null | grep -q .; then
    add_result "RECOMMEND" "PASS" "Optional: $plugin_name" "installed ($purpose)"
  else
    add_result "RECOMMEND" "WARN" "Optional: $plugin_name" \
      "not installed — $purpose" \
      "$install_cmd"
  fi
}

optional_plugin_check "frontend-design"   "Generator uses this for UI quality" \
  "/plugin install frontend-design@claude-plugins-official"
optional_plugin_check "security-guidance" "Generator+Evaluator OWASP checks" \
  "/plugin install security-guidance@claude-plugins-official"
optional_plugin_check "agentlint"         "Evaluator automated code quality scan (33 checks)" \
  "/plugin install agentlint@claude-plugins-official"

# ─────────────────────────────────────────────────────────────
# OUTPUT
# ─────────────────────────────────────────────────────────────

EXIT_CODE=0
[ "$CRITICAL_FAIL" -gt 0 ] && EXIT_CODE=1
[ "$STRICT" -eq 1 ] && [ "$RECOMMENDED_FAIL" -gt 0 ] && EXIT_CODE=1

if [ "$MODE" = "json" ]; then
  printf '{\n  "critical_failures": %d,\n  "recommended_failures": %d,\n  "warnings": %d,\n  "exit_code": %d,\n  "items": [%s\n  ]\n}\n' \
    "$CRITICAL_FAIL" "$RECOMMENDED_FAIL" "$WARN_COUNT" "$EXIT_CODE" "$JSON_ITEMS"
  exit "$EXIT_CODE"
fi

if [ "$QUIET" -eq 1 ] && [ "$EXIT_CODE" -eq 0 ]; then
  exit 0
fi

echo "═══════════════════════════════════════════════"
echo "  BELCORT Harness — Environment Preflight"
echo "═══════════════════════════════════════════════"
printf '%s\n' "$REPORT"
echo ""
echo "───────────────────────────────────────────────"
TOTAL_SOFT=$((RECOMMENDED_FAIL + WARN_COUNT))
if [ "$CRITICAL_FAIL" -eq 0 ] && [ "$TOTAL_SOFT" -eq 0 ]; then
  echo "  ✓ All checks passed. Harness ready."
elif [ "$CRITICAL_FAIL" -eq 0 ]; then
  echo "  ✓ Critical checks passed ($TOTAL_SOFT warning/recommended item(s) — see above)."
  echo "    Pipeline can proceed. Address warnings when convenient."
else
  echo "  ✗ $CRITICAL_FAIL critical check(s) failed — pipeline BLOCKED."
fi
echo "───────────────────────────────────────────────"

if [ -n "$FIXES" ]; then
  echo ""
  echo "Suggested fixes (copy-paste):"
  printf '%s\n' "$FIXES"
fi

exit "$EXIT_CODE"
