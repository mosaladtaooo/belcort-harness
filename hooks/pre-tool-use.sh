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

exit 0
