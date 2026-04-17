---
description: Fast pipeline — skip Planner, use minimal contract, single build + QA pass. Use for small well-defined tasks (<30 min).
argument-hint: "<what to build, concise>"
---

# `/harness:quick`

Invoke the BELCORT Harness skill and execute the **`/harness:quick`** procedure with the user's prompt: `$ARGUMENTS`

Read `skills/harness/SKILL.md` and follow the `/harness:quick "<prompt>"` section. Differences from `sprint`:

- Skip the Planner entirely
- Write a minimal inline contract (Generator drafts, no negotiation)
- Single Generator → Evaluator pass (no retry loop)
- Skip retrospective

If the task turns out to be larger than expected mid-build, offer to promote to a full sprint. If `$ARGUMENTS` is empty, ask the user what to build first.
