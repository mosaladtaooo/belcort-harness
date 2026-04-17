#!/bin/bash
# BELCORT Harness Engine — SessionStart Hook
# Fires at every session start, resume, clear, or compact.
# Injects harness awareness into Claude's context.

set -u

# Check if harness state exists in current project
if [ -f ".harness/manifest.yaml" ]; then
  PHASE=$(grep 'phase:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 20)
  PROJECT=$(grep -A2 '^project:' .harness/manifest.yaml 2>/dev/null | grep 'name:' | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 50)
  CURRENT_FEATURE=$(grep 'current_feature:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 50)
  RETRIES=$(grep 'retry_count:' .harness/manifest.yaml 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 5)

  cat <<EOF
<harness-session-start>
BELCORT Harness Engine is ACTIVE for this project.
Project: ${PROJECT:-unnamed}
Current feature: ${CURRENT_FEATURE:-none}
Phase: ${PHASE:-unknown}
Retry count: ${RETRIES:-0}

You MUST read ~/.claude/skills/harness/SKILL.md RIGHT NOW.
Then briefly report the current status to the user.

If phase is not "complete":
  Tell the user: "Project has active harness (feature: ${CURRENT_FEATURE:-none}, phase: ${PHASE:-unknown}). Run /harness:resume to continue, or ask me anything else."

If phase is "complete":
  Tell the user: "Last feature (${CURRENT_FEATURE:-none}) shipped. Run /harness:sprint to start a new feature, or check ROADMAP.md for planned work."

Do NOT start coding or answer technical questions about this project until you've acknowledged the harness state.
</harness-session-start>
EOF
else
  cat <<EOF
<harness-session-start>
BELCORT Harness Engine is available but not active in this directory.

**The 1% rule:** If there is even a 1% chance the user's request would benefit from the harness pipeline, suggest it.

Trigger phrases that indicate harness-worthy work:
- "build", "create", "make a", "develop", "implement"
- "new feature", "new app", "new project"
- Anything taking more than 15 minutes to build well

Do NOT suggest the harness for:
- Quick questions ("how do I X?")
- Single-line fixes
- Conversational requests
- Clearly simple tasks

Suggestion format: "This looks like a project that could benefit from the harness. Want me to run /harness:sprint?"
</harness-session-start>
EOF
fi

exit 0
