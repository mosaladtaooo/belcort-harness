#!/bin/bash
# BELCORT Harness — SessionStart Hook (v2.1)
# Minimal: detect harness, nudge the skill. State reading is done by the skill
# itself — this hook is only a 1-line trigger.
#
# Dispatch note: v2.1.0 migrated subagent dispatch from `claude -p` subprocesses
# to native Agent-tool dispatch (plugin-declared subagent_types: harness:planner,
# harness:generator, harness:evaluator). Agent-tool subagents do NOT set
# CLAUDE_SUBAGENT=1 — they rely on Claude Code's own context isolation plus the
# <SUBAGENT-CONTEXT> block in each agent.md.
#
# The CLAUDE_SUBAGENT=1 check below is retained as a backward-compat shim for
# users who still invoke `claude -p` externally (rare). Within the harness
# pipeline, no command sets it.

set -u

# Legacy shim: skip injection if an external caller explicitly marked this as a
# subagent invocation via CLAUDE_SUBAGENT=1. Harmless for Agent-tool dispatches
# (which don't set the var).
if [ "${CLAUDE_SUBAGENT:-0}" = "1" ]; then
  exit 0
fi

# Only act if there's an active harness in this directory.
[ -f ".harness/manifest.yaml" ] || exit 0

cat <<'EOF'
<harness-state>
BELCORT Harness detected in this project (.harness/manifest.yaml present).

Invoke the harness skill via the Skill tool before acting. The skill reads
manifest.yaml, progress/changelog.md, and git log to figure out the current
phase and recommend next steps. Do not answer technical questions or start
coding about this project until the skill has run.
</harness-state>
EOF

exit 0
