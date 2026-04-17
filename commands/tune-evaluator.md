---
description: Review Evaluator divergence patterns from tuning-log.md and propose calibration improvements (new few-shot examples or criteria prompt changes).
---

# `/harness:tune-evaluator`

Invoke the BELCORT Harness skill and execute the **`/harness:tune-evaluator`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:tune-evaluator` section. In order:

1. Read `.harness/evaluator/tuning-log.md` — identify categories with ≥3 unreviewed divergences
2. For each pattern: propose ONE of these fixes (ranked by invasiveness):
   - Add a calibrated few-shot example to `.harness/evaluator/examples.md`
   - Add project-specific guidance to `.harness/spec/evaluator-notes.md`
   - Modify the criteria rubric in `.harness/evaluator/criteria.md` (rare, heavier change)
3. Present proposed changes — wait for user approval
4. Apply changes
5. Bump `manifest.harness.model_tuning_revision` and reset `tuning_debt.unreviewed_divergences` counters for reviewed categories
6. Append an entry to `.harness/progress/decisions.md` documenting the calibration change

If there are <3 divergences in any category, tell the user there's not enough signal yet and recommend revisiting after more sprints.
