---
description: Verification debt scan — finds deferred issues, stale known-issues, silent skips, TODO/FIXME without owners across the harness state.
---

# `/harness:audit`

Invoke the BELCORT Harness skill and execute the **`/harness:audit`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:audit` section. Scan:
- `.harness/progress/known-issues.md` — flag entries older than 30 days with no activity
- `.harness/manifest.yaml` `verification_debt` — list deferred items and pending-human items
- Feature eval-reports — look for "deferred" / "skipped" / "known issue" mentions
- Source code — grep for `TODO` / `FIXME` without owners or dates

Produce a debt report grouped by severity:
- **BLOCKER**: things that should halt new sprints until resolved
- **SHOULD-FIX**: real issues but not blocking
- **INFO**: informational, tracked for visibility

Do NOT auto-fix. Present findings and ask the user which to address.
