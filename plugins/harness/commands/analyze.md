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

     **ADR matrix completeness check (v3.1+, WARNING).** For each ADR in
     architecture.md:

     - If the ADR has a `Considered options` field with only one option (or
       none), emit WARNING (NOT CRITICAL — preserves existing-project
       compatibility): "ADR-NNN has fewer than 2 considered options; v3.1+
       requires MADR matrix structure. Consider running `/harness:edit
       'restructure ADR-NNN to MADR format'` if this is a new sprint."
     - If the ADR has a `Pros and cons matrix` but missing the
       `Hallucination check` (Context7-verified alternatives), emit WARNING:
       "ADR-NNN matrix missing Context7-verification of non-chosen
       alternatives; alternatives may be hallucinated."

     These are WARNINGs not CRITICAL because they don't break the pipeline;
     they surface drift the user can choose to address via `/harness:edit`.
3. Write findings to `.harness/features/{current-feature}/analysis-report.md`. The report has two parts: a **coverage matrix** (per-requirement tables that make gaps visually loud) and a **summary block** (counts + CRITICAL/WARNING lists).

   ### Part A — Coverage matrix (SpecKit-inspired)

   The matrix makes drift a checkable claim, not a vibe. One row per FR, one row per AC. Empty/missing mappings render as literal `NO` (not blank), so gaps jump off the page. Add a `Finding` column that points to the numbered finding below when the row is problematic.

   ```markdown
   ## FR Coverage Matrix

   | FR    | In Architecture? | In Contract?  | Priority | Finding |
   |-------|------------------|---------------|----------|---------|
   | FR-01 | yes (§data-model) | yes (D-01)   | P0       | —       |
   | FR-02 | yes (§api)        | yes (D-02)   | P0       | —       |
   | FR-03 | NO                | yes (D-03)   | P0       | C1      |
   | FR-04 | yes (§ui)         | NO           | P1       | C2      |
   | FR-05 | yes (§cache)      | yes (D-05)   | P2       | W1      |

   ## AC Coverage Matrix

   | AC       | From FR | Test strategy in contract? | Testable? | Finding |
   |----------|---------|----------------------------|-----------|---------|
   | AC-01-1  | FR-01   | yes (vitest: happy path)   | yes       | —       |
   | AC-01-2  | FR-01   | yes (vitest: invalid input)| yes       | —       |
   | AC-02-1  | FR-02   | yes (playwright: flow)     | yes       | —       |
   | AC-03-1  | FR-03   | NO                         | —         | C1      |
   | AC-04-1  | FR-04   | yes (vitest)               | vague     | W2      |
   ```

   **Rendering rules:**
   - Every FR in `prd.md` MUST appear as a row. Every AC from every FR MUST appear as a row. No omissions — if it's in the PRD, it's in the matrix.
   - Missing mapping → literal `NO` (uppercase, no dash, no "N/A"). Weak/vague mapping → single word like `vague`, `partial`, or `weak`.
   - Finding column refers to the numbered findings below (C1, C2, W1, …). Rows with `—` in the Finding column are clean.
   - If the matrix exceeds 50 rows, emit the first 50 plus a footer: `… +N more FR rows omitted — see raw coverage data at <path>`. Token discipline per SpecKit `/analyze`.

   ### Part B — Summary + findings block

   Add the existing summary block AFTER the coverage matrix. Include the numbered findings the Finding column referenced.

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

   CRITICAL findings:
     C1: FR-03 missing from architecture + no test strategy
         → either add to architecture.md §data-model, or drop FR-03 from contract
     C2: FR-04 missing from contract deliverables
         → add deliverable D-04 mapping FR-04 to an implementation task

   WARNINGS:
     W1: FR-05 is P2 but appears in contract (contract should be P0/P1 only)
     W2: AC-04-1 test strategy is vague ("check form works") — tighten to observable behavior

   Remediation (optional):
     - [specific fix for finding 1]
     - [specific fix for finding 2]
   ═══════════════════════════════
   ```

   The matrix is the primary diagnostic artifact; the summary block is the orchestrator's decision input (counts + CRITICAL = halt).
4. **CRITICAL findings block progress** — the sprint cannot proceed until they're resolved (user can use [edit.md](edit.md) to fix, or manually edit)
5. **Warnings are informational** — sprint can proceed but user should know

**Constitutional violations are always CRITICAL** — from SpecKit: "The correct action is always to modify the plan or tasks to comply with the constitution, never to weaken or remove constitutional principles."

If run standalone (outside a sprint), use the currently active feature from `manifest.yaml`, or ask the user which feature to analyze.
