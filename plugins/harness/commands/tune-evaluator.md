---
description: Review Evaluator divergence patterns from tuning-log.md and propose calibration improvements (new few-shot examples or criteria prompt changes). Conservative by default — prefer examples over prompt edits.
---

# `/harness:tune-evaluator` — Review divergences and propose calibration improvements

Runs independently of sprints. Analyzes accumulated `.harness/evaluator/tuning-log.md` entries to surface patterns and propose concrete changes to Evaluator calibration.

Like `/harness:retrospective`, this is an orchestrator-driven command — no subagent dispatch. The orchestrator reads the log, groups divergences, and proposes low-risk fixes first.

## When to invoke

- The sprint pipeline suggests it after ≥3 entries in the same divergence category.
- After a string of feels-wrong evaluations, to check if it's a pattern.
- Periodically (every 5–10 features) as a health check.

## Default posture: CONSERVATIVE

Most divergences should result in **adding a calibration example** to `examples.md`, not changing the Evaluator prompt. Prompt changes are justified ONLY when a behavioral pattern is systematic AND example calibration hasn't already fixed it. Prompt edits compound — every prompt edit affects every future evaluation. Start with examples.

## Procedure

### Step 1: Precondition check

The orchestrator verifies `.harness/evaluator/tuning-log.md` exists and contains at least one entry. If empty or missing, tell the user "No tuning-log entries yet — nothing to tune" and exit.

### Step 2: Read and group divergences

Orchestrator reads the full tuning-log.md and groups entries by the `Divergence` category:

- **Leniency** — Evaluator too soft (false PASS)
- **Strictness** — Evaluator too harsh (false FAIL)
- **Missed issue** — Evaluator didn't test an edge case that mattered
- **Overclaim** — Evaluator flagged something that wasn't broken
- **Scope confusion** — Evaluator graded outside the contract
- **Other**

### Step 3: Analyze patterns per category

For each category with ≥3 entries (or explicit user invocation for <3), the orchestrator:
1. Reads the specific divergences in that category.
2. Reads `.harness/evaluator/examples.md` to check if calibration examples already cover the pattern.
3. Assesses: calibration gap (example missing) vs. systematic behavioral issue (example present but not helping).

### Step 4: Present findings

```
═══════════════════════════════
  Harness — Evaluator Tuning Review
═══════════════════════════════
Log entries analyzed: [N]
Patterns detected: [N]

Pattern 1: Leniency on edge-case testing  (6 entries)
  Entries: [list]
  Existing examples covering this: [M]
  Assessment: calibration gap / systematic / unclear
  Proposed action:
    [a] Add calibration example to examples.md (preferred, low risk)
    [b] Edit evaluator.md prompt (higher risk, only if examples insufficient)
    [c] Defer — insufficient signal, revisit later

Pattern 2: ...

For each pattern: choose [a], [b], [c], or [skip].
═══════════════════════════════
```

### Step 5: Apply approved actions

For each pattern the user approves:

**Action [a] — Add calibration example**: The orchestrator drafts an entry following the format in `examples.md` (symptom → correct Evaluator response), shows it to the user for approval, then uses the `Edit` tool to append it to `.harness/evaluator/examples.md`.

**Action [b] — Edit evaluator prompt**: The orchestrator drafts a specific before/after diff on `${CLAUDE_PLUGIN_ROOT}/agents/evaluator.md`, presents it, and requires typed confirmation (`I-AM-EDITING-THE-EVALUATOR-PROMPT`). On confirmation, uses the `Edit` tool on evaluator.md, then uses the `Edit` tool on `.harness/manifest.yaml` to bump `harness.model_tuning_revision` by 1 (create the field as integer 1 if missing).

**Action [c] — Defer**: The orchestrator uses the `Edit` tool to mark each entry in tuning-log.md as `reviewed: deferred YYYY-MM-DD` so they don't resurface on the next run.

### Step 6: Log ADR (mandatory if prompt edited)

For any prompt edit to evaluator.md, the orchestrator appends to `.harness/progress/decisions.md`:

```markdown
## ADR-NNN — Evaluator prompt tuning: [short title]
**Date**: YYYY-MM-DD
**Status**: Accepted

### Context
Tuning review of [N] log entries surfaced a [Leniency / Strictness / ...] pattern.
Existing examples did not correct it.

### Decision
Edited evaluator.md §[section]: [before → after]
Bumped manifest → harness.model_tuning_revision to [N].

### Consequences
- All future evaluations use the updated prompt
- [Any specific expected impact on divergences]
```

### Step 7: Append to changelog

```markdown
## YYYY-MM-DD — Evaluator tuning
- Log entries reviewed: [N]
- Examples added: [N]
- Prompt edits applied: [N]
- Entries deferred: [N]
- model_tuning_revision: [N]
```

## Anti-patterns

- **Over-eager prompt editing**: every divergence becomes a prompt change. Leads to prompt bloat and overfitting. Default to examples.
- **Single-case prompt changes**: editing based on one divergence. Wait for a pattern.
- **Silent prompt edits**: any change to evaluator.md MUST log an ADR. Without it, the change is unauditable.
- **Ignoring strictness divergences**: only attending to false PASSes. False FAILs waste retry cycles just as badly.

## Files written

| File | Writer |
|---|---|
| `.harness/evaluator/examples.md` | Orchestrator appends approved examples via Edit |
| `agents/evaluator.md` | Orchestrator applies approved prompt diffs via Edit (rare) |
| `.harness/evaluator/tuning-log.md` | Orchestrator marks deferred entries |
| `manifest.yaml → harness.model_tuning_revision` | Orchestrator bumps on prompt edit |
| `progress/decisions.md` | Orchestrator appends ADR on prompt edit |
| `progress/changelog.md` | Orchestrator appends |
