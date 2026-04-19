---
description: Fast pipeline — skip Planner, use minimal contract, single build + QA pass. Use for small well-defined tasks (<30 min).
argument-hint: "<what to build, concise>"
---

# `/harness:quick` — Fast Mode

For small changes where planning overhead > implementation time. The user's prompt is `$ARGUMENTS`. If empty, ask what to build first.

## Procedure

### 0. DOCTOR — Environment preflight (mandatory, blocking)

Even for quick builds, the environment must be ready. The Generator needs context7, the Evaluator needs playwright. Run doctor first:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

If doctor exits non-zero, stop and show its output. Do not dispatch any subagent until the CRITICAL items are resolved. See [doctor.md](doctor.md).

1. Write a minimal contract directly (no Planner subagent):
   ```markdown
   # Quick Build Contract
   ## Task: $ARGUMENTS
   ## Test Criteria:
   - [ ] [inferred from the prompt]
   ## Done when: tests pass, lint clean, feature works
   ```
2. Dispatch Generator immediately (see [sprint.md § 3. BUILD](sprint.md) for the dispatch block — `quick` reuses it verbatim)
3. Single Evaluator pass (no retry loop — see [sprint.md § 4. EVALUATE](sprint.md) for the dispatch block)
4. Merge on pass, report on fail

If the task turns out to be larger than expected mid-build, offer to promote to a full `/harness:sprint`.
