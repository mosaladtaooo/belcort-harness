---
description: Run the 19-point quality audit on existing .harness/spec/ files (BMAD tri-modal). Surfaces missing sections, inconsistencies, and spec drift without regenerating anything.
---

# `/harness:validate` — Validate existing spec

For when you want to audit an existing PRD without regenerating it.

## Procedure

1. Read all `.harness/spec/` files
2. Run the Planner's 19-point validation checklist against them (V1–V18 + V8b — see `agents/planner.md` SELF-VALIDATION section)
3. Report findings:
   ```
   ═══════════════════════════════
     Harness — Spec Validation
   ═══════════════════════════════
   V1  Completeness:    PASS/FAIL  [details]
   V2  SMART NFRs:      PASS/FAIL  [details]
   V3  Traceability:    PASS/FAIL  [details]
   ...
   V18 Wording does work: PASS/FAIL  [details]

   Result: [N]/19 passed
   Fix: [list of specific issues to address]
   ═══════════════════════════════
   ```
4. If issues found, offer to fix them in-place via `/harness:edit` or `/harness:amend` (user confirms per fix). The orchestrator itself does NOT author the fixes — see [SKILL.md § File Ownership Contract](../skills/harness/SKILL.md).
