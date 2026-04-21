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
# JSON parser detection — pick the first one that ACTUALLY WORKS.
#
# On Windows, `python3.exe` is commonly a Microsoft Store stub that exists on
# PATH but doesn't execute — `command -v python3` succeeds, yet `python3 -c ...`
# returns empty. We must verify the interpreter actually runs Python, not just
# that it's resolvable. Same consideration for `python` on macOS vs Linux.
#
# Preference order: jq → python3 (real) → python (real).
# ─────────────────────────────────────────────────────────────
JSON_PARSER=""
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -r '.' >/dev/null 2>&1; then
  JSON_PARSER="jq"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'print(1)' >/dev/null 2>&1; then
  JSON_PARSER="python3"
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info.major>=3 else 1)' 2>/dev/null; then
  JSON_PARSER="python"
fi

parse_json_field() {
  local field_path="$1"
  case "$JSON_PARSER" in
    jq)
      printf '%s' "$INPUT" | jq -r "${field_path} // empty" 2>/dev/null
      ;;
    python3|python)
      # Convert .a.b.c → ["a","b","c"]; walk the dict
      printf '%s' "$INPUT" | "$JSON_PARSER" -c '
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
      ;;
    *)
      # No usable parser — return empty so caller sees "no command"
      return 0
      ;;
  esac
}

if [ -z "$JSON_PARSER" ]; then
  echo "WARN: BELCORT pre-tool-use hook needs a working 'jq', 'python3', or 'python' (3.x) to parse tool input." >&2
  echo "      Without one, harness safety rails (force-push block, sudo block, etc.)" >&2
  echo "      are inactive. Run /harness:doctor for install instructions." >&2
  echo "      Windows note: a non-functional Microsoft Store python3.exe stub is the most common cause." >&2
  exit 0
fi

TOOL_NAME=$(parse_json_field '.tool_name')

# Only Bash invocations get the rest of the safety rails — other tools have
# different schemas and different risk profiles.
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
