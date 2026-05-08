# BELCORT Harness v3.0 — Runtime-Verification Phase + Audit Pass (Design Spec)

**Date**: 2026-05-07
**Author**: BELCORT (tao@belcort.com)
**Target model**: `claude-opus-4-7[1m]` (1M context variant — see § 8.2)
**Refactor scope**: Single-PR atomic merge. Two layered changes: (a) close the runtime-verification gap surfaced by BELCORT ACC v2's 8-bug demo-prep incident by adding a SIMULATE mode to the Generator and tightening the contract template; (b) full audit sweep applying the v2.0 / v2.2 / v2.3 ruler to anything accreted since v2.3.0 (eight days ago). Predicted net LoC: +300 to +430.
**Predecessors**:
- `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md` (v2.0 — minimalist rewrite, ~−900 LoC)
- `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md` (v2.2 — stale-assumption pruning, ~−300 LoC)
- `docs/superpowers/specs/2026-04-29-belcort-v2.3-agent-prompt-deduplication-design.md` (v2.3 — agent prompt dedup, ~−50 LoC)
**Source report**: `BELCORT ACC v2/.harness/harness-improvements-report-2026-05-07.md` (deep-research subagent, post-feature-003 demo-prep blocker chain — 8 bugs surfaced after the Evaluator gave PASS)

---

## 1. Context & Motivation

The proximate trigger is the BELCORT ACC v2 feature-003 demo-prep incident: 8 bugs surfaced *after* the Evaluator gave PASS, every one of which would have been caught by driving the production-mode runtime end-to-end through a real browser observing a real worker process. The deep-research subagent commissioned to investigate (`harness-improvements-report-2026-05-07.md`) returns a structurally diagnostic finding:

> *"The harness is structurally sound — Planner → Generator → Evaluator with file-based handoffs and fresh subagent contexts is exactly what Anthropic's harness research prescribes. What's broken is the coverage of 'done': the Evaluator grades the artifact … but never simulates the user journey through the running product."*
> — `harness-improvements-report-2026-05-07.md` § 1

Mapped to Anthropic's verification triad (Effective Harnesses + Rajasekaran 2026, *"three approaches for verification: rules-based feedback, visual feedback, and LLM-as-judge"*):

| Verification leg | Today's owner | Status |
|---|---|---|
| Rules-based (lint, types, unit tests) | Generator TDD loop + Evaluator Step 4 re-run | ✅ Covered |
| LLM-as-judge | Evaluator Part A binary + Part B numeric, calibration-mandatory | ✅ Covered |
| Visual / interactive | Evaluator EVALUATE Step 2 (`agents/evaluator.md:268`) | ⚠️ **Partial** — runs dev-mode (Turbopack) against the same artifact the Generator already tested |

The visual leg is BELCORT's only verification weakness because the Evaluator's Playwright pass shares a runtime mode and a build with the Generator. Bugs that only fire under prod runtime (Bug #2 `__getUnscopedDb` stack-walker), under real worker process (Bugs #1 S3-stub, #7 status-never-extracted), or under cross-feature interaction (Bug #5 review-queue stuck) bypass every existing gate. This is the precise gap action [1] in the source report addresses.

This audit closes the gap (§ 5) and applies the v2.0 / v2.2 / v2.3 ruler to anything accreted since v2.3.0 (§ 6). Two layered axes; verification-first weight (per Q1); audit as polish layer (per Q4). Both axes ship in a single atomic v3.0 PR per ruler #7.

### Anti-goal

Not a redesign of the 3-agent topology. The Planner / Generator / Evaluator + file-based handoffs + fresh subagent contexts pattern is preserved verbatim per Anthropic's GAN insight (ruler #4) and explicit anti-rec 10.1 of the source report. SIMULATE is a new MODE on the existing Generator subagent type, not a new role.

---

## 2. The Ruler

Five Anthropic principles verbatim, carried forward from the v2.0, v2.2, and v2.3 specs:

1. *"Find the simplest solution possible, and only increase complexity when needed."* — Rajasekaran 2026
2. *"Every component in a harness encodes an assumption … those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."* — Rajasekaran 2026
3. *"Communication was handled via files."* — Rajasekaran 2026
4. *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* — Rajasekaran 2026 (GAN isolation, non-negotiable)
5. *"With Opus 4.6 I dropped context resets from this harness entirely."* — Rajasekaran 2026 (continuous-session principle)

Three user-stated constraints (this round):

6. **Verification > audit weight.** The runtime-verification gap is the load-bearing fix; the audit is the polish layer. Time and attention budget allocated proportionally.
7. **Atomic v3.0.** Single PR, single major version bump. No staged rollout, no patch-train.
8. **Three-agent topology preserved.** No 4th subagent type. Anti-rec 10.1 from the source report is binding: SIMULATE is a Generator MODE, not a new role.

These eight rulers are the test every change in § 5 and every scan in § 6 is checked against — each gets a "Why this fits the ruler" line.

---

## 3. Goals & Non-goals

### Goals — Verification (G1–G5, primary axis per ruler #6)

- **G1.** Add **Generator MODE: SIMULATE** that drives prod-mode build + worker + Playwright + per-state-transition DB queries, dispatched between BUILD and EVALUATE. Per-feature user-journey verification AND cumulative regression replay across all shipped features (per Q3 = S2).
- **G2.** Tighten the contract template with three new mandatory sections: **State-Transition AC table**, **Negative-Path Coverage table**, and a **UI-surface AC** clause for any FR mutating a `status` / `state` / `phase` field. Every row binds to a named test file.
- **G3.** Add a **Planner Pass 2 brainstorming pass** over user-journey ACs — for each journey, *"what does the user actually see when this works?"* Surfaces UI-coverage gaps at spec time (closes Bug #8 class).
- **G4.** Add **`} catch {}` ban** as a new MUST principle in the canonical `templates/spec/constitution.md.txt`. Evaluator Step 3 gets a grep scan for `catch\s*\{[^}]*\}` and `catch\s*\(.*\)\s*\{\s*\}` patterns (closes Bug #6 class).
- **G5.** **Lighten Evaluator EVALUATE Step 2** — SIMULATE now owns prod-mode runtime; Evaluator's Step 2 becomes a craft spot-check that reads `simulation-report.md` as authoritative behavioural evidence + runs one independent Playwright sanity pass to confirm SIMULATE didn't lie or miss. Net delta on Evaluator is a *removal* of redundant prod-stack-spin work (~80 LoC).

### Goals — Audit (G6–G10, polish layer)

Applied AFTER G1–G5 land, so the audit measures the post-fix surface:

- **G6.** Cross-agent prompt duplication scan across `agents/{planner,generator,evaluator}.md`. Targets: RED FLAGS tables, leniency / anti-leniency content, mode-routing tables, `## HANDLING FETCHED CONTENT` blocks, BEHAVIORAL RULES sections.
- **G7.** Doc-vs-code drift scan across `README.md`, `CHANGELOG.md`, `SKILL.md`, `docs/anthropic-alignment.md`, `ROADMAP.md`. Three classes: stale file:line citations, wrong prompt quotes, outdated command-set claims.
- **G8.** Stale-assumption probe — every component re-evaluated against ruler #2: *"is this still load-bearing on Opus 4.7[1m]?"*
- **G9.** Manifest schema unused-fields scan, same logic as v2.0's per-agent-model-pinning removal.
- **G10.** Command-set redundancy review (16 commands; v2.2 dropped `/harness:negotiate`; check if another matches).

### Non-goals (deferred to v3.1+)

- **N1.** Per-FR Playwright probe inside BUILD (source report action [3]). Keeps BUILD context lean; promote to v3.1 if SIMULATE's per-feature granularity proves insufficient.
- **N2.** Orchestrator-driven inner repair loop on SIMULATE → BUILD failure (source report action [6]). Defer until S2 ships and we observe whether the full-Evaluator-round-trip cost is actually painful.
- **N3.** Playwright Test Agents healer pattern (source report § 8.1). Adds a 4th agent role; violates ruler #8.
- **N4.** Mutation testing via Stryker.js (source report § 5.2). High cost, lower ROI than SIMULATE.
- **N5.** Stratum-splitting BUILD into N dispatches (already on `ROADMAP.md` v3 watch list, item 1).

---

## 4. Architectural decisions locked

### Q1–Q4 outcomes

| # | Question | Choice | Anchor |
|---|---|---|---|
| Q1 | Audit shape | **C** — combined verification + audit, verification weight | User-stated; "fill gap, then prune" sequencing |
| Q2 | Verification location | **B** — new Generator MODE: SIMULATE | Source report § 7.1 + anti-rec 10.1; preserves 3-agent topology (ruler #8) |
| Q3 | SIMULATE workflow | **S2** — per-feature journey + cumulative regression | Catches Bug #5 / #7 class without compounding retry loops (ruler #1) |
| Q4 | Audit scope | **C** — full sweep | User-stated; ruler-application discipline still proportionate to verification weight |

### Mechanical ratifications (no Socratic question; consequence of locked choices)

- **R1.** SIMULATE dispatched as a fresh `harness:generator` Agent-tool call after BUILD returns — *not* as a continuation of BUILD's context. Matches the existing NEGOTIATE / FINALIZE / BUILD pattern documented in `plugins/harness/skills/harness/SKILL.md:53–56`. Avoids the leniency bias of self-judging in the same context.
- **R2.** Evaluator EVALUATE reads `simulation-report.md` as authoritative behavioural evidence; its Playwright work becomes a sanity spot-check, not a primary functional pass.
- **R3.** Cumulative regression files use **per-feature directories**: `tests/e2e/<NNN-feature-name>/journey.spec.ts`. Generator NEGOTIATE proposes the path; BUILD writes the test as one of the FR's TDD outputs; SIMULATE invokes `npx playwright test tests/e2e/` against the cumulative tree. Diverges from the report's monolithic `tests/e2e/investor-demo.spec.ts` because per-feature directories preserve atomic feature ownership and allow clean revert.
- **R4.** Catch-block ban (G4) ships only in the canonical template (`plugins/harness/templates/spec/constitution.md.txt`). Existing v2.x projects' constitutions are unaffected unless they explicitly run `/harness:constitution-amend` — preserves the v1.5+ post-init immutability guarantee.
- **R5.** v3.0 lands as **a single atomic PR** to `v2-beta`, observed for one canary sprint on BELCORT ACC v2 feature-004, then FF-merged to `main`.

---

## 5. Verification-gap changes

Each change follows the same shape: **Problem → Evidence → Change → Files affected → Risk → Test → Ruler fit**. Ordered by dependency: contract template tightening (C2–C4) produces the structured input SIMULATE needs; SIMULATE (C1) then reads it; Evaluator delta (C6) consumes SIMULATE's output; sprint flow (C7) wires everything together. C5 (catch-block ban) is independent but bundled atomic per ruler #7.

### Change 1 — New Generator MODE: SIMULATE

**Problem.** Generator hands off `implementation-report.md` based on unit-test pass + a textual self-eval checklist (`plugins/harness/agents/generator.md:413-444`). Evaluator's Playwright pass runs in dev mode (`plugins/harness/agents/evaluator.md:360`, `bash .harness/init.sh`) against the same artifact. Neither agent observes the production-mode runtime, the real worker process, or the DB state-transitions. The visual verification leg of Anthropic's triad is partial.

**Evidence.**
- `agents/generator.md:354` — BUILD delegates RED→GREEN→REFACTOR to `superpowers:test-driven-development` — unit-level by design.
- `agents/evaluator.md:268` declares Playwright as primary, but `agents/evaluator.md:360` uses `bash .harness/init.sh` for app start (dev mode), not `pnpm build && pnpm start && pnpm worker`.
- `harness-improvements-report-2026-05-07.md` line 35: *"Today the Evaluator is the only agent that runs Playwright; the Generator is essentially blind to runtime behaviour and submits work it has only proven at the unit-test layer."*
- 8 production bugs from BELCORT ACC v2 feature-003, all inside the gap class (per the appendix mapping in the source report).

**Change.** Add a 4th MODE to the Generator. Mode-routing table at `agents/generator.md:48-53` grows from 3 rows to 4. New `## MODE: SIMULATE` section ~250 lines after `## MODE: BUILD`.

SIMULATE is dispatched as a fresh `harness:generator` Agent-tool call after BUILD returns. Per R1, it has fresh context — same isolation guarantee as the NEGOTIATE → REVIEW-PROPOSAL → FINALIZE-CONTRACT → BUILD chain.

**SIMULATE workflow** (7 steps):

| Step | Action | Output |
|---|---|---|
| 1 | Setup — read `contract.md` (must contain `**Negotiated**:` marker, else CRITICAL halt — same gate as Evaluator), `implementation-report.md`, `proposal.md`, `prd.md` § "User Journeys", `manifest.yaml → features.completed[]`. Verify `tests/e2e/<NNN-feature-name>/journey.spec.ts` exists (Generator BUILD must have written it). | go / halt |
| 2 | Start prod stack — `pnpm build` (or equivalent — read `package.json` scripts via Read tool) → `pnpm start` (web server, run via Bash with `run_in_background: true`) → `pnpm worker` if `package.json` has it (also background) → migrate fresh test DB if applicable (`pnpm db:reset && pnpm db:migrate` or equivalent). Wait for servers to bind their ports (Playwright `await page.goto(URL)` with retry, 30s timeout). | servers bound |
| 3 | Drive current feature's State-Transition AC rows via Playwright. For each row in `contract.md`'s State-Transition AC table: drive the user flow that triggers the transition; screenshot at the state-transition boundary; query the DB after each transition to confirm DB state matches UI (via Bash: `psql ${DB_URL} -c 'SELECT status FROM <table> WHERE id=...'`). | per-FR verification rows in simulation-report |
| 4 | Drive Negative-Path Coverage rows. For each row in `contract.md`'s Negative-Path Coverage table: trigger the constraint violation; confirm expected error appears in UI; confirm DB state is recovered (no abort, no orphan rows, no transaction stuck). | per-constraint verification rows |
| 5 | Cumulative regression replay. Run `npx playwright test tests/e2e/` against the running prod stack. Each prior feature's `<NNN-feature-name>/journey.spec.ts` runs as a regression test. | regression PASS/FAIL list |
| 6 | Cross-runtime parity quick-check (5-min cap, source report action [5] folded in). Compare unit-test behavior in dev (Vitest/Turbopack) against current prod build behavior. Specifically detect `__getUnscopedDb`-class bugs — utilities that read stack traces or filenames may behave differently under bundlers. If no specific suspicion, skip. | parity finding (or "none") |
| 7 | Write `simulation-report.md` per template `templates/features/simulation-report.md.txt` with `**Verdict**: VERIFIED \| NEEDS-REPAIR` header. Per-FR row format: `✅ Verified` / `⚠️ Partial-runtime-gap` / `❌ Cannot-verify` with screenshot paths + DB-state evidence. Per-state-transition row: confirmed-in-DB / UI-mismatch / missing. Per-negative-path row: error-shown-correctly / error-eaten / recovery-works / recovery-broken. Cumulative regression: list of which prior features passed, which failed. Cross-runtime parity finding (if any). Tear down servers (kill background `pnpm start` and `pnpm worker` PIDs). | handoff to Evaluator |

If any FR is `⚠️ Partial-runtime-gap` or `❌ Cannot-verify`, the file's header has `**Verdict**: NEEDS-REPAIR`. Evaluator EVALUATE will read this and Part A will FAIL.

If all FRs are `✅ Verified`, header says `**Verdict**: VERIFIED`. Evaluator EVALUATE proceeds to craft grading.

**Files affected:**
- `plugins/harness/agents/generator.md` (+~250 lines, new MODE section + 4-row mode-routing table)
- `plugins/harness/templates/features/simulation-report.md.txt` (new file, ~80 lines)
- `plugins/harness/templates/manifest.yaml` (+1 line, `state.phase` enum gains `simulating`)
- `plugins/harness/skills/harness/SKILL.md` (+~12 lines: mode table updated, new ownership row for `simulation-report.md`, flow diagram updated to insert SIMULATE phase)
- `plugins/harness/commands/sprint.md` — covered separately in C7

**Risk.**
- **Cumulative regression cost grows linearly with shipped features.** At feature 20+, single SIMULATE dispatch may approach 15 minutes (5 min stack-up + 30 s/journey × 20 journeys). Acceptable per Q3 = S2 acceptance; healer pattern (N3) stays parked. Parallel-dispatch (`ROADMAP.md` v3 item 1) is the natural v3.1 mitigation if real.
- **Generator-as-its-own-verifier leniency bias.** SIMULATE is the Generator-typed agent verifying its own builder's output (via fresh context, but same training distribution). Mitigated by R1 (fresh context dispatch) + Evaluator EVALUATE Part A still binary-gates + tuning-log captures divergence. SIMULATE produces *behavioural evidence* (screenshots + DB state), not *judgment* — it cannot mark its own work PASS, only VERIFIED-or-NEEDS-REPAIR against the contract's tables.
- **Stack-up cost on small features.** ~90 s overhead (build + start + worker bind) on a 2-FR feature. Acceptable cost for the bug class it eliminates.

**Test.** Self-test 1 in § 10.2.

**Ruler fit.**
- **#1 simplest** — smallest viable change that closes the visual-verification leg; alternatives (per-FR probe N1, healer N3, 4th agent) all carry more machinery for less marginal coverage.
- **#4 separation** — SIMULATE runs in fresh context, separated from BUILD's reasoning even though both are Generator-typed. Evaluator still grades independently.
- **#7 atomic v3.0** — single new mode lands with the contract tightening that drives it (C2–C4) and the Evaluator delta that consumes it (C6) in one PR.
- **#8 three-agent topology** — no new agent type. SIMULATE is `harness:generator` mode #4.

---

### Change 2 — Contract template: State-Transition AC + Negative-Path Coverage tables

**Problem.** Contracts list FRs and ACs but don't enumerate (a) the data-model state transitions a feature mutates, nor (b) the constraint-violation paths the data-model implies. Bug #4 (Postgres transaction abort on duplicate) and Bug #7 (status-never-extracted) are both *"spec didn't require a test for this"* failures, not implementation failures.

**Evidence.**
- `plugins/harness/templates/features/contract.md.txt` — current sections cover FRs / ACs / ECs / NFRs to verify / Definition of Done, but no state-machine table.
- Source report § 6.1 verbatim mandate: *"For every state field in the data model that this feature mutates, list each transition and its corresponding observable Playwright test."*
- Source report § 6.3 verbatim: *"For each unique constraint, foreign-key constraint, or check constraint in the data model that this feature exercises..."*
- Bugs #4 + #7 in source report appendix → both addressable directly by these tables.

**Change.** Add two new mandatory sections to `templates/features/contract.md.txt`:

**(a) State-Transition ACs**

```markdown
## State-Transition ACs

For every state field in the data model that this feature mutates, list each
transition and its corresponding observable Playwright test:

| Entity.Field | From | To | Triggered by | Playwright test name |
|--------------|------|-----|--------------|----------------------|
| <example>    |      |     |              |                      |
```

Population responsibility:
- **Planner Pass 2** populates `Entity` / `From` / `To` / `Triggered by` columns from `architecture.md`'s data model. The data-model section of architecture must declare state machines explicitly enough for the Planner to enumerate transitions.
- **Generator NEGOTIATE** populates the `Playwright test name` column with files that will exist after BUILD. Format: `tests/e2e/<NNN-feature>/journey.spec.ts > test('<name>')`.
- **Evaluator REVIEW-PROPOSAL** verifies each row has a non-blank test-name; rejects `agreed` if any row blank.
- **Generator BUILD** writes the named tests as TDD outputs.
- **Generator SIMULATE Step 3** drives each row's test against prod runtime + queries DB to confirm state.
- **Evaluator EVALUATE Part A** refuses to mark FR Met without one passing named test per row.

**(b) Negative-Path Coverage**

```markdown
## Negative-Path Coverage

For each unique constraint, foreign-key constraint, or check constraint in
the data model that this feature exercises:

| Constraint | Trigger scenario | Expected error | Recovery test |
|------------|------------------|----------------|---------------|
| <example>  |                  |                |               |
```

Same ownership pattern: Planner Pass 2 populates `Constraint` / `Trigger scenario` / `Expected error` from architecture's data-model constraints (UNIQUE, FOREIGN KEY, CHECK); Generator NEGOTIATE populates the `Recovery test` column; SIMULATE Step 4 drives each row + verifies recovery; Evaluator EVALUATE Part A gates on test presence + passing.

**Files affected:**
- `plugins/harness/templates/features/contract.md.txt` (+~40 lines, two new sections + example rows)
- `plugins/harness/agents/planner.md` (~+30 lines, Pass 2 step that emits these tables — driven from architecture.md's data model and constraints)
- `plugins/harness/agents/generator.md` (~+15 lines, NEGOTIATE mode populates test-name columns + FINALIZE-CONTRACT preserves them)
- `plugins/harness/agents/evaluator.md` (~+20 lines, REVIEW-PROPOSAL Step 5 verifies coverage; EVALUATE Part A gates on these rows)

**Risk.**
- Planner Pass 2 produces incomplete state-machine if `architecture.md`'s data model is shallow — but that's an architecture-quality issue *surfaced* by the new requirement, not introduced by it. Mitigation: Planner's existing Pass 2 self-validation gains a row: *"For each entity in architecture.md with a status/state/phase field, the contract has at least one State-Transition AC row."*
- Generator NEGOTIATE may stub test-name columns with implausible paths — Evaluator REVIEW-PROPOSAL catches via the new Step 5 expansion. Round-2 negotiation resolves; if 3-round escalation fires, the human gate handles it (existing pattern from `commands/sprint.md` § 2c).
- Existing v2.x projects without these tables: contracts are per-feature, not global, so existing in-flight features are unaffected. Any NEW sprint produces the tables. Graceful migration.

**Test.** Self-test 1 in § 10.2 (verifies State-Transition rows produced for `todos.status`).

**Ruler fit.**
- **#1 simplest** — small template addition; no new files, no new commands.
- **#6 verification weight** — directly enables SIMULATE's per-state-transition verification. Without these tables, SIMULATE has nothing to drive at the entity-state level.

---

### Change 3 — Contract template: UI-surface AC for status / state / phase fields

**Problem.** Contract today lists FRs and ACs but doesn't require that a UI-rendering AC exist for any FR mutating a status/state/phase field. Bug #8 (dashboard table missing extraction-status column) is exactly this class — the status field changed in DB, but no UI surfaced it; user could not see the AI worked.

**Evidence.**
- Source report action [8] verbatim: *"every FR with status or state field in its data model MUST include a 'user can see this state in the UI' AC tied to a specific page/component."*
- Bug #8 in source report appendix → directly.

**Change.** Add a clause to the contract template's FR-section schema. For any FR whose ACs mutate a `status` / `state` / `phase` field, a UI-surface AC must be present. Format:

```markdown
- AC-NNN-ui: User can see <field-value-transformation> on <route> via
  selector <selector>. Asserted by Playwright test
  `tests/e2e/<NNN-feature>/journey.spec.ts > test('<name>')`.
```

Required components:
- **Route** — `/dashboard/documents`
- **Selector** — `[data-testid="status-badge"]`
- **Value transformation** — `'extracted' → 'Extracted'` (DB raw → user-visible label)
- **Test name** — same Playwright test that exercises the State-Transition AC

This is enforced as an Evaluator REVIEW-PROPOSAL Step 5 gate (currently architecture/constitution checks; this expansion adds the UI-surface check).

**Files affected:**
- `plugins/harness/templates/features/contract.md.txt` (+~10 lines, FR-section schema annotation + example UI-surface AC)
- `plugins/harness/agents/planner.md` (+~10 lines, Pass 2 step gains the UI-surface requirement)
- `plugins/harness/agents/evaluator.md` (+~15 lines, REVIEW-PROPOSAL Step 5 expansion)

**Risk.**
- Some status fields are internal-only (e.g., audit-log status, internal-job-state) and don't need UI surface. Mitigation: heuristic in template comment: *"user-observable lifecycle stages need UI; internal/admin-only stages don't. If unsure, declare the AC; if the user really shouldn't see it, the Planner can add a `## UI-Surface Excluded` note with rationale."*
- Generator NEGOTIATE may push back on UI requirement when architecture is API-only (no UI). Mitigation: Evaluator REVIEW-PROPOSAL Step 5 reads `architecture.md`; if architecture declares no UI surface, the UI-surface AC requirement is skipped automatically (already the pattern for the C4 brainstorming pass).

**Test.** Self-test 1 in § 10.2 (verifies UI-surface AC produced for `todos.status` field).

**Ruler fit.**
- **#1 simplest** — template + REVIEW-step expansion, no new file.
- **#6 verification weight** — closes Bug #8 class at spec time, before contract negotiation completes.

---

### Change 4 — Planner Pass 2: brainstorming pass over user-journey ACs

**Problem.** Planner Pass 2 emits FRs / ACs / NFRs / risks / scope but doesn't force a *"what does the user actually see at each journey step?"* interrogation. Result: ACs that pass technically but don't terminate at observable UI states. Bug #8 again, but at a higher level — the brainstorming pass would have surfaced *"no UI surface for extraction status"* before the contract was written.

**Evidence.**
- Source report § 3.2 + action [10] verbatim: *"when the Planner emits a contract, run a synthetic brainstorming pass over the user-journey ACs — does each one terminate at an observable UI state?"*
- v1.5's `/harness:brainstorm` is opt-in pre-plan (per `commands/brainstorm.md`); this change makes the core insight inline-mandatory at Pass 2. Same logic by which Superpowers' `brainstorming` skill was invoked here for the v3.0 design itself.

**Change.** New Pass 2 step in `agents/planner.md` after current "Define test criteria" step. For each user journey UJ-NNN, the Planner asks itself:

> *"When the system performs each step of this journey successfully, what does the user see? Where? Through what selector?"*

Each "user can't see this" finding becomes:
- A new UI-surface AC (per C3), OR
- An AskUserQuestions escalation (the user may want to defer the UI to a later feature)

Output is appended to `prd.md` under a new `## UI-Surface Audit` section as a per-journey list:

```markdown
## UI-Surface Audit

### UJ-001 — User uploads a document
- Step 1: User selects file → observable: file name appears in upload list
  → route `/dashboard/upload` → selector `[data-testid="upload-list"]`
- Step 2: System extracts → observable: status badge changes from
  'received' to 'extracted' → route `/dashboard/documents/:id`
  → selector `[data-testid="status-badge"]`
- Step 3: User reviews extracted fields → observable: form fields
  pre-populated → route `/dashboard/documents/:id/review`
  → selectors `[data-testid="field-<name>"]`
```

Adds one row to Planner's 16-point self-validation checklist:

> **V17:** Every UJ has every step covered by an observable user-state-change OR a deliberate `## UI-Surface Excluded` note.

(Bumps self-validation from 16 points to 17.)

**Files affected:**
- `plugins/harness/agents/planner.md` (+~50 lines, new Pass 2 step + V17 self-validation)
- The PRD is written directly by Planner in PLAN mode; no separate template change needed.

**Risk.**
- Pass 2 grows in length and time. Acceptable trade per ruler #6 (verification weight).
- Planner may over-elaborate UI-surface for non-UI features (CLI tools, API-only services). Mitigation: heuristic in prompt: *"if architecture.md declares no UI surface, skip this step entirely and add `## UI-Surface Audit: N/A — non-UI feature` to prd.md."*

**Test.** Self-test 1 in § 10.2 (verifies UJ-Surface Audit appears for the todo feature).

**Ruler fit.**
- **#1 simplest** — prompt expansion only; no new file or command.
- **#6 verification weight** — closes Bug #8 class at spec time, *before* contract negotiation.
- Adopts Superpowers' brainstorming-skill insight formally — v1.5 had `/harness:brainstorm` opt-in; this makes the UI-observability part inline-mandatory.

---

### Change 5 — Constitution template: catch-block ban

**Problem.** Empty/no-op catch blocks silently swallow errors. Bug #6 (Clerk `getCurrentSession` `} catch {}` swallowed authentication errors → returned `null` → app pretended user was unauthenticated rather than surfacing the real bug) was the production manifestation. Constitution today has no MUST-principle on error surfacing.

**Evidence.**
- Source report action [7] verbatim: *"Add `} catch {}` ban + audit-export-style audit to constitution AND a grep-based scan in Evaluator Step 3 for swallowed-error patterns: `catch\s*\{[^}]*\}` and `catch\s*\(.*\)\s*\{\s*\}`."*
- Bug #6 in source report appendix → directly.

**Change.** Two atomic pieces:

**(a)** New MUST principle in canonical `plugins/harness/templates/spec/constitution.md.txt`:

```markdown
### §N — Errors at boundaries MUST be surfaced or explicitly logged.

Forbidden patterns in `src/` (not test code):
- Empty catch:                `try { ... } catch {}`
- Empty body:                 `try { ... } catch (e) {}`
- Catch without re-throw,
  log, or explicit error
  return:                     `try { ... } catch (e) { /* ... */ }`
                              with no `throw`, no `console.error`,
                              no `logger.*`, no `return Error`/`Result.err`

Exception: tests may use empty catch when the exception is the assertion
(e.g., `expect(() => fn()).toThrow()` is fine). Source code may not.

Rationale: silent error swallowing creates ghost-state bugs the Evaluator's
black-box testing cannot detect. The Bug #6 class (authentication catch
swallowing → null user → "feature works unless you've signed out") is the
canonical instance.
```

**(b)** Evaluator EVALUATE Step 3 (Code Quality Review) gains a grep procedure:

```bash
# Catch-block ban scan
grep -rn -E 'catch\s*\{[^}]*\}|catch\s*\(.*\)\s*\{\s*\}' src/ 2>/dev/null
```

Each match → CRITICAL finding under Code Quality, unless the match is in test code AND the surrounding context (read 3 lines before + 3 after via `grep -A 3 -B 3`) shows the catch is intentional (asserting a throw).

**Files affected:**
- `plugins/harness/templates/spec/constitution.md.txt` (+~15 lines, new MUST principle as §N — N is the next available principle number after the existing constitution template's principles)
- `plugins/harness/agents/evaluator.md` (+~15 lines, Step 3 grep procedure addition)

**Risk.**
- Existing v2.x projects' constitutions don't have this principle until the user runs `/harness:constitution-amend` — preserves immutability per ruler #8 / R4.
- The single-line grep may false-positive on multi-line `catch {\n logger.error(e)\n}` blocks where the regex doesn't span lines. **Implementation-time decision (per § 11):** use a multiline-aware version that detects `catch\s*\([^)]*\)\s*\{[\s\S]*?\}` and inspects the body for forbidden absence-of-handling. If the multiline approach surfaces too many false positives in practice, fall back to the source report's literal regex with documented disclosure in the constitution principle.
- Catch-block ban could conflict with framework-specific patterns (e.g., some libraries expect silent catches in event handlers). Mitigation: constitution principle is overridable per-project — Planner Pass 1 may strike or modify it during constitution drafting if architecture's framework requires it.

**Test.** Self-test 5 in § 10.2 (`try {...} catch {}` in source → CRITICAL finding).

**Ruler fit.**
- **#1 simplest** — 1 constitution principle + 1 grep procedure.
- **#2 stale-assumption** — this is a NEW principle, not a removal — closes a bug class the prior constitution didn't address.
- **#4 separation** — principle authored by Planner Pass 1; Evaluator enforces at EVALUATE; clean ownership.
- **#6 verification weight** — low-cost addition that closes Bug #6 class.

---

### Change 6 — Evaluator EVALUATE Step 2 lightens *(net REMOVAL)*

**Problem.** Once SIMULATE owns prod-mode runtime + worker + DB queries + cumulative regression (per C1), Evaluator's EVALUATE Step 2 (`agents/evaluator.md:368-417`, "Functional Testing via Playwright — primary evaluation") becomes redundant work. The Evaluator currently runs `bash .harness/init.sh` and drives Playwright in dev mode — same coverage SIMULATE just produced authoritatively in prod mode. Two full stack spins per evaluation.

**Evidence.**
- `agents/evaluator.md:368-417` — current Step 2 workflow ("Goal-backward verification", happy path / edge cases / error paths) drives Playwright as primary functional pass.
- `agents/evaluator.md:360` — current "Start the app via `bash .harness/init.sh`" (dev mode, not prod build).
- C1's R2 ratification: SIMULATE produces simulation-report.md as authoritative behavioural evidence.

**Change.** Rewrite `agents/evaluator.md` Step 2 from "primary evaluation" to "craft spot-check":

**Step 2a — Read simulation-report.md as authoritative behavioural evidence.**

- Cross-reference per-FR `Verified` / `Partial-runtime-gap` / `Cannot-verify` rows against `contract.md`'s State-Transition AC + Negative-Path Coverage tables.
- Any non-Verified row → Part A FAIL trigger; document each in Part A as `Met? = N` with evidence pointing to simulation-report.md.
- Cumulative regression failure (any prior feature's `journey.spec.ts` failed against current build) → MAJOR finding under "## Reward-Hacking Findings" or a new `## Cross-Feature Regressions` section.
- Cross-runtime parity finding from SIMULATE Step 6 → CRITICAL or MAJOR per SIMULATE's verdict on it.

**Step 2b — Independent Playwright sanity (15-min cap).**

- Drive 1–2 most user-visible flows in the running app. Evaluator chooses based on:
  - FRs the Generator flagged as "Known Rough Edges" in implementation-report.md
  - Bug-vibe risk areas surfaced by code-quality review (Step 3)
- Ad-hoc edge cases simulation-report.md didn't explicitly cover (input length, special characters, rapid clicks, browser back/forward).
- This is "did SIMULATE lie or miss?" check — *not* full coverage replay. Spot-check, not regression.

The deleted "Test like a real user" prose (current `agents/evaluator.md:378-417`) moves into SIMULATE's mode prompt in C1, where it now applies authoritatively.

**Files affected:**
- `plugins/harness/agents/evaluator.md` (~**−80 LoC net**: Step 2 shrinks from ~80 lines to ~30 lines; the 80 lines deleted resurface inside SIMULATE per C1 — same content, new owner).

**Risk.**
- **Evaluator becomes too lenient if SIMULATE has bugs.** Fresh-context dispatch per R1 mitigates Generator-leniency bias, but a Generator-class bug in SIMULATE would now be invisible to Evaluator. Mitigation: Step 2b's spot-check is the safety net; Part A still binary-gates on FR verification rows.
- **Evaluator may rubber-stamp simulation-report's verdicts.** Anthropic-documented leniency-bias risk. Mitigation: existing anti-leniency protocol at `agents/evaluator.md:557-563` continues to apply ("If your evidence is 'it generally works' → subtract 2 points"); tuning-log captures divergence; user sees both reports in the human gate.
- **Step 2b's 15-min cap may be too permissive.** Evaluator could spend the cap re-driving the same flows SIMULATE already verified, returning no marginal value. Mitigation: prompt explicitly directs Evaluator to spot-check the *gaps* (Known Rough Edges, edge cases) — not the verified flows.

**Test.** Self-test 7 in § 10.2 (sprint where SIMULATE returns VERIFIED but the running app has a subtle bug — wrong button color, slow loading state. Verify Step 2b's spot-check catches it; verify Step 2a doesn't auto-PASS on SIMULATE's verdict).

**Ruler fit.**
- **#1 simplest — this is a NET REMOVAL.** The whole point of C6 is removing redundant work; net delta is a *removal* of ~80 LoC.
- **#2 stale-assumption** — Evaluator's "I run prod stack independently" assumption became stale the moment SIMULATE shipped.
- **#4 separation preserved** — Evaluator still independently judges; just stops re-doing the same runtime spin.
- **#6 verification weight** — this isn't a new verification leg; it's compressing the existing legs to remove duplication. Frees Evaluator capacity to focus on craft.

---

### Change 7 — sprint.md flow + manifest enum updates

**Problem.** Current sprint.md flow goes Step 3 BUILD → Step 4 EVALUATE. With SIMULATE inserted between, sprint.md needs a new step. Manifest's `state.phase` enum needs `simulating` value. Resume + rewind commands need to know about the new phase.

**Evidence.**
- `plugins/harness/commands/sprint.md` Steps 3–4 — current numbering.
- `plugins/harness/templates/manifest.yaml` `state.phase` enum — current values: `planning | analyzing | negotiating | building | evaluating | retrospective | complete | amending | clarifying | editing | tuning | constitution-amending`.

**Change.**

**(a)** `plugins/harness/commands/sprint.md` — insert new Step 3.5 between Step 3 (BUILD) and Step 4 (EVALUATE):

```markdown
## 3.5. Simulate — drive prod-mode runtime (automatic)

After Generator BUILD returns, the orchestrator updates `manifest.yaml →
state.phase = "simulating"` (Edit tool) and dispatches Generator in
SIMULATE mode via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Simulate ${FEATURE} via prod-mode Playwright"`
- **prompt** (passed verbatim):

> You are being dispatched in SIMULATE mode (see your system prompt's
> MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** [same boilerplate as Step 3]
>
> Drive the production-mode runtime through the contract's
> State-Transition AC + Negative-Path Coverage tables. Replay all prior
> features' tests/e2e/<NNN>/journey.spec.ts cumulatively. Write your
> verdict to .harness/features/${FEATURE}/simulation-report.md per
> template at @templates/features/simulation-report.md.txt with
> **Verdict**: VERIFIED | NEEDS-REPAIR header.
>
> Mandatory reads BEFORE driving:
> - .harness/features/${FEATURE}/contract.md (final, with new tables)
> - .harness/features/${FEATURE}/implementation-report.md
> - .harness/features/${FEATURE}/proposal.md
> - .harness/spec/prd.md § "User Journeys" + "UI-Surface Audit"
> - manifest.yaml → features.completed[] (which prior features to replay)

After dispatch returns:

1. Read `simulation-report.md`. Extract the `**Verdict**: VERIFIED | NEEDS-REPAIR` line.
2. **If VERIFIED:** orchestrator updates `state.phase = "evaluating"` and
   proceeds to Step 4 (Evaluator EVALUATE).
3. **If NEEDS-REPAIR:** for v3.0, **proceed to Step 4 anyway**. The
   Evaluator's Part A binary check will FAIL on the gap rows (per C6 Step
   2a), triggering the standard retry loop. Inner repair loop (auto-retry
   Generator BUILD with simulation-report context) deferred to v3.1 per N2.

   Rationale: keeping a single retry topology for v3.0 (SIMULATE flags →
   Evaluator FAIL → Generator retry) avoids compounding retry loops in the
   first release. If the latency cost proves painful in canary, promote N2
   to v3.1 or v3.2.
```

**(b)** `plugins/harness/templates/manifest.yaml` — add `simulating` to `state.phase` enum. New canonical sequence:

```yaml
state:
  phase: planning  # planning | analyzing | negotiating | building |
                   # simulating | evaluating | retrospective | complete |
                   # amending | clarifying | editing | tuning |
                   # constitution-amending
```

**(c)** `plugins/harness/commands/resume.md` — phase-specific recovery for `simulating`:

```markdown
- **`simulating`**: if `simulation-report.md` exists for the current feature,
  proceed to Evaluator (Step 4) — SIMULATE finished but orchestrator was
  interrupted before phase transition. If `simulation-report.md` is absent,
  re-dispatch Generator SIMULATE.
```

**(d)** `plugins/harness/commands/rewind.md` — `simulating` as a valid rewind target. Archives `simulation-report.md` to `.archive/TIMESTAMP/` per existing rewind pattern.

**(e)** `plugins/harness/skills/harness/SKILL.md` — Pipeline Timing table gains a row:

| Step | When it fires | Who triggers |
|---|---|---|
| Generator SIMULATE | After Generator BUILD returns successfully | auto |

**Files affected:**
- `plugins/harness/commands/sprint.md` (+~50 lines, new Step 3.5)
- `plugins/harness/templates/manifest.yaml` (+1 line, enum addition)
- `plugins/harness/commands/resume.md` (+~10 lines, new phase recovery branch)
- `plugins/harness/commands/rewind.md` (+~5 lines, new rewind target)
- `plugins/harness/skills/harness/SKILL.md` (+~5 lines, Pipeline Timing table row + flow diagram update)

**Risk.**
- **Manifest backward-compat.** Existing v2.x projects mid-sprint when v3.0 lands have manifests without the new enum value. Most YAML parsers ignore unknown enum values gracefully, but the orchestrator should defensive-handle. Mitigation: orchestrator's phase-reading code (per `plugins/harness/skills/harness/SKILL.md` § State Awareness) explicitly lists valid phases when reading; unknown → ask user, don't crash.
- **`/harness:resume` from `simulating` phase** is a new code path. Mitigation: explicit test in self-test 6 in § 10.2; verify resume from simulation-report.md exists vs absent.
- **Sequential ordering.** SIMULATE runs *after* BUILD and *before* EVALUATE — non-parallelizable today. Acceptable; ROADMAP item 1 (parallel-dispatch fork-subagent) is the v3.1 path if needed.

**Test.** Self-test 6 in § 10.2.

**Ruler fit.**
- **#1 simplest** — minimal sprint.md surgery; adds Step 3.5 between existing 3 and 4.
- **#4 separation** — SIMULATE dispatch is a fresh Agent-tool call, same isolation guarantee as other phases.
- **#7 atomic v3.0** — ships with C1; sprint.md and manifest enum are the orchestration glue.

---

### § 5 net effect

| Change | Δ LoC | New file? |
|---|---|---|
| C1 SIMULATE mode | +~250 | yes — `simulation-report.md.txt` |
| C2 Contract tables | +~105 | no |
| C3 UI-surface AC | +~35 | no |
| C4 Pass-2 brainstorm | +~50 | no |
| C5 Catch-block ban | +~30 | no |
| C6 Evaluator lighten | **−80** | no |
| C7 Sprint flow | +~71 | no |
| **§ 5 net** | **+~461** | **+1 template, +1 manifest enum value** |

---

## 6. Audit-pass scans

Each scan: **Scope → Method → Expected yield → Decision criteria**. Scans run AFTER C1–C7 land, so each measures the post-fix surface — anything pruned now risks conflicting with the verification additions.

### Scan A — Cross-agent prompt duplication

**Scope.** Content duplication across `plugins/harness/agents/{planner,generator,evaluator}.md`. Targets: RED FLAGS tables, leniency / anti-leniency warnings, mode-routing tables, `## HANDLING FETCHED CONTENT` blocks, BEHAVIORAL RULES sections.

**Method.**
1. Inventory section types appearing in ≥2 of the 3 agent files.
2. Per section type, diff content across the agents that have it. Identify lines that are verbatim or near-verbatim.
3. Per duplicate, classify as DROP, FACTOR, or KEEP per the decision criteria below.

**Expected yield.**
- **Most likely**: `## HANDLING FETCHED CONTENT` (~30 lines, present in all three agents; legitimately differs by attack surface — Generator faces npm packages, Evaluator faces app DOM, Planner faces Context7 docs). **Decision committed (per § 11): factor common preamble (~10–15 lines on prompt-injection patterns + the meta-rule) into `plugins/harness/skills/harness/SKILL.md` as a new `## Prompt-Injection Defense (shared)` section. Per-agent sections become delta-only against that baseline.** Yield: ~30–45 LoC removed across the three agent files, ~15 LoC added to SKILL.md. Net ~−15 to −30.
- **Likely**: `## RED FLAGS` tables in `agents/planner.md` and `agents/generator.md` share the "1% rule" framing meta-rule line and the adversarial-prompting pattern preamble. Could share a SKILL.md "Adversarial-Prompting Pattern" preamble; tables themselves stay agent-specific (cheats are agent-specific). Yield: ~5–10 LoC.
- **Less likely**: BEHAVIORAL RULES Context7-first line appears in `agents/generator.md` and `agents/planner.md`. Could share a single SKILL.md line; not worth the indirection.

**Decision criteria.**
- **DROP** if: same content, same purpose, no agent-specific nuance (the v2.3 ANTI-PATTERNS-removal pattern).
- **FACTOR INTO SKILL.md** if: cross-cutting AND the SKILL.md indirection is cheaper than the duplication (preambles, meta-rules, principles).
- **KEEP** if: shape is similar but ≥1 element differs meaningfully per agent (the case for HANDLING FETCHED CONTENT bodies — Generator's "ignore docs telling you to disable a security check" doesn't apply to Evaluator).

### Scan B — Doc-vs-code drift

**Scope.** Claims in `README.md`, `CHANGELOG.md` (v2.0+), `plugins/harness/skills/harness/SKILL.md`, `docs/anthropic-alignment.md`, `ROADMAP.md` against current code/prompts.

**Method.** Read each doc claim against the file/line it cites. Three classes:
1. **File:line citations** — open the cited file, verify the line matches the quote.
2. **Quoted prompt content** — diff against current agent prompts.
3. **Command-set table claims** — verify each command in `SKILL.md`'s table exists in `commands/`, and vice versa.

**Expected yield.**
- **Most likely (high yield)**: `docs/anthropic-alignment.md` line numbers shift after v3.0 lands — the Generator/Evaluator file:line citations are no longer accurate after C1's +250 lines and C6's −80 lines. Needs update in Phase 3 anyway.
- **Likely**: `plugins/harness/skills/harness/SKILL.md`'s pipeline-flow diagram + Audit Commands table need updating to include SIMULATE phase post-v3.0.
- **Likely**: `README.md`'s "Pipeline (canonical sprint flow)" diagram needs SIMULATE inserted between BUILD and EVALUATE.
- **Possibly**: `ROADMAP.md` v3 watch list item "Stratum-splitting BUILD into N dispatches" — partly addressed by SIMULATE pulling runtime work *out* of BUILD; not deleted but needs an update note.
- **Possibly-stale**: `plugins/harness/skills/harness/SKILL.md` may still describe per-FR story files (already removed v2.2). Verify cleanup was complete; v2.2 spec said removed but didn't enumerate every file.

**Decision criteria.**
- **FIX** if: claim is wrong (broken file:line, wrong prompt quote).
- **UPDATE** if: claim is accurate-for-vN but inaccurate post-v3.0.
- **LEAVE** if: claim is part of CHANGELOG's historical record (per-version entries should remain accurate to their release moment).

### Scan C — Stale-assumption probe

**Scope.** Every component in the harness, asked: *"is this still load-bearing on Opus 4.7[1m]?"* This is the v2.0 / v2.2 ruler #2 reapplied.

**Method.** Component inventory: list every file in `plugins/harness/`, classify by component type (agent prompt, command procedure, hook, template, doc). For each non-doc component:
1. What assumption does this encode? (e.g., `pre-tool-use.sh` test-file-deletion block encodes "Generator may try to `rm` a test file under retry pressure")
2. Does that assumption still hold given Opus 4.7[1m] capabilities + recent reality (BELCORT ACC v2 stress-test, no test-deletion incidents reported)?
3. What's the cost of removing this component? (Could the pipeline degrade silently? Could a Generator regress?)

**Expected yield.**
- **Likely-keep (assumptions still load-bearing):**
  - GAN isolation (`<SUBAGENT-CONTEXT>` blocks in all three agents) — Anthropic ruler #4
  - File-based comm — ruler #3
  - 4-criterion grading + calibration — Anthropic prescription
  - Reward-hacking scan + git archaeology Steps A–F (`agents/evaluator.md:444-481`) — Trustworthy Agents
  - 1M-context confirmation banner + sprint.md Step 0b — BELCORT ACC truncation incident proves load-bearing (and v3.0 makes it more so per § 8.2)
  - Pause-protocol "default if unanswered" anti-procrastination rule — Trustworthy Agents calibrated-uncertainty principle

- **Candidate for stress-testing (one component, conservative):**
  - **`pre-tool-use.sh` test-file-deletion hard-block.** Rationale: written when v1.5 reward-hacking scan was less mature; on Opus 4.7 with the prompt RED FLAGS table (`agents/generator.md:144-167`) + Evaluator's git-archaeology (`agents/evaluator.md:444-481` Steps A, B, C, E) + atomic-commit discipline, the hard-block is belt-and-suspenders. **Decision committed (per § 11): downgrade from hard-block to advisory warning.** The Evaluator's git-archaeology scan still catches actual test deletions; the hook becomes an advisory log entry in `progress/changelog.md` rather than a `pre-tool-use.sh` exit-2 block.
  - If canary surfaces a test-deletion incident, restore the hard-block in v3.1 patch. Reversible.

- **Likely-null result targets** (look but don't expect to find):
  - Planner Pass 2 feature-size gate (already advisory-only post-v2.2; no further action)
  - Generator's `## REWARD-HACKING — FORBIDDEN` section in `agents/generator.md:498-505` (already cross-ref-only post-v2.3; no further action)
  - 16-point self-validation in Planner (becoming 17-point with V17 added by C4; expansion not redundancy)

**Decision criteria.**
- **REMOVE** if: testably stale (component absent → BELCORT ACC v2 still passes) AND no documented bug class re-opens.
- **DOWNGRADE** if: assumption is partial (hard gate → advisory banner — the v2.2 Planner feature-size gate pattern, applied here to the test-file-deletion block).
- **KEEP** if: removal would re-open a bug class the source report already mapped (e.g., reward-hacking scan).

### Scan D — Manifest schema unused-fields

**Scope.** `plugins/harness/templates/manifest.yaml` — fields declared but no longer read by any agent or command.

**Method.**
1. List every field in `manifest.yaml` (`state.*`, `config.*`, `harness.*`, `features.*`, `constitution.*`).
2. For each field, `grep -rn '<field-name>'` across `plugins/harness/`. If zero reads outside the manifest itself, the field is dead.

**Expected yield.**
- **Likely-dead candidates** (verify by grep):
  - `config.observability.{heartbeat, poll_interval_seconds, rate_limit_seconds}` — v1.5 added; v2.0 removed the heartbeat code per CHANGELOG. Field may persist.
  - `harness.last_assumption_test` — v1.5 added for `/harness:assumption-test`; v2.0 removed the command. Field likely orphaned.
- **Likely-live**:
  - `constitution.amendments[]` — read by `/harness:constitution-amend`
  - `config.calibration_metrics.agent_checkins` — incremented by `commands/sprint.md` pause loop
  - `state.*` — read by orchestrator at every phase boundary
- **New in v3.0**: `state.phase` enum gains `simulating` (per C7).

**Decision criteria.** REMOVE if zero reads in current code. ANNOTATE in CHANGELOG if reads exist for migration purposes only — note for v3.1 removal.

### Scan E — Command-set redundancy review

**Scope.** 16 commands in `plugins/harness/commands/`. Question: does each answer a distinct question, or is one a near-duplicate of another?

**Method.**
1. Inventory all 16 commands per the SKILL.md table.
2. For each, write a one-sentence "what question does this answer?" (canonical: `plugins/harness/skills/harness/SKILL.md` already has this for the audit family).
3. Cluster by question type: lifecycle (sprint, quick, resume, brainstorm), spec-edit (clarify, amend, edit, constitution-amend), audit (analyze, validate, audit, retrospective), tuning (tune-evaluator), management (rewind, setup, doctor).
4. Per cluster, ask: do two commands have substantially overlapping questions?

**Expected yield.**
- **Likely null result.** v2.2 already dropped `/harness:negotiate`; the audit-family table in `SKILL.md:289-318` justifies the analyze/validate/audit/REVALIDATE/retrospective separation explicitly per Anthropic's "single-purpose tools" principle.
- **Low-confidence merge candidates** (worth probing, probably reject):
  - `/harness:analyze` (consistency) + `/harness:validate` (completeness) — both read spec/, but answer different questions per the SKILL.md mnemonic. Probably keep.
  - `/harness:audit` (debt) + `/harness:retrospective` (drift) — different time scopes (cross-feature historical vs single-feature post-build). Keep.
- **No new commands in v3.0**; SIMULATE is a Generator mode, not a slash command. Total stays at 16.

**Decision criteria.** MERGE only if two commands share a single question AND the audit-family table justification doesn't apply.

### § 6 net effect

| Scan | Predicted Δ LoC |
|---|---|
| A — cross-agent dupes | −15 to −30 (factoring) + balanced SKILL.md additions |
| B — doc drift | mostly text fixes; ~0 net |
| C — stale-assumption probe | −10 to −30 (test-deletion hook downgrade); else null |
| D — manifest dead fields | −5 to −15 |
| E — command-set redundancy | 0 (likely null result) |
| **§ 6 predicted net** | **−30 to −75** |

---

## 7. Implementation sequence

**Phase 1 — Verification gap (Changes C1–C7).** Order matters because of dependencies. The contract template must exist before SIMULATE has structured input to drive; the Evaluator delta requires SIMULATE to exist; sprint flow ties everything together.

```
C2 (contract State-Transition + Negative-Path tables) →
C3 (UI-surface AC clause) →
C4 (Planner Pass 2 brainstorming pass) →
C5 (constitution catch-block ban) →
C1 (SIMULATE mode + simulation-report.md template) →
C6 (Evaluator Step 2 lighten) →
C7 (sprint flow + manifest enum + resume + rewind)
```

C2–C4 land first because they define the structured input SIMULATE reads. C5 is independent and lands here for atomic. C1 reads C2–C4's output. C6 depends on C1 producing simulation-report.md. C7 wires the orchestration once all subagent prompts agree.

**Phase 2 — Audit scans (Scans A–E).** Run AFTER Phase 1 commits — measures the post-fix surface, not the pre-fix one.

```
B (doc drift — line numbers shifted by Phase 1; must fix anyway) →
A (cross-agent dupes — including the new SIMULATE prompt) →
D (manifest dead fields — quick grep) →
C (stale-assumption probe — judgment-heavy) →
E (command-set redundancy — likely null result, fastest)
```

**Phase 3 — Documentation + alignment updates.**
- Update `docs/anthropic-alignment.md` with new rows per § 9 (seven new rows mapping each verification change + each audit principle).
- Append v3.0 entry to `CHANGELOG.md` with full rationale + migration notes.
- Update `ROADMAP.md`: promote SIMULATE-related items to Shipped; demote items now obsoleted (the "Stratum-splitting BUILD" item now partially addressed by SIMULATE moving runtime out of BUILD).
- Update `README.md` Pipeline diagram + Recommended-launch section.

**Phase 4 — Canary stress-test.** Run `/harness:sprint "feature-004-canary"` on BELCORT ACC v2 (a real project with ≥3 prior features so cumulative regression actually exercises). Validate:
- SIMULATE phase fires correctly
- simulation-report.md emits with per-state-transition + per-negative-path rows
- Cumulative regression replays prior features' journey tests
- Evaluator EVALUATE reads simulation-report and lightens
- At least one bug class from the source report appendix would have been caught

If issues found: log to `.harness/progress/known-issues.md`; do not block v3.0 release unless blocker-class.

**Phase 5 — Release.** Single PR to `v2-beta` per ruler #7. After 1 successful canary sprint with no SIMULATE-class regressions, FF-merge `v2-beta` → `main` as `v3.0.0`. Tag.

Sequencing rationale:
- Phase 1 dependency order is internally coherent (templates → consumer → orchestration glue).
- Phase 2 after Phase 1 because audit measures the post-fix surface.
- Phase 3 after Phase 2 because the audit may surface doc-vs-code drift Phase 3 docs need to incorporate.
- Phase 4 BEFORE merge to `main` because canary on a real project surfaces issues that the test plan doesn't.
- Phase 5 atomic merge is the v3.0 commitment per ruler #7.

---

## 8. Operational considerations

### 8.1 File ownership preservation

No new orchestrator-edits-spec drift introduced by v3.0. New ownership rows for `plugins/harness/skills/harness/SKILL.md` File Ownership Contract:

| File | Writer |
|---|---|
| `features/NNN/simulation-report.md` | Generator SIMULATE |
| Contract State-Transition table — `Entity` / `From` / `To` / `Triggered by` columns | Planner Pass 2 |
| Contract State-Transition table — `Playwright test name` column | Generator NEGOTIATE |
| Contract Negative-Path table — `Constraint` / `Trigger scenario` / `Expected error` columns | Planner Pass 2 |
| Contract Negative-Path table — `Recovery test` column | Generator NEGOTIATE |
| `tests/e2e/<NNN-feature-name>/journey.spec.ts` | Generator BUILD (per per-feature TDD) |

Catch-block ban ships in canonical template only; existing projects' constitutions immutable per R4.

Updated `manifest.yaml → state.phase` enum is a state-transition field already owned by orchestrator; no new writer.

### 8.2 1M-context dependency *(elevated importance)*

SIMULATE adds one Generator dispatch per sprint. Cumulative regression cost compounds with shipped features — by feature 10, the SIMULATE dispatch is reading and exercising 10 prior `journey.spec.ts` files plus the current feature's transitions. Without [1m] launch, a 10-feature cumulative replay can exhaust the 200K context.

Implications:
- Doctor's 1M-context confirmation banner (v2.2) stays advisory — mechanical detection still blocked by Claude Code not exposing `--model` to plugin scripts (per v2.2 § 6.1).
- `commands/sprint.md` Step 0b user-confirmation prompt promotes from "recommended" to a stronger "required for projects with ≥5 shipped features" — soft escalation matching the cost curve.
- `ROADMAP.md` item "Mechanical 1M-context detection from doctor.sh" elevates from low-priority to medium (because the operational cost of forgetting now compounds across SIMULATE + BUILD, not just BUILD).

In-flight detection: Generator SIMULATE emits a `## Resource Warnings` section in `simulation-report.md` if turn count exceeds 800 OR token usage exceeds 700K mid-dispatch. Informational; does not block the pipeline. Future v3.1 may use this signal to auto-degrade cumulative regression to the most recent N features.

### 8.3 Backward compatibility

Existing v2.x projects upgrading to v3.0:
- **Manifest enum**: existing manifests don't include `simulating` in `state.phase` enum. Orchestrator's phase-reading code (per `plugins/harness/skills/harness/SKILL.md` § State Awareness) defensive-handles unknown values: lists valid phases when reading; on unknown, asks user, does not crash.
- **Existing contracts** (without State-Transition / Negative-Path / UI-surface tables): sprint can proceed; Evaluator REVIEW-PROPOSAL would fail Part A on missing tables, but that's only on NEW sprints. Mid-build v2.x sprints continue without these gates (graceful migration). New sprints produce the tables.
- **Existing constitutions** don't have catch-block ban: preserved per R4 (immutability). Users opt-in by running `/harness:constitution-amend` with the new principle as the amendment.
- **No automatic migration**: users opt-in by running new sprints. CHANGELOG v3.0 entry documents migration path.

### 8.4 SIMULATE failure modes

What goes wrong in SIMULATE and what to do:

| Failure | Detection | Surface to user |
|---|---|---|
| `pnpm build` non-zero exit | exit code | simulation-report.md `## Build failure` section; `**Verdict**: NEEDS-REPAIR`; Evaluator Part A FAIL → standard retry |
| Server port conflict (`pnpm start` cannot bind) | 30s bind timeout + 1 retry | `## Infrastructure failure`; orchestrator may pause for user (analogous to v2.1.9 setup-required gate) |
| Worker startup needs missing env | startup throws on missing env var | analog of v2.1.9 setup gate; SIMULATE pauses, orchestrator surfaces required env to user |
| Cumulative regression flake (passes 4/5 retries) | per-test retry budget | MAJOR finding under `## Cumulative Regression Flakes`; Evaluator decides whether to fail. Healer pattern (N3) deferred. |
| DB query gives unexpected state | per-row Partial-runtime-gap with DB state evidence | per-FR row in simulation-report.md; Evaluator EVALUATE Step 2a picks up; Part A FAIL |
| Stack tear-down fails | killed-process signal mismatch | log to `progress/changelog.md`; not blocking — next SIMULATE will re-spin clean |

---

## 9. `docs/anthropic-alignment.md` updates

Seven new rows in the decision map. Verbatim quotes pulled from the same three sources cited throughout (Rajasekaran 2026, Effective Harnesses, Trustworthy Agents):

| BELCORT decision (v3.0) | Source | Specific quote or principle |
|---|---|---|
| Generator SIMULATE mode (v3.0) | Effective Harnesses | *"Claude mostly did well at verifying features end-to-end once explicitly prompted to use browser automation tools."* Operationalised as a mandatory pre-Evaluator runtime-verification phase per ruler-aligned anti-rec 10.1 (no 4th agent). |
| Per-state-transition AC + Negative-Path tables (v3.0) | Rajasekaran 2026 | *"Each criterion had a hard threshold, and if any one fell below it, the sprint failed."* Extended to per-transition test coverage in addition to the 4 quality criteria. |
| Cumulative regression replay in SIMULATE (v3.0) | Rajasekaran 2026 | *"We prompt coding agents to edit this file only by changing the status of a `passes` field."* Extended cross-feature: regression replay enforces that per-feature `passes` claims remain valid in the presence of subsequently-shipped features. |
| Planner Pass 2 brainstorming pass (v3.0) | Trustworthy Agents | *"Models are trained through scenarios that place Claude in ambiguous situations."* Operationalised at spec-time on UI-observability ambiguities (closes Bug #8 class before contract negotiation). |
| Constitution catch-block ban (v3.0) | Trustworthy Agents | *"Multi-layer defenses: train the model, monitor production, red-team battle test."* Production observation surfaced Bug #6 class; constitution principle is the train-the-model layer. |
| Evaluator EVALUATE Step 2 lightening (v3.0) | Rajasekaran 2026 | *"Stripping away pieces that are no longer load-bearing."* Evaluator's prod-stack work staled the moment SIMULATE shipped. |
| Cross-runtime parity check folded into SIMULATE Step 6 (v3.0) | Effective Harnesses | *"Visual feedback (screenshots via Playwright for UI tasks)."* Extended to dev-vs-prod cross-runtime parity to catch Bug #2 class. |

---

## 10. Risk + test plan

### 10.1 Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | SIMULATE's cumulative regression cost grows linearly. By feature 20, single dispatch may approach 15–20 min. | Per Q3 = S2 acceptance; healer pattern (N3) parked; if real, address in v3.1 with parallel-dispatch (`ROADMAP.md` v3 item 1). |
| R2 | Generator-as-its-own-verifier may produce lenient evidence in SIMULATE. | Fresh-context dispatch per R1 mitigates Generator-leniency bias; Evaluator EVALUATE Part A still binary-gates; tuning-log captures divergence; SIMULATE produces *behavioural evidence*, not *judgment*. |
| R3 | SIMULATE failure modes (stack-up, port-bind, worker-startup) unfamiliar to existing users. | simulation-report.md verdict header + clear-language failure sections; orchestrator surfaces with `--- SIMULATE FAILURE ---` marker analogous to v2.1.9 setup-required gate. |
| R4 | Existing v2.x projects' constitutions don't have catch-block ban. | Per R4 ratification: users opt-in via `/harness:constitution-amend`. CHANGELOG v3.0 documents migration path. |
| R5 | Phase 2 audit may discover that some Phase 1 changes introduced their own duplication (e.g., SIMULATE prompt content overlapping BUILD). | Phase 2 measures against post-fix surface explicitly. Yield prediction includes both directions. |
| R6 | 1M-context dependency becomes load-bearing post-v3.0 in a way it wasn't before. | sprint.md Step 0b confirmation prompt strengthens (per § 8.2); ROADMAP "Mechanical 1M-context detection" elevated. In-flight resource warnings emit if turn-count or token-usage thresholds exceeded. |
| R7 | Catch-block grep produces false positives on multi-line catch blocks. | Per § 5 C5 implementation note: use multiline-aware regex; document false-positive disclosure if used; fall back to literal report regex if multiline approach surfaces too many false positives. |

### 10.2 Test plan

**Self-tests (pre-canary, on greenfield projects):**

- **ST1 — greenfield SIMULATE smoke test.** `/harness:sprint "build a 2-FR todo with done-status the user can toggle"` on a fresh project. Verify:
  - Contract has State-Transition AC table with `todos.status` rows
  - Contract has UI-surface AC (per C3)
  - PRD has UI-Surface Audit section (per C4)
  - SIMULATE phase fires after BUILD
  - simulation-report.md emits with per-state-transition rows
  - Cumulative regression skipped (no prior features)
  - Evaluator EVALUATE Step 2 lightens correctly (reads simulation-report, runs spot-check, doesn't re-spin prod stack)

- **ST2 — cumulative regression activation.** After ST1 passes, `/harness:sprint "add a delete-todo action that removes from the list"`. Verify:
  - SIMULATE replays ST1's `tests/e2e/001-*/journey.spec.ts`
  - If delete logic accidentally breaks list-render, regression catches it
  - simulation-report.md cumulative regression section lists ST1's feature with verdict

- **ST3 — NEEDS-REPAIR path.** Seed BUILD with a known stub (e.g., extraction handler always returns null). Verify:
  - SIMULATE flags Partial-runtime-gap on the relevant FR
  - simulation-report.md verdict is NEEDS-REPAIR
  - Evaluator EVALUATE Part A FAILs on the gap row
  - Standard retry loop fires; Generator BUILD re-dispatched with eval-report context

- **ST4 — negative-path coverage.** Seed unique-constraint table, then trigger duplicate insert. Verify:
  - SIMULATE Step 4 catches transaction-abort
  - Recovery test in Negative-Path Coverage row drives recovery scenario
  - simulation-report.md per-negative-path row reports correctly

- **ST5 — catch-block ban.** Write `try {...} catch {}` in source. Verify:
  - Evaluator EVALUATE Step 3 grep files CRITICAL finding
  - Generator's next retry must remove or fix the catch
  - Re-evaluation passes after fix

- **ST6 — resume from `simulating` phase.** Hard-stop after BUILD before SIMULATE finishes. `/harness:resume`. Verify:
  - Resume picks up `state.phase == "simulating"`
  - If `simulation-report.md` absent: re-dispatches Generator SIMULATE
  - If `simulation-report.md` present (test by manually creating a partial one): proceeds to Evaluator

- **ST7 — Evaluator catches SIMULATE-missed bug.** Sprint where SIMULATE returns VERIFIED but the running app has a subtle bug not covered by the State-Transition table (e.g., wrong button color, slow loading state visible in the spot-check). Verify:
  - Step 2b's 15-min spot-check catches it
  - Step 2a doesn't auto-PASS on SIMULATE's verdict
  - Evaluator's verdict differs from SIMULATE's; tuning-log captures divergence

**Canary test (Phase 4):** `/harness:sprint "feature-004"` on BELCORT ACC v2.

Pass criteria:
- SIMULATE phase fires successfully
- simulation-report.md emits per the new template
- Cumulative regression replays features 001 + 002 + 003
- At least one bug class from the source report appendix would have been caught (S3 stub, transaction abort, status-not-extracted, review-queue-stuck)
- False-positive rate on legitimate work <10% (a "false positive" = SIMULATE flagging Partial-runtime-gap on an FR that human review confirms is correctly working)

**Rollback.** v3.0 is single-PR atomic to `v2-beta`. If canary surfaces a blocker:
- `git revert <PR-merge-commit>` returns the branch to v2.3.0 baseline
- No partial state to clean up (nothing to migrate; nothing was written to existing projects' `.harness/` outside per-feature folders)
- Existing projects with new-style contract tables continue to work because the contract is per-feature; the rolled-back orchestrator simply ignores the new tables

---

## 11. Open questions

Empty. Q1–Q4 all answered (see § 4); mechanical ratifications R1–R5 confirmed.

**Two implementation-time judgment calls** explicitly committed to here, made during the brainstorming process:

- **Scan A → factor `HANDLING FETCHED CONTENT` preamble into `plugins/harness/skills/harness/SKILL.md`** (per § 6 Scan A). Default committed: yes, factor common preamble; per-agent sections become delta-only against the SKILL.md baseline. If Phase 2 finds the indirection costs more than the saved duplication (e.g., the per-agent deltas grow large enough that the SKILL.md anchor doesn't pay), abort the factoring and document in CHANGELOG v3.0 as "considered, rejected — kept duplication for resilience to SKILL.md changes."

- **Scan C → downgrade `pre-tool-use.sh` test-file-deletion hard-block to advisory** (per § 6 Scan C). Default committed: attempt the downgrade per ruler #2 (assumption testably stale on Opus 4.7 with the prompt RED FLAGS table + git-archaeology scan + atomic-commit discipline). The Evaluator's git-archaeology Steps A, B, C, E continue to scan for the same patterns; the hook becomes advisory log entry in `progress/changelog.md` rather than a `pre-tool-use.sh` exit-2 block. If canary (Phase 4) surfaces a test-deletion incident, restore the hard-block in v3.1 patch. Both the downgrade and the restore are reversible.

Both decisions align with the v2.0 / v2.2 / v2.3 reduction discipline (ruler #1 + ruler #2). Both are surfaced explicitly here so the implementation plan in Phase 2 has clear instructions; neither is gated on additional user input.
