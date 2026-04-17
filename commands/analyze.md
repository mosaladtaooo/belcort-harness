---
description: Cross-artifact consistency check — verifies PRD coverage, NFR alignment, constitution compliance across spec and feature contracts. Writes analysis-report.md.
---

# `/harness:analyze`

Invoke the BELCORT Harness skill and execute the **`/harness:analyze`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:analyze` section. Produces `.harness/features/<current>/analysis-report.md` with:
- Coverage: every PRD user journey maps to ≥1 FR; every FR maps to ≥1 contract deliverable
- NFR alignment: NFRs are addressed in architecture + contract
- Constitution compliance: no contract deliverable violates an enforceable rule
- Drift: contract and architecture are internally consistent

CRITICAL findings halt the pipeline. Warnings are surfaced but don't block.

If run standalone (outside a sprint), use the currently active feature from `manifest.yaml`, or ask the user which feature to analyze.
