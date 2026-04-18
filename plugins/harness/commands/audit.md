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
5. Cross-reference against current codebase (has anything been silently fixed?)
6. Report:
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

   Recommendations:
     - Address M1 (old, may block shipping)
     - Close 3 items that are silently resolved
   ═══════════════════════════════
   ```
7. Offer to promote high-priority items to new sprints via `/harness:sprint`

Do NOT auto-fix. Present findings and ask the user which to address.
