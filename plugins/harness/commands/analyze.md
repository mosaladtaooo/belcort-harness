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

1a. **Criteria placeholder / unmodified-default check (FIX B2.2 — MANDATORY, halts on match)**

The Planner is supposed to customise `.harness/evaluator/criteria.md` for the project's type during Pass 2 (e.g., set `Project type: SaaS` and raise Product Depth threshold for frontend-heavy work). Real-use sprints have surfaced a failure mode where the Planner ships criteria.md with the literal placeholder text intact (e.g., `Project type: [fill in: SaaS / e-commerce ...]`) AND the per-criterion thresholds unchanged from the template. The Evaluator then grades against the generic defaults, the user assumes the rubric was tailored, and FAIL-worthy work passes with a 6-floor.

Run these checks against `.harness/evaluator/criteria.md`:

```bash
CRITERIA=".harness/evaluator/criteria.md"
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/evaluator/criteria.md.txt"

# A. Placeholder patterns — literal markers that should have been filled in
HITS=$(grep -nE '\[fill in:|\[TBD\]|\[describe[^]]*\]' "$CRITERIA" 2>/dev/null)
if [ -n "$HITS" ]; then
  echo "PLACEHOLDER_HITS:"
  echo "$HITS"
fi

# B. Threshold-default check — every threshold matches the template's default value
# AND no custom Weighting Decision line ("Project type: SOMETHING_REAL"). If both
# conditions hold, the Planner did not customise the rubric for this project.
PROJECT_TYPE_LINE=$(grep -n '^Project type:' "$CRITERIA" 2>/dev/null | head -1)
DEFAULTS_UNCHANGED=0
if [ -f "$TEMPLATE" ]; then
  # Compare just the threshold lines (lines starting with "- **<name>**: ").
  TPL_THRESH=$(grep -E '^\- \*\*(Functionality|Code Quality|Test Coverage|Product Depth)\*\*:' "$TEMPLATE")
  CUR_THRESH=$(grep -E '^\- \*\*(Functionality|Code Quality|Test Coverage|Product Depth)\*\*:' "$CRITERIA")
  if [ "$TPL_THRESH" = "$CUR_THRESH" ]; then
    DEFAULTS_UNCHANGED=1
  fi
fi
```

**Halt rules** (each is a CRITICAL finding; halt the analyze pipeline same as a constitutional violation):

- **Placeholder pattern detected** (`[fill in:` / `[TBD]` / `[describe ...]` regex hits anywhere in the file):
  > "criteria.md contains placeholder text — the Planner did not customise the rubric for this project. Run `/harness:clarify` or `/harness:amend "fill in evaluator criteria"` before proceeding. Matched lines:"
  >
  > followed by the line numbers + content from `$HITS`.

- **All thresholds match template defaults AND Project type still says `[fill in: ...]`** (or is missing entirely):
  > "criteria.md thresholds are all-default AND Project type is unset — the Planner did not customise the rubric for this project. Run `/harness:clarify` or `/harness:amend` to set Project type and adjust at least one threshold for this project's risk profile before proceeding."

Show the matched lines so the user can see WHICH placeholder fired. Don't auto-fix; the Planner is the canonical writer of spec files (per SKILL.md File Ownership Contract) — `/harness:analyze` only halts and surfaces.

If both checks pass (no placeholders AND at least one threshold differs from template OR Project type is set to something concrete), proceed to step 2.

2. Run these checks:
   - **Requirement coverage**: Every FR in the PRD appears in the architecture traceability table AND in the contract deliverables
   - **AC coverage**: Every AC in the PRD appears in the contract's test criteria
   - **NFR alignment**: Stack choices in architecture can realistically meet NFR metrics
   - **Constitution compliance**: Nothing in the plan violates a constitution principle
   - **Dependency ordering**: Contract's build order respects architectural dependencies
   - **Scope consistency**: Contract scope matches PRD priorities (no P2 features in a P0 contract)
   - **Tech stack conflicts**: No contradicting framework mentions across files
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
