#!/bin/bash
# BELCORT Harness — Safety Hook (PreToolUse)
# Blocks dangerous operations during harness execution.
# Install: Add to ~/.claude/settings.json under hooks.PreToolUse

TOOL_INPUT="${1:-}"

# Block force push
echo "$TOOL_INPUT" | grep -qE 'git\s+push.*--force' && \
  echo "BLOCKED: force push not allowed in harness mode" && exit 1

# Block harness state deletion
echo "$TOOL_INPUT" | grep -qE 'rm\s+(-rf?\s+)?.*\.harness' && \
  echo "BLOCKED: cannot delete .harness/" && exit 1

# Block sudo
echo "$TOOL_INPUT" | grep -qE '^\s*sudo\s' && \
  echo "BLOCKED: sudo not allowed" && exit 1

# ─────────────────────────────────────────────────────────────
# REWARD-HACKING GUARD — block test-file deletion during BUILD phase
# ─────────────────────────────────────────────────────────────
# A common Generator failure mode (reward hacking): when a test fails and the
# Generator can't make it pass, it deletes the test. The Evaluator then sees
# "all tests pass" and awards a high Test Coverage score even though coverage
# actually dropped. This block prevents the most obvious form of that attack.
#
# Only fires when the harness is in the 'building' phase AND the tool input
# looks like it's deleting a test file. Non-test deletions and non-build phases
# are unaffected.
if [ -f ".harness/manifest.yaml" ]; then
  PHASE=$(grep 'phase:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 20)
  if [ "$PHASE" = "building" ]; then
    # Match `rm` (with any flags) followed by a path containing a test-ish marker.
    # Patterns: *.test.*, *.spec.*, __tests__/, /test/, /tests/, /e2e/, .playwright.ts
    if echo "$TOOL_INPUT" | grep -qE 'rm\s+(-[a-z]+\s+)*[^ ]*(\.test\.|\.spec\.|__tests__/|/tests?/|/e2e/|playwright\.config)'; then
      echo "BLOCKED: deleting test files during 'building' phase is forbidden (reward-hacking guard)." >&2
      echo "If this deletion is legitimate, document the reason in your commit message with" >&2
      echo "the tag [tests-removed: <reason>], run /harness:rewind building, then retry." >&2
      exit 1
    fi
  fi
fi

exit 0
