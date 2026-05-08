# BELCORT Harness v3.0 Implementation Plan — Part 1 of 2 (Phase 1 — Verification)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This is Part 1 of 2.** Part 2 (`-part-2.md`) contains self-tests, audit scans, docs updates, canary, and release. Complete Part 1 before starting Part 2.

**Goal:** Add a SIMULATE mode to the Generator that drives the production-mode runtime + cumulative regression replay before Evaluator handoff, tighten the contract template with structured State-Transition + Negative-Path + UI-surface coverage, lighten the Evaluator's redundant prod-stack work, and apply a full audit pass to anything accreted since v2.3.0. Closes the runtime-verification gap that produced 8 demo-prep bugs in BELCORT ACC v2 feature-003.

**Architecture:** Three-agent topology preserved (Planner / Generator / Evaluator + file-based handoffs + fresh subagent contexts) per Anthropic's GAN insight. Generator gains a 4th MODE: SIMULATE, dispatched as a fresh `harness:generator` Agent-tool call after BUILD returns — *not* a 4th subagent. Sprint flow gains Step 3.5 between BUILD and EVALUATE. Cumulative regression accumulates in `tests/e2e/<NNN-feature-name>/journey.spec.ts` per-feature directories. Evaluator EVALUATE Step 2 lightens to read simulation-report.md as authoritative behavioural evidence + run a 15-min spot-check.

**Tech Stack:** Claude Code plugin (`.claude-plugin/plugin.json`), markdown agent prompts (`agents/*.md`), template `.txt` files, manifest YAML, prose command procedures (`commands/*.md`). Generator BUILD delegates TDD to `superpowers:test-driven-development`; Generator SIMULATE drives `pnpm build / start / worker` + Playwright MCP + DB queries via Bash. Evaluator drives Playwright MCP for spot-checks + git-archaeology grep scans.

**Spec reference:** `docs/superpowers/specs/2026-05-07-belcort-v3-runtime-verification-and-audit-design.md` — every task in this plan implements a section of that spec. Read § 4 (architectural decisions) before starting; refer to § 5 for per-change rationale; § 6 for audit-scan decision criteria.

---

## File Structure

### New files

| Path | Purpose |
|---|---|
| `plugins/harness/templates/features/simulation-report.md.txt` | Generator SIMULATE output template — per-FR verification rows + per-state-transition rows + per-negative-path rows + cumulative regression list + cross-runtime parity finding (per spec § 5 C1) |

### Modified files (Phase 1 — this plan)

| Path | Modifications |
|---|---|
| `plugins/harness/templates/features/contract.md.txt` | Two new mandatory sections (State-Transition ACs + Negative-Path Coverage); FR-section schema clause for UI-surface AC |
| `plugins/harness/templates/spec/constitution.md.txt` | New §N MUST principle on error-surfacing / catch-block ban |
| `plugins/harness/templates/manifest.yaml` | `state.phase` enum gains `simulating` value |
| `plugins/harness/agents/planner.md` | Pass 2 gains State-Transition + Negative-Path population, UI-surface AC requirement, brainstorming-pass-over-UJ step; 16-point self-validation expands to 18-point with V17 + V18 |
| `plugins/harness/agents/generator.md` | +~250 lines new MODE: SIMULATE section after MODE: BUILD; mode-routing table grows from 3 to 4 rows; NEGOTIATE prose updated to populate new contract table test-name columns; FINALIZE-CONTRACT preserves new tables |
| `plugins/harness/agents/evaluator.md` | REVIEW-PROPOSAL Step 5 expands to verify State-Transition + Negative-Path + UI-surface coverage; EVALUATE Part A gates on table rows; EVALUATE Step 2 lightens (~−80 LoC net); Step 3 gains catch-block grep procedure; reads simulation-report.md as authoritative behavioural evidence |
| `plugins/harness/commands/sprint.md` | New Step 3.5 (Simulate) inserted between Step 3 (BUILD) and Step 4 (EVALUATE) |
| `plugins/harness/commands/resume.md` | New phase recovery branch for `simulating` |
| `plugins/harness/commands/rewind.md` | `simulating` as valid rewind target |
| `plugins/harness/skills/harness/SKILL.md` | Mode-routing table updated; new ownership rows; flow diagram updated to insert SIMULATE phase; Pipeline Timing table gains row |

### Modified files (Phase 2-5 — see Part 2 of plan)

Audit scan modifications, doc updates, hooks, and release activities live in Part 2 (`-part-2.md`). Do NOT start them until Part 1 self-tests have been planned (Part 2 § Phase 1 Self-tests).

---

## Phase 1 — Verification gap implementation

Implementation order: **C2 → C3 → C4 → C5 → C1 → C6 → C7** per spec § 7. Within each C-cluster, tasks decompose into commit-sized units.

---

### Task 1: Add State-Transition AC + Negative-Path Coverage table sections to contract template (C2.a)

**Files:** Modify `plugins/harness/templates/features/contract.md.txt`

- [ ] **Step 1: Read the current template, locate insertion point (after `## NFRs to Verify`, before `## Definition of Done`)**

- [ ] **Step 2: Insert State-Transition ACs section**

```markdown
## State-Transition ACs

For every state field in the data model that this feature mutates, list each
transition and its corresponding observable Playwright test. Planner Pass 2
populates `Entity.Field` / `From` / `To` / `Triggered by` from architecture's
data model; Generator NEGOTIATE populates `Playwright test name`; Evaluator
REVIEW-PROPOSAL Step 5 rejects `agreed` if any row blank; SIMULATE Step 3
drives each row; Evaluator Part A refuses Met without one passing named test
per row.

| Entity.Field | From | To | Triggered by | Playwright test name |
|--------------|------|-----|--------------|----------------------|
| <example: documents.status> | received | extracting | worker pickup | `tests/e2e/<NNN-feature>/journey.spec.ts > test('worker picks up doc')` |

If this feature mutates no state fields, write: `_None — this feature does
not mutate any state field._` and explain why in one line.
```

- [ ] **Step 3: Insert Negative-Path Coverage section immediately after**

```markdown
## Negative-Path Coverage

For each unique constraint, foreign-key constraint, or check constraint in
the data model that this feature exercises. Same ownership pattern: Planner
populates `Constraint` / `Trigger scenario` / `Expected error`; Generator
NEGOTIATE populates `Recovery test`; SIMULATE Step 4 drives + verifies
recovery; Evaluator Part A gates on test presence + passing.

| Constraint | Trigger scenario | Expected error | Recovery test |
|------------|------------------|----------------|---------------|
| <example: documents_unique(firm_id, sha256)> | re-upload same file | "duplicate document" | `tests/e2e/<NNN-feature>/journey.spec.ts > test('duplicate upload recovers')` |

If this feature exercises no constraints, write: `_None — this feature
does not interact with any constraints._` and explain why.
```

- [ ] **Step 4: Verify with Grep — exactly two new headers (`^## State-Transition ACs$` + `^## Negative-Path Coverage$`)**

- [ ] **Step 5: Commit**

```
git add plugins/harness/templates/features/contract.md.txt
git commit -m "feat(v3.0/C2): add State-Transition + Negative-Path tables to contract template"
```

---

### Task 2: Add UI-surface AC clause to contract template FR-section schema (C3.a)

**Files:** Modify `plugins/harness/templates/features/contract.md.txt`

- [ ] **Step 1: Locate the FR-section schema annotation block (under "## Test Criteria" or equivalent)**

- [ ] **Step 2: Add UI-surface AC clause to the FR-section template**

```markdown
**For any FR that mutates a `status` / `state` / `phase` field on any entity:**
A UI-surface AC is REQUIRED. Format:

- AC-NNN-ui: User can see <field-value-transformation> on `<route>` via
  selector `<selector>`. Asserted by Playwright test
  `tests/e2e/<NNN-feature>/journey.spec.ts > test('<name>')`.

Required components: route, DOM selector, value transformation, test name.

Heuristic: user-observable lifecycle stages need UI surface; internal/admin-only
stages don't. If unsure, declare the AC; if the user really shouldn't see it,
the Planner adds a `## UI-Surface Excluded` note with rationale below the FR.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/templates/features/contract.md.txt
git commit -m "feat(v3.0/C3): add UI-surface AC clause to contract template FR-section schema"
```

---

### Task 3: Update Planner Pass 2 to populate State-Transition + Negative-Path tables (C2.b)

**Files:** Modify `plugins/harness/agents/planner.md`

- [ ] **Step 1: Locate Pass 2 contract-emission step (currently around "Define test criteria")**

- [ ] **Step 2: Add State-Transition + Negative-Path population sub-steps**

```markdown
**Sub-step X.1: Populate State-Transition AC table (v3.0)**

Read `architecture.md`'s data model section. For every entity with a
`status` / `state` / `phase` field, enumerate every transition this feature
triggers. For each transition, write one row in the contract's
`## State-Transition ACs` table with:

- `Entity.Field` — e.g., `documents.status`
- `From` — state before this transition
- `To` — state after this transition
- `Triggered by` — action / event causing the transition
- `Playwright test name` — leave BLANK; Generator NEGOTIATE fills this

If feature mutates no state fields, write: `_None — this feature does not
mutate any state field._`

**Sub-step X.2: Populate Negative-Path Coverage table (v3.0)**

Read architecture's data model constraints (UNIQUE, FOREIGN KEY, CHECK).
For each constraint this feature exercises, write one row with:

- `Constraint` — e.g., `documents_unique(firm_id, sha256)`
- `Trigger scenario` — what user action would violate the constraint
- `Expected error` — what user-visible error message / code
- `Recovery test` — leave BLANK; Generator NEGOTIATE fills this

If feature exercises no constraints, write: `_None — this feature does not
interact with any constraints._`
```

- [ ] **Step 3: Add V17 to self-validation checklist**

```markdown
- [ ] V17: For every entity in `architecture.md` with a status/state/phase
      field, the contract has at least one State-Transition AC row covering
      a transition this feature triggers, OR the contract explicitly states
      `_None — this feature does not mutate any state field._`. Same check
      for Negative-Path Coverage against architecture constraints.
```

- [ ] **Step 4: Update self-validation header to "17-point" (becomes 18 in Task 5)**

- [ ] **Step 5: Commit**

```
git add plugins/harness/agents/planner.md
git commit -m "feat(v3.0/C2): Planner Pass 2 populates State-Transition + Negative-Path tables; V17 self-validation"
```

---

### Task 4: Update Planner Pass 2 to enforce UI-surface AC for status/state/phase fields (C3.b)

**Files:** Modify `plugins/harness/agents/planner.md`

- [ ] **Step 1: Locate FR-emission step in Pass 2**

- [ ] **Step 2: Add UI-surface AC requirement**

```markdown
**Sub-step Y: UI-surface AC for status / state / phase fields (v3.0)**

For each FR whose ACs mutate a `status` / `state` / `phase` field, you MUST
emit a UI-surface AC. Format:

- AC-NNN-ui: User can see <field-value-transformation> on `<route>` via
  selector `<selector>`. Asserted by Playwright test
  `tests/e2e/<NNN-feature>/journey.spec.ts > test('<name>')`.

Required components: route, DOM selector, value transformation, test name.

Heuristic: user-observable lifecycle stages need UI; internal/admin-only
don't. If unsure, declare the AC.

If `architecture.md` declares no UI surface (e.g., headless service, CLI
tool), skip this requirement; add `## UI-Surface Excluded — non-UI feature`
note to prd.md.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/planner.md
git commit -m "feat(v3.0/C3): Planner Pass 2 emits UI-surface AC for status/state/phase fields"
```

---

### Task 5: Add Pass 2 brainstorming pass over user-journey ACs (C4)

**Files:** Modify `plugins/harness/agents/planner.md`

- [ ] **Step 1: Locate end of Pass 2, just before self-validation checklist**

- [ ] **Step 2: Add brainstorming-pass step**

```markdown
**Sub-step Z: User-Journey UI-Surface Brainstorming Pass (v3.0)**

For each UJ-NNN you defined in Pass 1, ask yourself:

> "When the system performs each step of this journey successfully, what
> does the user see? Where? Through what selector?"

For each "user can't see this" finding:
- Add a UI-surface AC per Sub-step Y, OR
- Use AskUserQuestions to escalate (the user may want to defer the UI to a
  later feature)

Append findings to `prd.md` under a new `## UI-Surface Audit` section as a
per-journey list:

```markdown
## UI-Surface Audit

### UJ-001 — User uploads a document
- Step 1: User selects file → observable: file name appears in upload
  list → route `/dashboard/upload` → selector `[data-testid="upload-list"]`
- Step 2: System extracts → observable: status badge changes from
  'received' to 'extracted' → route `/dashboard/documents/:id` →
  selector `[data-testid="status-badge"]`
- Step 3: User reviews extracted fields → observable: form fields
  pre-populated → route `/dashboard/documents/:id/review`
```

If `architecture.md` declares no UI surface, skip this sub-step entirely
and add `## UI-Surface Audit: N/A — non-UI feature` to prd.md.
```

- [ ] **Step 3: Add V18 to self-validation checklist**

```markdown
- [ ] V18: Every UJ has every step covered by an observable
      user-state-change OR a deliberate `## UI-Surface Excluded` note in
      prd.md, OR `architecture.md` declares no UI surface and prd.md says
      `## UI-Surface Audit: N/A — non-UI feature`.
```

- [ ] **Step 4: Update self-validation header to "18-point"**

- [ ] **Step 5: Commit**

```
git add plugins/harness/agents/planner.md
git commit -m "feat(v3.0/C4): Planner Pass 2 brainstorming pass + V18 UI-Surface Audit self-validation"
```

---

### Task 6: Add catch-block ban principle to constitution template (C5.a)

**Files:** Modify `plugins/harness/templates/spec/constitution.md.txt`

- [ ] **Step 1: Find the highest existing principle number — call it §M; new principle is §(M+1)**

- [ ] **Step 2: Append new MUST principle**

```markdown
### §<M+1> — Errors at boundaries MUST be surfaced or explicitly logged.

**Forbidden patterns in `src/` (NOT test code):**

- Empty catch:                `try { ... } catch {}`
- Empty body with named error: `try { ... } catch (e) {}`
- Catch without re-throw, log, or explicit error return:
  `try { ... } catch (e) { /* ... */ }` with no `throw`,
  `console.error`, `logger.*`, or `return Error` / `Result.err`

**Exception:** tests may use empty catch when the exception is the
assertion (e.g., `expect(() => fn()).toThrow()`). Source code may not.

**Rationale:** silent error swallowing creates ghost-state bugs the
Evaluator's black-box testing cannot detect. The Bug #6 class
(authentication catch swallowing → null user → "feature works unless
you've signed out") is the canonical instance.

**Override path:** if a project's framework genuinely requires silent
catches, the Planner may modify or strike this principle during
constitution drafting in Pass 1. Once shipped (post-init), only
`/harness:constitution-amend` can change it.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/templates/spec/constitution.md.txt
git commit -m "feat(v3.0/C5): add catch-block ban as new MUST principle in canonical constitution template"
```

---

### Task 7: Add catch-block grep procedure to Evaluator EVALUATE Step 3 (C5.b)

**Files:** Modify `plugins/harness/agents/evaluator.md`

- [ ] **Step 1: Locate `### Step 3: Code Quality Review` within MODE: EVALUATE**

- [ ] **Step 2: Add grep procedure after existing constitution-violation greps**

```markdown
**Catch-block ban scan (v3.0+):** if the project constitution includes the
"Errors at boundaries MUST be surfaced or explicitly logged" principle
(check `.harness/spec/constitution.md` for the matching §-text or trigger
keyword "catch-block ban"), run:

```bash
# Multiline-aware catch-block scan
grep -rn -P -E 'catch\s*(\([^)]*\))?\s*\{[\s\S]*?\}' src/ 2>/dev/null \
  | grep -E '\{\s*\}|\{\s*//[^\n]*\s*\}' | head -20
```

Each match → CRITICAL finding under Code Quality, unless match is in test
code AND surrounding context (3 lines before / 3 after) shows the catch is
intentional (asserting a `toThrow()`).

If multiline grep produces too many false positives, fall back to simpler
single-line version (documented as less precise):

```bash
grep -rn -E 'catch\s*\{[^}]*\}|catch\s*\(.*\)\s*\{\s*\}' src/ 2>/dev/null
```

Document false positives in eval-report under `## Reward-Hacking Findings`.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/evaluator.md
git commit -m "feat(v3.0/C5): Evaluator EVALUATE Step 3 grep scan for catch-block ban"
```

---

### Task 8: Update Generator NEGOTIATE mode to populate test-name columns (C2.c)

**Files:** Modify `plugins/harness/agents/generator.md`

- [ ] **Step 1: Locate `## MODE: NEGOTIATE` → Workflow → Step 3 (Write the proposal)**

- [ ] **Step 2: Add the test-name population substep**

```markdown
**Populate State-Transition + Negative-Path test names (v3.0).** The
Planner's draft contract emits `## State-Transition ACs` and
`## Negative-Path Coverage` tables with the `Playwright test name` column
blank. As part of your proposal, fill that column with the test file paths
+ test names that you commit to writing during BUILD.

Format: `tests/e2e/<NNN-feature-name>/journey.spec.ts > test('<name>')`.

Constraints:
- Path uses the per-feature directory (e.g., `tests/e2e/001-foundation-and-ingestion/`)
- Each row's test name unique within the file
- Each State-Transition row's test must drive the trigger AND assert both
  the UI state change AND the DB state change
- Each Negative-Path row's test must trigger the constraint AND assert the
  recovery flow

If you cannot commit to a test name (trigger unclear or out of scope), flag
it under `## Risk Flags` in the proposal — Evaluator will surface in REVIEW.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/generator.md
git commit -m "feat(v3.0/C2): Generator NEGOTIATE populates State-Transition + Negative-Path test names"
```

---

### Task 9: Update Generator FINALIZE-CONTRACT to preserve new tables (C2.d)

**Files:** Modify `plugins/harness/agents/generator.md`

- [ ] **Step 1: Locate `## MODE: FINALIZE-CONTRACT` → "Invariants the pipeline depends on"**

- [ ] **Step 2: Append invariant bullet**

```markdown
- State-Transition ACs and Negative-Path Coverage tables — both must be
  present in the final contract, with all `Playwright test name` /
  `Recovery test` columns populated (no blanks). If any row was added during
  negotiation by Evaluator's REVIEW, it appears in the final contract too —
  don't drop rows.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/generator.md
git commit -m "feat(v3.0/C2): Generator FINALIZE-CONTRACT preserves State-Transition + Negative-Path tables"
```

---

### Task 10: Update Evaluator REVIEW-PROPOSAL Step 5 to verify new contract tables (C2.e + C3.c)

**Files:** Modify `plugins/harness/agents/evaluator.md`

- [ ] **Step 1: Locate `## MODE: REVIEW-PROPOSAL` → Workflow → Step 5**

- [ ] **Step 2: Add three verification sub-steps**

```markdown
**State-Transition AC table verification (v3.0).** Read contract's
`## State-Transition ACs` table. Verify:

- For each entity in `architecture.md` with a status/state/phase field, the
  contract has at least one State-Transition row OR contract explicitly says
  `_None — this feature does not mutate any state field._`
- Every row has a non-blank `Playwright test name` column. Blank → `R-NN:
  state transition <Entity.Field: From → To> has no test name committed`.
- Every test name follows the `tests/e2e/<NNN-feature>/journey.spec.ts >
  test('<name>')` pattern.

**Negative-Path Coverage verification (v3.0).** Same pattern for
`## Negative-Path Coverage`:
- Each architecture constraint covered, OR contract says `_None_`.
- Every row has a non-blank `Recovery test` column.
- Test name format matches.

**UI-surface AC verification (v3.0).** For each FR mutating a
status/state/phase field (search FRs for ACs implying state mutation),
verify a `AC-NNN-ui` AC exists with route + selector + value transformation
+ test name. Missing UI-surface AC → R-NN flag, UNLESS architecture declares
no UI surface (in which case prd.md's `## UI-Surface Audit` says `N/A —
non-UI feature`).

Reject `agreed` if any R-NN flag from these checks remains unaddressed
after Round 2. Acceptance of blanks here causes Bug #4 / #7 / #8 class
failures downstream.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/evaluator.md
git commit -m "feat(v3.0/C2+C3): Evaluator REVIEW-PROPOSAL Step 5 verifies State-Transition + Negative-Path + UI-surface coverage"
```

---

### Task 11: Update Evaluator EVALUATE Part A to gate on State-Transition + Negative-Path table rows (C2.f)

**Files:** Modify `plugins/harness/agents/evaluator.md`

- [ ] **Step 1: Locate `### Step 6: Two-stage grading` → `#### PART A — Contract Compliance (binary)`**

- [ ] **Step 2: Add table-row gating after existing FR / AC binary tables**

```markdown
**State-Transition row check (v3.0).** Read contract's `## State-Transition
ACs` table. For each row, run the named Playwright test and check the
SIMULATE simulation-report.md verdict for that row. Render as:

| State Transition | Triggered by | Test name | Verdict |
|------------------|-------------|-----------|---------|
| documents.received → extracting | worker pickup | `worker-picks-up.spec.ts` | ✅ Verified |
| documents.extracting → extracted | extraction complete | `extraction-completes.spec.ts` | ❌ Test failed |

Any row with verdict `❌ Test failed` or `⚠️ Partial` triggers Part A FAIL
for the parent FR — same gating rule as the FR-level check.

**Negative-Path row check (v3.0).** Same pattern for `## Negative-Path
Coverage`. Render and gate identically.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/evaluator.md
git commit -m "feat(v3.0/C2): Evaluator EVALUATE Part A gates on State-Transition + Negative-Path rows"
```

---

### Task 12: Create simulation-report.md template (C1.a)

**Files:** Create `plugins/harness/templates/features/simulation-report.md.txt`

- [ ] **Step 1: Write template content**

```markdown
# Simulation Report — features/<FEATURE>

**Date**: <ISO date>
**Generator (SIMULATE)**: <agent run ID>
**Verdict**: VERIFIED | NEEDS-REPAIR

This file is the authoritative behavioural-evidence handoff from Generator
SIMULATE to Evaluator EVALUATE. Do NOT edit after the Generator writes it.

---

## Summary

- Feature: features/<FEATURE>
- Total state-transition rows: N (verified: M, partial: P, cannot-verify: Q)
- Total negative-path rows: N (verified: M, partial: P, cannot-verify: Q)
- Cumulative regression: N prior features replayed (passed: M, failed: P)
- Cross-runtime parity: <none / minor / CRITICAL>

---

## Per-FR verification

| FR | Verdict | Test driving | Evidence |
|----|---------|-------------|----------|
| FR-001 | ✅ Verified | `worker-picks-up.spec.ts` | screenshot: `<path>`, DB: `<query result>` |
| FR-002 | ⚠️ Partial-runtime-gap | `extraction-completes.spec.ts` | UI shows "extracted" but DB still shows "received" |
| FR-003 | ❌ Cannot-verify | (test missing) | Generator NEGOTIATE committed to test name but BUILD did not write it |

---

## Per-state-transition verification

| Entity.Field | From | To | Test name | DB confirmed | UI confirmed |
|--------------|------|-----|-----------|--------------|--------------|
| documents.status | received | extracting | `worker-picks-up.spec.ts` | ✅ | ✅ |
| documents.status | extracting | extracted | `extraction-completes.spec.ts` | ❌ stayed at 'extracting' | ✅ shows 'Extracted' |

---

## Per-negative-path verification

| Constraint | Trigger | Expected error | Recovery test | Error shown? | Recovery works? |
|------------|---------|---------------|---------------|--------------|-----------------|
| documents_unique(firm_id, sha256) | re-upload same file | "duplicate" | `duplicate-upload.spec.ts` | ✅ | ✅ |

---

## Cumulative regression

| Feature | Journey test | Verdict | Notes |
|---------|--------------|---------|-------|
| 001-foundation | `tests/e2e/001-foundation/journey.spec.ts` | ✅ pass | |
| 002-ingestion | `tests/e2e/002-ingestion/journey.spec.ts` | ❌ fail | review-queue did not filter approved docs |

---

## Cross-runtime parity

<none / brief description if found>

Example finding format:

> Bug class: stack-walker behaves differently under `tsx` worker vs Vitest.
> The `__getUnscopedDb` utility reads `Error().stack` to find caller path;
> works in dev (Turbopack) but fails in prod (`tsx` serves a different
> stack format). File: `src/lib/db/scope.ts:42`.

---

## Resource Warnings

<emit only if turn count > 800 or token usage > 700K mid-dispatch>

> Warning: turn count <N> / token usage <N> exceeded threshold during
> cumulative regression replay. Cumulative regression suite is large
> (<M> features). Consider promoting parallel-dispatch (ROADMAP v3 item 1)
> or feature-window cap to v3.1.

---

## Setup observations

<any infrastructure issues encountered, e.g., port conflicts, missing env,
db migration needed>
```

- [ ] **Step 2: Commit**

```
git add plugins/harness/templates/features/simulation-report.md.txt
git commit -m "feat(v3.0/C1): create simulation-report.md.txt template"
```

---

### Task 13: Update Generator mode-routing table from 3 to 4 rows + frontmatter description (C1.b)

**Files:** Modify `plugins/harness/agents/generator.md`

- [ ] **Step 1: Update frontmatter `description:` field**

```yaml
description: BELCORT Generator subagent. Implements the negotiated contract via TDD (delegates the RED→GREEN→REFACTOR cycle to `superpowers:test-driven-development`). Four modes via `--- MODE: X ---` marker — NEGOTIATE (propose HOW, no code), FINALIZE-CONTRACT (merge proposal+review into final contract), BUILD (atomic per-FR commits + changelog append), SIMULATE (drive prod-mode runtime + cumulative regression replay before Evaluator handoff). Dispatched by `/harness:sprint`, `/harness:quick`. Enforces reward-hacking prohibitions.
```

- [ ] **Step 2: Append SIMULATE row to mode-routing table**

```markdown
| **SIMULATE** | Drive prod-mode runtime + cumulative regression replay; verify per-FR + per-transition + per-negative-path behaviour against the running production build before Evaluator handoff | `simulation-report.md` | final contract, implementation-report.md, proposal.md, prd.md, prior features' journey tests, manifest.yaml | Yes — reads source, runs prod stack, drives Playwright, queries DB. NO new code. |
```

- [ ] **Step 3: Update default-mode line — SIMULATE never defaults; must be explicitly dispatched**

- [ ] **Step 4: Commit**

```
git add plugins/harness/agents/generator.md
git commit -m "feat(v3.0/C1): Generator mode-routing table grows to 4 rows including SIMULATE"
```

---

### Task 14: Add the full MODE: SIMULATE prompt section to generator.md (C1.c) — KEYSTONE

**Files:** Modify `plugins/harness/agents/generator.md`

This is the largest single content addition in v3.0 (~250 lines). Add AFTER `## MODE: BUILD` section's closing paragraph and BEFORE the file-level `## BEHAVIORAL RULES` section.

- [ ] **Step 1: Insert the full MODE: SIMULATE section**

```markdown
---

## MODE: SIMULATE

Generator BUILD has completed. The implementation-report.md is written; the
test suite passes at the unit level; per-FR atomic commits are on the build
branch. Now you drive the production-mode runtime against the contract's
State-Transition AC + Negative-Path Coverage tables, replay every prior
shipped feature's journey test cumulatively, and produce
`simulation-report.md` as authoritative behavioural evidence for the
Evaluator.

**You do NOT write source code in this mode.** You may write Playwright
tests if Generator BUILD missed any test that was committed to in the
contract — but only as a corrective gap-fill, with explicit notation in the
simulation-report. Code changes belong in BUILD; if SIMULATE detects a
code-level gap, it produces NEEDS-REPAIR verdict and exits without fixing —
the orchestrator surfaces this to the Evaluator (which will Part A FAIL),
and the standard retry loop dispatches BUILD again.

### Why this mode exists

Anthropic's verification triad recommends three approaches: rules-based
(unit tests + linters), visual / interactive (Playwright against the
running app), and LLM-as-judge (the Evaluator). Pre-v3.0, the Generator
covered the unit-test layer and the Evaluator covered the LLM-as-judge
layer; the visual / interactive layer was nominally with the Evaluator but
ran in dev mode (Turbopack), against the same artifact the Generator just
tested. Bugs that only fire under the production runtime (stack-walker
diffs, real worker process, real DB transactions) bypassed every gate.
SIMULATE closes this leg by running the production stack — the same one
end-users see — and observing per-state-transition behaviour through real
browser interactions backed by direct DB-state queries.

### Input

You receive (read via Read tool from project-root `.harness/`, NOT from
`.worktrees/current/.harness/` per the Working-Directory Contract):

- `.harness/features/${FEATURE}/contract.md` — final negotiated contract,
  with State-Transition ACs + Negative-Path Coverage tables populated by
  Planner Pass 2 + Generator NEGOTIATE
- `.harness/features/${FEATURE}/implementation-report.md` — Generator
  BUILD's handoff; the FR → file map tells you what to expect
- `.harness/features/${FEATURE}/proposal.md` — committed HOW from
  negotiation, for cross-reference
- `.harness/spec/prd.md` — § "User Journeys" + § "UI-Surface Audit" if
  present (Planner Pass 2 brainstorming-pass output)
- `.harness/manifest.yaml` → `features.completed[]` — list of prior shipped
  features whose journey tests must be cumulatively replayed

The current feature folder name lives in `.harness/manifest.yaml` under
`state.current_feature`.

### Tools

- **Bash** — run `pnpm build`, `pnpm start`, `pnpm worker`, `psql`, `npx
  playwright test`, kill background processes. Use `run_in_background:
  true` for long-running servers.
- **Playwright MCP** — drive the running app through user flows; screenshot
  at state-transition boundaries.
- **Read / Write** — read context files; write `simulation-report.md`. Do
  not write source code.

### Workflow (7 steps)

#### Step 1: Setup

Read inputs (per § Input). Verify these halt-gates:

- `contract.md` contains `**Negotiated**:` marker — same gate the Evaluator
  enforces. If absent, contract is still a draft; emit CRITICAL halt to
  simulation-report.md and exit. SIMULATE cannot proceed against a draft.
- `tests/e2e/<NNN-feature-name>/journey.spec.ts` exists. Generator BUILD
  was supposed to write the journey tests as TDD outputs (one test per
  State-Transition / Negative-Path row committed in the contract's tables).
  If absent or empty, the build did not honor its negotiation commitment —
  emit CRITICAL gap per FR; verdict NEEDS-REPAIR.

Then run `bash .harness/init.sh` to verify project health. If init.sh
fails (env missing, build broken before SIMULATE even runs), emit CRITICAL
halt and exit. The Evaluator will surface to user via the Setup-required
gate (sprint.md Step 4a).

#### Step 2: Start production stack

Read `package.json` to discover build / start / worker scripts (do NOT
assume — projects vary). Common patterns:

```json
{
  "scripts": {
    "build": "next build",
    "start": "next start",
    "worker": "tsx scripts/worker.ts",
    "db:reset": "drizzle-kit drop && drizzle-kit push",
    "db:migrate": "drizzle-kit migrate"
  }
}
```

Then:

1. Migrate fresh test DB if applicable. Use project's reset / migrate
   scripts. If no DB or no migrations, skip.
2. `pnpm build` — wait for completion. If non-zero exit, write `## Build
   failure` section to simulation-report.md, set verdict NEEDS-REPAIR, exit.
3. `pnpm start` — run via Bash with `run_in_background: true`. Capture PID
   for tear-down in Step 7.
4. `pnpm worker` — IF `package.json` has a worker script. Same background
   pattern. Capture PID.
5. Wait for servers to bind. Use Playwright MCP `playwright_navigate` with
   retry; treat 30s timeout as `## Infrastructure failure` in
   simulation-report.md.

#### Step 3: Drive State-Transition AC rows

Read `## State-Transition ACs` table from contract.md. For each row:

a. Drive the user flow that triggers the transition. Use Playwright MCP:
   `playwright_navigate` → `playwright_click` / `playwright_fill` →
   `playwright_screenshot` at each state-transition boundary.

b. Query DB after each transition to confirm DB state matches UI. Use
   `psql ${DB_URL} -c 'SELECT <field> FROM <table> WHERE id=...'`.
   Expected: the `To` value from the table's row.

c. Record per-row in simulation-report.md's per-state-transition section:
   - DB confirmed: ✅ / ❌ stayed at '<actual value>'
   - UI confirmed: ✅ / ❌ '<actual UI text>'
   - Screenshot path

#### Step 4: Drive Negative-Path Coverage rows

Read `## Negative-Path Coverage` table. For each row:

a. Trigger the constraint violation (e.g., re-upload a duplicate file).
b. Confirm expected error appears in UI.
c. Confirm DB state is recovered (no transaction abort, no orphan rows,
   no stuck transactions). Query specific tables to verify.

Record per-row:
- Error shown? ✅ / ❌
- Recovery works? ✅ / ❌

#### Step 5: Cumulative regression replay

Read `manifest.yaml → features.completed[]`. For each prior shipped
feature, the corresponding journey test lives at `tests/e2e/<NNN-feature-name>/journey.spec.ts`.

Run `npx playwright test tests/e2e/` against the running production stack.
Each prior feature's journey runs as a regression test.

Record per-prior-feature in cumulative regression section:
- Verdict: ✅ pass / ❌ fail (with brief failure description)
- Test name(s) that failed

A failure here is a MAJOR finding ("regression caused by current feature
changes"), but does NOT directly trigger NEEDS-REPAIR — goes to Evaluator's
reward-hacking section and user decides via the human gate.

#### Step 6: Cross-runtime parity quick-check (5-min cap)

This step folds in source-report action [5]. If the implementation uses
utilities that read stack traces (`Error().stack`), filenames
(`__filename`, `import.meta.url`), or import-time-only data, the same code
may behave differently under dev (Turbopack / ESM) vs prod (`tsx` /
CommonJS / standalone bundle).

Heuristic for "specific suspicion":
- implementation-report or contract mentions `__getUnscopedDb`-class
  utilities, or
- A worker process exists and the worker imports utilities the web app
  also imports, or
- architecture's stack table mentions tsx + Turbopack together.

If no specific suspicion: skip (write `## Cross-runtime parity: skipped —
no stack-walking utilities detected`).

If suspicion: write a focused Playwright test that exercises the suspicious
code path against prod runtime + worker. If results diverge from unit
tests' results, write the finding under `## Cross-runtime parity` with
file location + diff description.

Time-box: 5 minutes. If you exceed, emit `## Cross-runtime parity: deferred
— investigation exceeded time budget`. Acceptable; not a NEEDS-REPAIR
trigger by itself.

#### Step 7: Write simulation-report.md and tear down

Write `.harness/features/${FEATURE}/simulation-report.md` per template at
`@templates/features/simulation-report.md.txt`. Required header:

```
**Verdict**: VERIFIED | NEEDS-REPAIR
```

Verdict computation:
- VERIFIED if every per-FR row is ✅, every state-transition row is ✅ /
  ✅, every negative-path row is ✅ / ✅, and no CRITICAL cross-runtime
  parity findings.
- NEEDS-REPAIR otherwise.

Tear down:
- Kill background `pnpm start` PID (`kill <PID>` or via Playwright MCP
  cleanup)
- Kill background `pnpm worker` PID
- (Test DB cleanup is project's responsibility — do not assume.)

If tear-down fails, log to `.harness/progress/changelog.md` under
`## SIMULATE tear-down warning` and continue. Next SIMULATE will re-spin
clean.

### Anti-patterns in SIMULATE mode

- **Treating SIMULATE as a code-fix loop.** You do NOT modify source code
  in this mode. If you find a code-level bug (stub, missing implementation,
  wrong logic), record it as ⚠️ Partial-runtime-gap or ❌ Cannot-verify and
  let the Evaluator's Part A FAIL trigger the standard retry loop (which
  dispatches BUILD, not SIMULATE again).
- **Skipping rows because they look hard.** Every row in the contract's
  tables MUST appear in your simulation-report. If a test is missing
  (BUILD didn't write it), record ❌ Cannot-verify with explicit reason.
  Don't silently drop.
- **Replaying cumulative regression at the unit-test layer.** Cumulative
  regression replay is `npx playwright test tests/e2e/`, not `npx vitest
  run`. Prior features' journey tests are e2e by design.
- **Running in dev mode.** SIMULATE is exactly the gate that prevents this.
  If `pnpm build` or `pnpm start` fails and you fall back to `pnpm dev`,
  you reproduce the v2.x bug. STOP — write `## Build failure` and exit.
- **Inferring a "specific suspicion" without evidence.** Step 6's
  cross-runtime parity is gated on heuristic. If hand-wringing about
  whether to run it, you don't have specific suspicion — skip and document.

### Behavioral rules in SIMULATE mode

1. **Read context first.** Loading State-Transition + Negative-Path tables
   determines what you drive. Without them, you cannot produce meaningful
   behavioural evidence.
2. **One observation per row.** Don't conflate multiple state transitions
   into a single Playwright test description; each row gets its own
   evidence trail.
3. **Tear down the prod stack always.** Even on CRITICAL halt, kill
   background PIDs before exiting. A leaked `pnpm start` process prevents
   the next sprint from running.
4. **Verdict is mechanical.** Compute the verdict from row tallies per the
   rule above. Do NOT subjectively grade — that's the Evaluator's job.
   SIMULATE produces evidence; Evaluator produces judgment.
5. **NEEDS-REPAIR is acceptable.** A NEEDS-REPAIR verdict is the pipeline
   working correctly — the gap was caught before user impact. Do not pad
   the report. The Evaluator's anti-leniency protocol depends on accurate
   evidence.
```

- [ ] **Step 2: Verify with Grep — exactly one new top-level header `^## MODE: SIMULATE$`**

- [ ] **Step 3: Commit**

```
git add plugins/harness/agents/generator.md
git commit -m "feat(v3.0/C1): add MODE: SIMULATE to Generator (~250 lines, keystone change)"
```

---

### Task 15: Lighten Evaluator EVALUATE Step 2 to read simulation-report (C6)

**Files:** Modify `plugins/harness/agents/evaluator.md`

- [ ] **Step 1: Locate `## MODE: EVALUATE` → `### Step 2: Functional Testing via Playwright (primary evaluation)` (~lines 368-417 in v2.3.0)**

- [ ] **Step 2: Replace Step 2 wholesale with this content**

```markdown
### Step 2: Read simulation evidence + craft spot-check (v3.0+)

In v3.0+, prod-mode runtime verification + cumulative regression are owned
by Generator SIMULATE; this step reads SIMULATE's evidence and adds a craft
spot-check.

#### Step 2a — Read simulation-report.md as authoritative behavioural evidence

Read `.harness/features/${FEATURE}/simulation-report.md`. Verdict header:
- `**Verdict**: VERIFIED` — proceed; no Part A FAIL from runtime evidence.
- `**Verdict**: NEEDS-REPAIR` — at least one row failed; Part A will FAIL
  on the gap rows.

For each per-FR row in simulation-report:
- ✅ Verified — record as Met in your Part A FR table.
- ⚠️ Partial-runtime-gap — record as Partial; this row IS a Major finding
  under "## Findings" with simulation-report's evidence trail.
- ❌ Cannot-verify — record as Not Met; this row IS a Critical finding.

For each per-state-transition row:
- DB ✅ + UI ✅ → row passes; goes into Part A State-Transition table as Met.
- Either ❌ → row fails; Part A Met? = N for parent FR; document divergence
  in Findings.

For each per-negative-path row: same pattern.

For cumulative regression failures: record as MAJOR findings under a new
`## Cross-Feature Regressions` section in your eval-report. Do NOT treat as
Part A FAIL by themselves (the failed prior feature was Met when shipped;
question is whether the current feature broke it). Surface to user via
human gate.

For cross-runtime parity findings: per simulation-report's classification
(CRITICAL / MAJOR), file directly into Code Quality.

#### Step 2b — Independent Playwright sanity (15-min cap)

This is the "did SIMULATE lie or miss?" check — NOT a re-run.

Drive 1–2 of the most user-visible flows in the running app via Playwright
MCP. The orchestrator started the app via `bash .harness/init.sh` (dev
mode, lightweight) before dispatching you; SIMULATE already ran the prod
stack and torn it down. Use dev mode for spot-check; if a flow fails in
dev that passed in SIMULATE's prod run, that's a divergence finding.

Choose flows based on:
- FRs the Generator flagged as "Known Rough Edges" in implementation-report
- Risk areas surfaced by Step 3 code-quality review
- Edge cases simulation-report didn't cover (input >500 chars, special
  chars `<script>` / `'; DROP TABLE`, rapid clicks, browser back/forward)

Time-box: 15 minutes. Do NOT extend.

Record findings:
- If spot-check finds an issue SIMULATE missed: file as MAJOR under
  "## Findings — SIMULATE Gap"; tuning-log surfaces as divergence pattern.
- If spot-check confirms SIMULATE: single line in eval-report confirming
  alignment is sufficient.
```

- [ ] **Step 3: Verify line-count delta — expected ~−50 net (80 removed, ~30 added)**

- [ ] **Step 4: Commit**

```
git add plugins/harness/agents/evaluator.md
git commit -m "feat(v3.0/C6): Evaluator EVALUATE Step 2 lightens — reads simulation-report + 15-min spot-check (~−50 LoC)"
```

---

### Task 16: Update SKILL.md mode-routing tables, ownership rows, flow diagram, Pipeline Timing (C1.d + C7.e)

**Files:** Modify `plugins/harness/skills/harness/SKILL.md`

- [ ] **Step 1: Update Subagent Isolation Protocol § Dispatch mechanism**

Find: `harness:generator — Generator agent (NEGOTIATE, FINALIZE-CONTRACT, BUILD modes)`
Replace with: `harness:generator — Generator agent (NEGOTIATE, FINALIZE-CONTRACT, BUILD, SIMULATE modes)`

- [ ] **Step 2: Add ownership rows to File Ownership Contract table**

```markdown
| `features/NNN/simulation-report.md` | Generator SIMULATE | Evaluator EVALUATE |
| Contract State-Transition table — `Entity`/`From`/`To`/`Triggered by` cols | Planner Pass 2 | Generator NEGOTIATE, SIMULATE, Evaluator |
| Contract State-Transition table — `Playwright test name` col | Generator NEGOTIATE | Generator BUILD, SIMULATE, Evaluator |
| Contract Negative-Path table — `Constraint`/`Trigger`/`Expected error` cols | Planner Pass 2 | Generator NEGOTIATE, SIMULATE, Evaluator |
| Contract Negative-Path table — `Recovery test` col | Generator NEGOTIATE | Generator BUILD, SIMULATE, Evaluator |
| `tests/e2e/<NNN-feature-name>/journey.spec.ts` | Generator BUILD (TDD output) | SIMULATE, Evaluator |
```

- [ ] **Step 3: Update agent communication flow diagram**

In `### Flow`, insert SIMULATE between BUILD and Evaluator:

```
Generator BUILD    → reads  → ...
                   → writes → source code, git commits, progress/changelog.md,
                              features/NNN/implementation-report.md
Generator SIMULATE → reads  → contract.md (final), implementation-report.md,
                              proposal.md, prd.md, prior journey tests, manifest.yaml
                   → writes → features/NNN/simulation-report.md (NO source code)
Evaluator EVALUATE → reads  → simulation-report.md (authoritative behavioural evidence),
                              evaluator/criteria.md, examples.md, evaluator-notes.md,
                              implementation-report.md, contract.md (final), spec/
                   → writes → features/NNN/eval-report.md
```

- [ ] **Step 4: Add Pipeline Timing table row**

```markdown
| Generator SIMULATE | After Generator BUILD returns successfully | auto |
```

- [ ] **Step 5: Commit**

```
git add plugins/harness/skills/harness/SKILL.md
git commit -m "feat(v3.0/C1+C7): SKILL.md mode-routing, ownership rows, flow diagram, Pipeline Timing"
```

---

### Task 17: Add Step 3.5 (Simulate) to sprint.md (C7.a)

**Files:** Modify `plugins/harness/commands/sprint.md`

- [ ] **Step 1: Locate Step 3 (BUILD) end and Step 4 (EVALUATE) start**

- [ ] **Step 2: Insert Step 3.5 between them**

```markdown
---

## 3.5. Simulate — drive prod-mode runtime (automatic)

After Generator BUILD returns successfully (and the pause-protocol loop in
Step 3a has resolved), the orchestrator updates `manifest.yaml →
state.phase = "simulating"` (Edit tool) and dispatches Generator in
SIMULATE mode via the Agent tool.

The orchestrator dispatches:

- **subagent_type**: `harness:generator`
- **description**: `"Simulate ${FEATURE} via prod-mode Playwright"`
- **prompt** (passed verbatim):

> You are being dispatched in SIMULATE mode (see your system prompt's MODE
> ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root.
> All `.harness/...` paths resolve from project root. The
> `.worktrees/current/.harness/` folder is a stale frozen snapshot — never
> read or write it. Source code lives in `.worktrees/current/src/...`;
> spec, contract, and report files stay under project-root `.harness/`. If
> you `cd .worktrees/current` for a Bash command, `cd` back before any
> `.harness/` Read/Write, or use `$CLAUDE_PROJECT_DIR/.harness/...`
> absolute paths.
>
> Drive the production-mode runtime through the contract's State-Transition
> AC + Negative-Path Coverage tables. Replay all prior features'
> tests/e2e/<NNN>/journey.spec.ts cumulatively. Write your verdict to
> .harness/features/${FEATURE}/simulation-report.md per the template at
> @templates/features/simulation-report.md.txt with **Verdict**: VERIFIED |
> NEEDS-REPAIR header.
>
> Mandatory reads BEFORE driving:
> - .harness/features/${FEATURE}/contract.md (final, with State-Transition
>   + Negative-Path tables)
> - .harness/features/${FEATURE}/implementation-report.md
> - .harness/features/${FEATURE}/proposal.md
> - .harness/spec/prd.md § "User Journeys" + § "UI-Surface Audit"
> - manifest.yaml → features.completed[]

After dispatch returns:

1. Extract the line matching `\*\*Verdict\*\*: (VERIFIED|NEEDS-REPAIR)`.
2. **If VERIFIED:** orchestrator updates `state.phase = "evaluating"` and
   proceeds to Step 4.
3. **If NEEDS-REPAIR:** for v3.0, **proceed to Step 4 anyway**. Evaluator's
   Part A binary check will FAIL on gap rows (per updated Step 2a in
   evaluator.md), triggering standard retry loop. Inner repair loop
   (auto-retry Generator BUILD with simulation-report context) deferred to
   v3.1 per spec § 3 N2.
4. **If simulation-report.md missing or malformed** (no verdict header):
   treat as SIMULATE failure. Block merge; ask user to rerun via
   `/harness:resume` or rewind.

---
```

- [ ] **Step 3: Verify Step 4 (EVALUATE) still numbered 4**

- [ ] **Step 4: Commit**

```
git add plugins/harness/commands/sprint.md
git commit -m "feat(v3.0/C7): sprint.md Step 3.5 dispatches Generator SIMULATE between BUILD and EVALUATE"
```

---

### Task 18: Add `simulating` to manifest.yaml `state.phase` enum (C7.b)

**Files:** Modify `plugins/harness/templates/manifest.yaml`

- [ ] **Step 1: Update `state.phase` inline enum comment**

```yaml
state:
  phase: planning  # planning | analyzing | negotiating | building |
                   # simulating | evaluating | retrospective | complete |
                   # amending | clarifying | editing | tuning |
                   # constitution-amending
```

- [ ] **Step 2: Commit**

```
git add plugins/harness/templates/manifest.yaml
git commit -m "feat(v3.0/C7): manifest.yaml state.phase enum gains 'simulating'"
```

---

### Task 19: Add resume.md phase-recovery branch for `simulating` (C7.c)

**Files:** Modify `plugins/harness/commands/resume.md`

- [ ] **Step 1: Locate phase-specific recovery section**

- [ ] **Step 2: Insert `simulating` branch (between `building` and `evaluating`)**

```markdown
- **`simulating`**: if `simulation-report.md` exists for the current
  feature, the SIMULATE dispatch finished but orchestrator was interrupted
  before phase transition. Read verdict, transition to `evaluating`, and
  proceed to Step 4 (EVALUATE). If `simulation-report.md` is absent, the
  SIMULATE dispatch was interrupted; re-dispatch Generator SIMULATE with
  the same prompt as sprint.md Step 3.5.
```

- [ ] **Step 3: Commit**

```
git add plugins/harness/commands/resume.md
git commit -m "feat(v3.0/C7): resume.md handles 'simulating' phase recovery"
```

---

### Task 20: Add `simulating` as a valid rewind target in rewind.md (C7.d)

**Files:** Modify `plugins/harness/commands/rewind.md`

- [ ] **Step 1: Find valid-targets list (typically `planning | analyzing | negotiating | building | evaluating`)**

- [ ] **Step 2: Update to: `planning | analyzing | negotiating | building | simulating | evaluating`**

- [ ] **Step 3: Ensure rewind procedure archives `simulation-report.md` to `.archive/TIMESTAMP/` when user rewinds to or past `simulating`**

Use existing pattern for other phases.

- [ ] **Step 4: Commit**

```
git add plugins/harness/commands/rewind.md
git commit -m "feat(v3.0/C7): rewind.md adds 'simulating' as valid target with simulation-report.md archival"
```

---

## End of Part 1

Phase 1 — Verification gap implementation complete after Tasks 1-20.

**Continue to Part 2** (`docs/superpowers/plans/2026-05-07-belcort-v3-runtime-verification-and-audit-part-2.md`) for:

- Self-tests ST1-ST7 (Tasks 21-27) — validate Phase 1 changes
- Phase 2 audit scans (Tasks 28-32) — apply v2.0 / v2.2 / v2.3 ruler to post-Phase-1 surface
- Phase 3 documentation updates (Tasks 33-36) — anthropic-alignment, CHANGELOG, ROADMAP, README
- Phase 4 canary (Task 37) — stress-test on BELCORT ACC v2 feature-004
- Phase 5 release (Tasks 38-39) — atomic PR to v2-beta then FF to main
- Self-Review against spec coverage
- Execution handoff (Subagent-Driven vs Inline)

Do NOT begin self-tests until all 20 implementation tasks have committed cleanly. Self-tests verify Phase 1 produces expected artifacts; if Phase 1 has gaps, self-tests should catch them before Phase 2 builds on the foundation.
