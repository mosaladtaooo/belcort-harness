---
description: Verification debt scan (GSD-inspired) — finds deferred issues, stale known-issues, silent skips, TODO/FIXME without owners across the harness state.
---

# `/harness:audit` — Verification debt check

Runs independently of sprints. Scans all completed features for deferred verification items, stale known-issues, and silent skips.

## Procedure

1. Read `.harness/manifest.yaml` → `verification_debt` section
2. Scan every `features/*/eval-report.md` for Major/Minor findings marked "deferred"
3. Scan `.harness/progress/known-issues.md` for items older than 30 days
4. Scan every `features/*/retrospective.md` for unresolved drift
5. **Reward-hacking sweep** (git archaeology, cross-feature):
   - For each completed feature, check if the post-merge code still contains the test files the Evaluator claimed to verify. Missing test files → flag.
   - Run the same reward-hacking patterns the Evaluator uses in EVALUATE mode (`.skip`, trivial assertions, same-commit test+impl modifications) against the current codebase. Accumulated drift since the feature merged → flag.
   - Check `git log --all --diff-filter=D --name-only` for test deletions that don't have a matching ADR in `progress/decisions.md`. Untracked deletions → flag.
6. Cross-reference against current codebase (has anything been silently fixed?)
7. **Calibration metrics readout** (Trustworthy Agents Art.2). Read `manifest.yaml` → `config.calibration_metrics` and summarize the running interrupt-to-checkin ratio across completed sprints. Surface anomalies:
   - `user_interrupts` much greater than `agent_checkins` → harness is too silent; agents are missing ambiguities the user has to correct manually. Suggest reviewing Planner + Generator red-flags and tightening `/harness:clarify` suggestions.
   - `agent_checkins` much greater than `user_interrupts` on trivial tasks → harness is over-cautious, creating approval fatigue. Suggest relaxing the AskUserQuestions triggers in Planner.
   - Either ratio trending worse over time → call out the trend; raw numbers without direction aren't actionable.
   If counters are all zero, the orchestrator hasn't been incrementing them — flag as "calibration metrics not collected; see sprint.md §5b for increment points".
8. Report:
   ```
   ═══════════════════════════════
     Harness — Verification Audit
   ═══════════════════════════════
   Deferred findings: [N]
     - features/001/M1: "Empty state UI missing" (deferred 45 days ago)
     - features/003/m2: "Rate limit not implemented" (deferred 12 days ago)

   Stale known-issues: [N]
   Pending human questions: [N]
   Silently resolved (can be closed): [N]

   Reward-hacking indicators: [N]
     - features/002: 3 tests marked .skip() appeared post-merge (FR-006 coverage regressed)
     - global: 2 test files deleted with no ADR (src/lib/auth.test.ts, src/lib/token.test.ts)

   Calibration (last N sprints):
     user_interrupts : agent_checkins = 8 : 3  (ratio 2.67)
     Assessment: agents trending silent — 3 course corrections vs 1 clarifying question per sprint
     Suggestion: review /harness:clarify auto-suggest trigger in sprint.md step 2

   Recommendations:
     - Address M1 (old, may block shipping)
     - Close 3 items that are silently resolved
     - Investigate features/002 reward-hacking indicators — consider /harness:rewind + re-evaluate
     - Calibration: tighten Planner's clarify-trigger heuristic
   ═══════════════════════════════
   ```
8. Offer to promote high-priority items to new sprints via `/harness:sprint`

Do NOT auto-fix. Present findings and ask the user which to address.

**On reward-hacking indicators specifically**: do NOT close these without investigation. Unlike deferred findings (which are known and owned), reward-hacking indicators suggest the Evaluator may have been fooled on a feature that was claimed as shipped. The correct response is one of:
- Confirm it was legitimate (e.g., test was deleted because the feature was also deleted) → add an ADR retroactively
- Confirm it was reward-hacking → consider rolling back the feature or writing a regression test that re-covers the gap
- Uncertain → flag for deeper review; never silently close
