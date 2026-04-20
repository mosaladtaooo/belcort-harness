#!/bin/bash
# BELCORT Harness — Safety Hook (PreToolUse)
#
# Reads Claude Code's tool-call JSON payload from STDIN and blocks dangerous
# patterns. Claude Code passes the payload as JSON like:
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
#
# It is NOT passed as $1 — the previous version of this hook read $1 (always
# empty), causing every safety check to silently grep against the empty
# string and pass. That meant force-push, sudo, and .harness/ deletion blocks
# never actually fired. This rewrite fixes the underlying parse bug.
#
# Exit codes (Claude Code convention):
#   0 — allow tool call
#   1 — block tool call (stderr message is shown to the user)
#
# Failure mode: if the JSON parse fails (no jq, no python3, malformed input),
# the hook EXITS 0 — failing open. Failing closed would block every tool
# call in the user's session, which is worse than letting safety rails be
# temporarily inactive. A WARN line goes to stderr instead.

set -u

# Read the entire stdin payload
INPUT="$(cat)"

# ─────────────────────────────────────────────────────────────
# JSON parsing helpers — jq preferred, python3 fallback
# ─────────────────────────────────────────────────────────────
parse_json_field() {
  local field_path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "${field_path} // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    # Convert .a.b.c → ["a","b","c"]; walk the dict
    printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    keys = "'"$field_path"'".lstrip(".").split(".")
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k, "")
        else:
            val = ""
            break
    print(val if val is not None else "")
except Exception:
    pass
' 2>/dev/null
  else
    # No JSON parser available — return empty so caller sees "no command"
    return 0
  fi
}

if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "WARN: BELCORT pre-tool-use hook needs 'jq' or 'python3' to parse tool input." >&2
  echo "      Without one, harness safety rails (force-push block, sudo block, etc.)" >&2
  echo "      are inactive. Run /harness:doctor for install instructions." >&2
  exit 0
fi

TOOL_NAME=$(parse_json_field '.tool_name')

# Only Bash invocations are inspected — other tools have different schemas
# and different risk profiles. Add per-tool checks here if needed later.
[ "$TOOL_NAME" = "Bash" ] || exit 0

TOOL_CMD=$(parse_json_field '.tool_input.command')

# Empty command — nothing to inspect (let Claude Code handle the error)
[ -n "$TOOL_CMD" ] || exit 0

# ─────────────────────────────────────────────────────────────
# Safety rails (universally applied to all Bash invocations)
# ─────────────────────────────────────────────────────────────
block() {
  echo "BLOCKED: $1" >&2
  exit 1
}

# 1. Force push — destroys remote history
echo "$TOOL_CMD" | grep -qE 'git\s+push.*--force' && \
  block "force push not allowed in harness mode"

# Also catch the short form `git push -f`
echo "$TOOL_CMD" | grep -qE 'git\s+push\s+(-[a-z]*f|.*\s-f(\s|$))' && \
  block "force push (-f) not allowed in harness mode"

# 2. Deletion of .harness/ — would destroy the entire pipeline state
echo "$TOOL_CMD" | grep -qE 'rm\s+(-[a-zA-Z]+\s+)*[^|;&]*\.harness(/|$|\s)' && \
  block "cannot delete .harness/ — that's the harness state directory"

# 3. sudo — escalation should never happen inside an agent loop
echo "$TOOL_CMD" | grep -qE '(^|[|;&]\s*)sudo(\s|$)' && \
  block "sudo not allowed in harness mode"

# ─────────────────────────────────────────────────────────────
# Reward-hacking guard: block test-file deletion during BUILD phase
# ─────────────────────────────────────────────────────────────
# A common Generator failure mode: when a test fails and the Generator can't
# fix the code, it deletes the test. The Evaluator then sees "all tests pass"
# and awards a high Test Coverage score even though coverage actually dropped.
# This block prevents the most obvious form of that attack. The Evaluator's
# git-archaeology scan catches the subtler variants (modify-instead-of-delete,
# .skip injection, etc.).
if [ -f ".harness/manifest.yaml" ]; then
  PHASE=$(grep '^[[:space:]]*phase:' .harness/manifest.yaml 2>/dev/null \
            | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 20)
  if [ "$PHASE" = "building" ]; then
    # Patterns matched (preceded by word boundary `\b` so `tests/` matches
    # whether at path start (`tests/foo`) or mid-path (`src/tests/foo`),
    # without false-positive on `mytests/`):
    #   .test.  .spec.  __tests__/  tests/  test/  e2e/  playwright.config
    if echo "$TOOL_CMD" | grep -qE 'rm\s+(-[a-zA-Z]+\s+)*[^|;&]*(\.test\.|\.spec\.|__tests__/|\btests?/|\be2e/|playwright\.config)'; then
      echo "BLOCKED: deleting test files during 'building' phase is forbidden (reward-hacking guard)." >&2
      echo "If this deletion is legitimate, document the reason in your commit message with" >&2
      echo "the tag [tests-removed: <reason>], run /harness:rewind building, then retry." >&2
      exit 1
    fi
  fi
fi

exit 0
