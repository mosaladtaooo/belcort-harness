---
description: Run the 13-point quality audit on existing .harness/spec/ files (BMAD tri-modal). Surfaces missing sections, inconsistencies, and spec drift without regenerating anything.
---

# `/harness:validate` — Validate existing spec

For when you want to audit an existing PRD without regenerating it.

## Procedure

1. Read all `.harness/spec/` files
2. Run the Planner's 13-point validation checklist against them
3. Report findings:
   ```
   ═══════════════════════════════
     Harness — Spec Validation
   ═══════════════════════════════
   V1  Completeness:    PASS/FAIL  [details]
   V2  SMART NFRs:      PASS/FAIL  [details]
   V3  Traceability:    PASS/FAIL  [details]
   ...
   V13 Right-sized:     PASS/FAIL  [details]

   Result: [N]/13 passed
   Fix: [list of specific issues to address]
   ═══════════════════════════════
   ```
4. If issues found, offer to fix them in-place (user confirms per fix)
