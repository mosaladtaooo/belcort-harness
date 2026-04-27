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

# JSON parser — pre-tool-use.sh needs a working jq OR python (3.x) to parse tool
# input. Without one, the hook fails open and every safety rail (force-push
# block, .harness/ deletion block, test-file deletion guard) is silently inactive.
#
# MUST test actual execution, not just PATH existence. On Windows, python3.exe
# is often a Microsoft Store stub — command -v succeeds but running it does
# nothing. Hence the `-c 'print(1)'` probe below.
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -r '.' >/dev/null 2>&1; then
  JQ_VER=$(jq --version 2>/dev/null)
  add_result "CRITICAL" "PASS" "JSON parser (jq)" "${JQ_VER:-jq available}"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'print(1)' >/dev/null 2>&1; then
  PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
  add_result "CRITICAL" "PASS" "JSON parser (python3 fallback)" \
    "python3 ${PY_VER:-available} — jq preferred but not required"
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info.major>=3 else 1)' 2>/dev/null; then
  PY_VER=$(python --version 2>&1 | awk '{print $2}')
  add_result "CRITICAL" "PASS" "JSON parser (python fallback)" \
    "python ${PY_VER:-available} — 3.x detected (Windows-common naming); jq preferred but not required"
else
  # Detect the specific failure mode so the fix suggestion is accurate
  WIN_STUB_NOTE=""
  if command -v python3 >/dev/null 2>&1 && ! python3 -c 'print(1)' >/dev/null 2>&1; then
    WIN_STUB_NOTE=" (NOTE: python3 was found on PATH but does not execute — likely a Microsoft Store stub on Windows; install a real Python 3 from python.org or use jq instead)"
  fi
  add_result "CRITICAL" "FAIL" "JSON parser (jq or python 3.x)" \
    "no working jq/python3/python(3.x) detected — pre-tool-use.sh safety rails silently fail open${WIN_STUB_NOTE}" \
    "macOS: brew install jq  |  Debian/Ubuntu: apt install jq  |  Windows: winget install jqlang.jq  |  or install Python 3.x from python.org"
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

# Project-local CLAUDE.md check (v2+): verify ./CLAUDE.md has a BELCORT-HARNESS block
# if a .harness/ is present. Global ~/.claude/CLAUDE.md check was removed in v2 —
# harness rules install project-local now. If a legacy global block still exists,
# setup.sh warns the user about cleanup; doctor doesn't flag it as a failure.
if [ -d ".harness" ]; then
  if [ -f "./CLAUDE.md" ] && grep -q "BELCORT-HARNESS BEGIN" "./CLAUDE.md" 2>/dev/null; then
    add_result "CRITICAL" "PASS" "Project CLAUDE.md" "harness activation block present in ./CLAUDE.md"
  else
    add_result "CRITICAL" "FAIL" "Project CLAUDE.md" \
      ".harness/ exists but ./CLAUDE.md has no BELCORT-HARNESS activation block" \
      "Run: /harness:setup  (creates or patches ./CLAUDE.md)"
  fi
fi

# Agent file integrity — if plugin is corrupt, catch it before sprint
if [ -n "$PLUGIN_FOUND" ]; then
  PLUGIN_AGENTS_DIR="$(dirname "$PLUGIN_FOUND")/../../agents"
  for agent in planner generator evaluator; do
    if [ -f "$PLUGIN_AGENTS_DIR/${agent}.md" ] && [ -r "$PLUGIN_AGENTS_DIR/${agent}.md" ]; then
      add_result "CRITICAL" "PASS" "Agent file: ${agent}.md" "readable"
    else
      add_result "CRITICAL" "FAIL" "Agent file: ${agent}.md" \
        "not found or not readable at $PLUGIN_AGENTS_DIR/${agent}.md — plugin may be corrupt" \
        "Reinstall plugin: /plugin uninstall harness && /plugin install harness@belcort-harness"
    fi
  done
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

optional_plugin_check "superpowers"       "Generator BUILD delegates TDD cycle to superpowers:test-driven-development — strongly recommended" \
  "/plugin install superpowers@claude-plugins-official"
optional_plugin_check "frontend-design"   "Generator uses this for UI quality" \
  "/plugin install frontend-design@claude-plugins-official"
optional_plugin_check "security-guidance" "Generator+Evaluator OWASP checks" \
  "/plugin install security-guidance@claude-plugins-official"
optional_plugin_check "agentlint"         "Evaluator automated code quality scan (33 checks)" \
  "/plugin install agentlint@claude-plugins-official"
# v2.2+ — Designer subagent dispatches these via the Skill tool. WARN (not FAIL)
# is the right level: harness still runs without them (sprints without design loop
# work unchanged), but `/harness:design *` subcommands will halt with descriptive
# errors if these are missing.
optional_plugin_check "huashu-design"     "Designer EXPLORE+REROLL wrap this skill (v2.2+ design loop). Required for /harness:design explore and /harness:design reroll." \
  "/plugin marketplace add https://github.com/alchaincyf/huashu-design && /plugin install huashu-design"
optional_plugin_check "impeccable"        "Designer TEACH+AUDIT+EXTRACT wrap this skill (v2.2+ design loop). Required for /harness:design teach, /harness:design audit, /harness:design extract, and the auto-audit-gate in /harness:sprint." \
  "/plugin marketplace add https://github.com/pbakaus/impeccable && /plugin install impeccable"

# ─────────────────────────────────────────────────────────────
# RECOMMENDED: Bash permission pre-allows for npm-family commands
# ─────────────────────────────────────────────────────────────
# Generator BUILD runs `npm install`, `npx vitest run`, etc. If Claude Code's
# Bash-permission system hasn't pre-allowed these, the Generator will either
# (a) prompt interactively, breaking autonomy, or (b) get blocked, causing
# the pause-protocol to fire. Better to pre-allow at setup time.
# Detect by grepping the project's and user's .claude/settings.json for
# "Bash(npm *)"-style entries. Absence triggers a RECOMMEND warning with
# the exact fix command.
NPM_ALLOW_FOUND=0
for settings_path in ".claude/settings.json" "$CLAUDE_HOME/settings.json"; do
  if [ -f "$settings_path" ]; then
    if grep -qE '"Bash\(npm [*]\)"|"Bash\(npx [*]\)"|"Bash\(pnpm [*]\)"' "$settings_path" 2>/dev/null; then
      NPM_ALLOW_FOUND=1
      break
    fi
  fi
done
if [ "$NPM_ALLOW_FOUND" = "1" ]; then
  add_result "RECOMMEND" "PASS" "Bash npm/npx/pnpm pre-allow" "Claude Code settings allow npm-family commands without interactive approval"
else
  add_result "RECOMMEND" "WARN" "Bash npm/npx/pnpm pre-allow" \
    "Generator BUILD will likely prompt-or-block on npm/npx/pnpm — the pause protocol handles this gracefully, but it interrupts autonomous runs" \
    "Run in Claude Code: /allow Bash(npm *) Bash(npx *) Bash(pnpm *) Bash(node *)  — or edit .claude/settings.json → permissions.allow"
fi

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
