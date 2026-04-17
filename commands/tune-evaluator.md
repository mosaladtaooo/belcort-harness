---
description: Review Evaluator divergence patterns from tuning-log.md and propose calibration improvements (new few-shot examples or criteria prompt changes). Conservative by default — prefer examples over prompt edits.
---

# `/harness:tune-evaluator` — Review divergence patterns and propose prompt improvements

Runs independently of sprints. Analyzes accumulated `tuning-log.md` entries to surface patterns and propose concrete changes to Evaluator calibration.

**When to invoke:**
- The sprint pipeline suggests it after detecting ≥3 entries of the same divergence category
- After a string of feels-wrong evaluations, to check if it's a pattern
- Periodically (every 5-10 features) as a health check

## Why it exists

Anthropic's documented tuning loop: "read the evaluator's logs, find examples where its judgment diverged from mine, and update the QAs prompt to solve for those issues." This command formalizes that loop.

The default posture is CONSERVATIVE. Most divergences should result in adding an example to `examples.md`, not changing the Evaluator prompt. Prompt changes are only justified when a behavioral pattern is systematic and example calibration hasn't fixed it.

## Procedure

1. Read `.harness/evaluator/tuning-log.md` entirely.

2. Group entries by divergence category:
   - Leniency (Evaluator too soft)
   - Strictness (Evaluator too harsh — false FAILs)
   - Missed issue (Evaluator didn't test edge case)
   - Overclaim (Evaluator flagged something that wasn't actually broken)
   - Scope confusion (Evaluator graded outside contract)
   - Other

3. For each category with ≥3 entries, run pattern analysis:
   - Read the specific divergences
   - Check `examples.md` for calibration examples already covering this pattern
   - Determine: is this a calibration gap, or a systematic behavioral issue?

4. Report:

```
═══════════════════════════════
  Harness — Evaluator Tuning Review
═══════════════════════════════
Log entries analyzed: [N]
Patterns detected: [N]

Pattern 1: Leniency on edge case testing
  Entries: [list of log entries]
  Root cause assessment: [calibration gap / behavioral / unclear]
  Existing examples covering this: [N]

  Proposed action:
    [ ] Add calibration example to examples.md (preferred — low risk)
    [ ] Update evaluator.md prompt (higher risk — only if examples insufficient)
    [ ] Defer — not enough signal yet, revisit after more entries

Pattern 2: [...]

Recommendations:
  - Low-risk: [add N examples to examples.md]
  - Higher-risk: [specific prompt tweaks, if any]
═══════════════════════════════
```

5. Present recommendations to the user. For each:
   - If user approves "add example" → draft the example, show it, append to `examples.md` on confirmation
   - If user approves "update prompt" → draft the specific prompt diff (show before/after), apply to `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/evaluator.md` on confirmation, and log the change as an ADR in `progress/decisions.md` for traceability
   - If user defers → mark entries in tuning-log.md as "reviewed, deferred" so they don't resurface immediately

6. On any prompt change to `evaluator.md`:
   - Update `manifest.yaml` → `harness.model_tuning_revision` field (new, integer counter)
   - Note in the ADR: which feature's tuning log triggered this, what was changed, why

## Anti-patterns

- **Over-eager prompt editing**: Every divergence becoming a prompt change. This leads to prompt bloat and overfitting. Default to examples; touch the prompt only for systematic issues.
- **Single-case prompt changes**: Changing `evaluator.md` based on one divergence. Not enough signal. Wait for pattern.
- **Silent prompt edits**: Changing the prompt without logging why. Impossible to audit later. Every prompt change must produce an ADR.
- **Ignoring strictness divergences**: Only attending to leniency. False FAILs waste retry cycles just as badly as false PASSes ship bugs.

If there are <3 divergences in any category, tell the user there's not enough signal yet and recommend revisiting after more sprints.
