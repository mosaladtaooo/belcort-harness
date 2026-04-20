---
description: Fast pipeline — skip Planner, use minimal contract, single build + QA pass. Use for small well-defined tasks (<30 min).
argument-hint: "<what to build, concise>"
---

# `/harness:quick` — Fast Mode

For small changes where planning overhead > implementation time. The user's prompt is `$ARGUMENTS`. If empty, ask what to build first.

## When to use `/harness:quick` vs `/harness:sprint`

Picking between the two is the most common decision point and gets hand-wavy ("use quick for small tasks"). Here's a concrete rubric:

| Signal | Use `/harness:quick` | Use `/harness:sprint` |
|--------|---------------------|----------------------|
| **Scope** | One component or one file | Multiple components, cross-cutting concerns |
| **Novel decisions** | None — approach is obvious | At least one of: new stack choice, new data shape, new API surface |
| **Test strategy** | Unit tests suffice | Playwright flows needed, or multi-layer integration |
| **Estimated elapsed time** | < 30 min of build | ≥ 30 min, OR unknown |
| **Can you write the AC list in one sentence per AC, without research?** | Yes | No |
| **Does it touch the constitution?** | No — fits existing principles | Maybe — needs architecture deliberation |
| **Is this a bug fix with a clear reproduction?** | Yes → quick | No, or bug is deep → sprint |

**The 30-minute heuristic is the tiebreaker.** If you're unsure and the build will take ≥ 30 min, take the extra 5 min to run `/harness:sprint` — you save time on the back half by catching spec ambiguities before the Generator locks in an approach. If you're under 30 min and have high confidence in the approach, `/harness:quick` is the right call.

**Auto-promotion**: if `/harness:quick` Generator reports its self-eval as PARTIAL with ≥2 unresolved decisions, or if the Evaluator flags multiple FRs at `Met? = N`, the orchestrator suggests promoting to `/harness:sprint` before retrying. The 30-min guess was wrong — reshape the work.

## Procedure

### 0. DOCTOR — Environment preflight (mandatory, blocking)

Even for quick builds, the environment must be ready. The Generator needs context7, the Evaluator needs playwright. Run doctor first:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

Exit-code handling (same rules as `/harness:sprint` — keep them aligned):
- `0` → environment ready, proceed to step 1.
- `1` → CRITICAL failure. Stop. Show the doctor report. Tell the user: "Fix the items above and re-run."
- `2` → doctor itself errored (unreadable manifest, malformed config). Treat as a hard stop — do not dispatch anything. Tell the user: "The doctor could not complete its own checks (exit 2). Run `bash \"${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh\"` manually and investigate the error output."

Do not dispatch any subagent until the CRITICAL items are resolved. See [doctor.md](doctor.md).

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
