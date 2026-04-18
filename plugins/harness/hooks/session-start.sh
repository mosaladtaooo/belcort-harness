#!/bin/bash
# BELCORT Harness — SessionStart Hook
# Fires on session start, resume, clear, and compact.
# Injects DYNAMIC per-directory state only. Static behavioral rules live in
# ~/.claude/CLAUDE.md (installed by /harness:setup) so they survive compaction.

set -u

# Only act if there's an active harness in this directory.
# Otherwise stay silent — CLAUDE.md already tells Claude how to recognize
# trigger phrases and suggest /harness:sprint.
[ -f ".harness/manifest.yaml" ] || exit 0

PHASE=$(grep 'phase:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 20)
PROJECT=$(grep -A2 '^project:' .harness/manifest.yaml 2>/dev/null | grep 'name:' | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 50)
CURRENT_FEATURE=$(grep 'current_feature:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 50)
RETRIES=$(grep 'retry_count:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 5)

cat <<EOF
<harness-state>
BELCORT Harness is ACTIVE in this project.
- Project: ${PROJECT:-unnamed}
- Current feature: ${CURRENT_FEATURE:-none}
- Phase: ${PHASE:-unknown}
- Retry count: ${RETRIES:-0}

Read .harness/manifest.yaml before doing anything else. The harness skill is registered — invoke it via the Skill tool when needed.

If phase is not "complete": tell the user "Active harness found (feature: ${CURRENT_FEATURE:-none}, phase: ${PHASE:-unknown}). Run /harness:resume to continue, or ask me anything else."

If phase is "complete": tell the user "Last feature (${CURRENT_FEATURE:-none}) shipped. Run /harness:sprint to start a new feature, or check ROADMAP.md for planned work."

Do NOT start coding or answer technical questions about this project until you've acknowledged the harness state.
</harness-state>
EOF

exit 0
