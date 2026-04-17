---
description: Run the 14-point quality audit on existing .harness/spec/ and feature contract files. Surfaces missing sections, inconsistencies, and spec drift.
---

# `/harness:validate`

Invoke the BELCORT Harness skill and execute the **`/harness:validate`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:validate` section. Audit targets:
- `.harness/spec/constitution.md`
- `.harness/spec/prd.md`
- `.harness/spec/architecture.md`
- Each `.harness/features/*/contract.md` (if requested or all by default)

Produce a concise report: ✓ passed items, ✗ failed items with file:line references, and suggested fixes. Do NOT auto-fix — surface findings and let the user decide.
