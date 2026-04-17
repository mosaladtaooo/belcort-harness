---
description: Cross-artifact consistency check (SpecKit-inspired) — verifies PRD coverage, NFR alignment, constitution compliance across spec and feature contracts. CRITICAL findings halt the pipeline; warnings pass through. Writes analysis-report.md.
---

# `/harness:analyze` — Cross-artifact consistency check

Runs AFTER the Planner completes and BEFORE the human approval gate. Catches misalignments between PRD, architecture, and contract before we waste the Generator's time building from a flawed spec.

**When it runs automatically:**
In the full [sprint.md](sprint.md) flow, `/harness:analyze` runs automatically between Planner completion and the human gate. It's transparent — findings are presented alongside the approval prompt.

**When to invoke manually:**
- After [edit.md](edit.md) modified a spec file (check nothing drifted)
- Before starting a complex sprint where confidence matters
- After importing a spec from elsewhere

## Procedure

1. Read `.harness/spec/prd.md`, `.harness/spec/architecture.md`, `.harness/spec/constitution.md`, `.harness/features/{current-feature}/contract.md`
2. Run these checks:
   - **Requirement coverage**: Every FR in the PRD appears in the architecture traceability table AND in the contract deliverables
   - **AC coverage**: Every AC in the PRD appears in the contract's test criteria
   - **NFR alignment**: Stack choices in architecture can realistically meet NFR metrics
   - **Constitution compliance**: Nothing in the plan violates a constitution principle
   - **Dependency ordering**: Contract's build order respects architectural dependencies
   - **Scope consistency**: Contract scope matches PRD priorities (no P2 features in a P0 contract)
   - **Tech stack conflicts**: No contradicting framework mentions across files
3. Write findings to `.harness/features/{current-feature}/analysis-report.md`:
   ```
   ═══════════════════════════════
     Harness — Cross-Artifact Analysis
   ═══════════════════════════════
   Requirement coverage:   [N]/[N] FRs mapped    ✓/✗
   AC coverage:            [N]/[N] ACs tested    ✓/✗
   NFR alignment:          [assessment]          ✓/✗/?
   Constitution:           [violations count]    ✓/✗
   Dependency ordering:    [issues count]        ✓/✗
   Scope consistency:      [issues]              ✓/✗

   CRITICAL findings: [list]
   WARNINGS: [list]

   Remediation (optional):
     - [specific fix for finding 1]
     - [specific fix for finding 2]
   ═══════════════════════════════
   ```
4. **CRITICAL findings block progress** — the sprint cannot proceed until they're resolved (user can use [edit.md](edit.md) to fix, or manually edit)
5. **Warnings are informational** — sprint can proceed but user should know

**Constitutional violations are always CRITICAL** — from SpecKit: "The correct action is always to modify the plan or tasks to comply with the constitution, never to weaken or remove constitutional principles."

If run standalone (outside a sprint), use the currently active feature from `manifest.yaml`, or ask the user which feature to analyze.
