# BELCORT Harness — Audit & Refine (Design Spec)

**Date**: 2026-04-28
**Author**: BELCORT (tao@belcort.com)
**Target model**: `claude-opus-4-7[1m]` (1M context variant — see §6.1)
**Refactor scope**: post-v2.1.9 stale-assumption pruning + operational hardening. Six changes, one PR, ~5 hours of focused work, ~300 LoC net reduction.
**Predecessor**: `2026-04-21-belcort-v2-minimalist-refactor-design.md` (the v2.0 minimalist refactor). This spec extends the same logic — stripping pieces no longer load-bearing on a more capable model — to four targets the v2.0 pass preserved or that v2.1.x patches grew.

---

## 1. Context & Motivation

The user (BELCORT, framework author) ran a multi-stratum sprint (`001-foundation-and-ingestion`) and observed Generator BUILD truncate at **178 tool uses, 347.5 k tokens, 36 minutes** with no `implementation-report.md`. Recovery via re-dispatch worked, but the failure surfaced two structural questions:

1. **Was the dispatch on the 1M context window?** The agent frontmatter declares `model: inherit`, which (per `README.md:392`) silently picks the default 200K Opus variant unless Claude Code was launched with `claude --model claude-opus-4-7[1m]`. The token count (347.5 k > 200 k) suggests the budget was exhausted, not the context.
2. **Is the framework still aligned with Anthropic's "every component encodes an assumption that may go stale" principle on Opus 4.7?** The v2.0 refactor (2026-04-21) removed ~900 LoC of v1.x defensive machinery. v2.1.x added back ~700 LoC across nine patch releases (per CHANGELOG). Some of that growth is genuine (worktree contract clarifications, secrets handoff); some encodes assumptions that are testable-and-stale on Opus 4.7.

This spec applies the v2.0 ruler to four targets that survived v2.0 plus two operational hardening items.

### Anti-goal

Not a redesign. Not new features. Not a paradigm shift. The goal is the same minimalist instinct as v2.0, applied to v2.1.x's growth.

---

## 2. The Ruler (verbatim Anthropic + user-stated constraints)

Same ruler as the v2.0 spec, restated for traceability:

1. *"Find the simplest solution possible, and only increase complexity when needed."* — Rajasekaran 2026
2. *"Every component in a harness encodes an assumption… those assumptions are worth stress testing… they can quickly go stale as models improve."* — Rajasekaran 2026
3. *"Communication was handled via files."* — Rajasekaran 2026
4. *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* — Rajasekaran 2026 (GAN isolation, non-negotiable)
5. *"Continuous-session on modern models."* — Rajasekaran 2026 (*"With Opus 4.6 I dropped context resets from this harness entirely."*)

**User-stated constraints (this round):**

6. **Trust the model.** No hard-blocking Planner size gate. Soft signals okay.
7. **No user-facing command surface reduction.** SKILL.md indexing + auto-invocation already solve discoverability. The 17 commands stay (one exception: §5).
8. **Single source of truth per fact.** Carryover from v2.0; tighter enforcement this round.
9. **One PR, atomic merge.** Anthropic-style minimalist refactor, not a patch series.

---

## 3. Goals & Non-goals

### Goals

- G1. Eliminate the duplication between per-FR story files and the aggregate contract.
- G2. Pin the operational foundation: ensure subagents actually run on the 1M-context variant.
- G3. Reduce Planner system-prompt size by ~400 LoC via mode collapse, without changing user-facing commands.
- G4. Tighten state safety at the Generator pause boundary.
- G5. Drop one redundant standalone command (`/harness:negotiate`) without losing the procedure.
- G6. Confirm the soft-only Planner size signal aligns with the "trust the model" stance and isn't being misread as a hard gate.

### Non-goals (deferred to v3 watch list)

- N1. Stratum-splitting BUILD into N dispatches. Premature on confirmed-1M sessions; revisit only if truncation recurs after Change #1.
- N2. Pause-mechanic full unification (Planner AskUserQuestions vs Generator pause-questions.md). The asymmetry is correct — Planner is interactive discovery, Generator is long-running autonomy. Tighten state, don't unify.
- N3. Audit-family merge (`/analyze`, `/validate`, `/audit`, `/retrospective`, `REVALIDATE`). Each answers a distinct question per `SKILL.md:289-318`. Mnemonic table is the right fix and is already there.
- N4. Mechanical 1M-context detection from doctor.sh. Claude Code does not currently expose `--model` reliably to plugin scripts; user-confirmation banner is the Anthropic-aligned fix.
- N5. Per-agent model pinning. Already removed in v2.0 for unused-and-undocumented; not reintroducing.

---

## 4. The six changes

Sequenced by leverage / risk; suitable to land in this order within a single PR.

### Change 1 — Doctor 1M-context confirmation gate + README launch banner

**Problem.** The token budget your incident hit (347.5 k) exceeded the default Opus context (200 k). The 1M variant is documented at `README.md:392` but buried in the v2.1.7 status entry — easy to miss. Agent frontmatter `model: inherit` silently inherits the wrong variant if the parent session wasn't started with the [1m] flag.

**Why detection-not-confirmation fails.** Investigated three mechanisms (see §6.1). Only user-confirmation is reliable today. Mechanical detection requires Claude Code to expose `--model` to plugin scripts; it doesn't.

**Change.**

- `plugins/harness/scripts/doctor.sh` gains a new CRITICAL check named "1M context window — user confirmation". The check prints a banner with the current launch flag (if discoverable from env) and the recommended flag, then sets a STATE marker. The check itself is non-blocking (always passes) — its purpose is the banner, not the verdict. Future Claude Code versions that expose `--model` could promote it to a real check.
- `plugins/harness/commands/sprint.md` Step 0 gains a one-line user-facing prompt: *"This sprint dispatches Generator BUILD which can run 30+ minutes on multi-stratum work. Confirm Claude Code was launched with `claude --model claude-opus-4-7[1m]` for the 1M-context variant. (Y to proceed / N to relaunch.)"* Same prompt added to `commands/quick.md` Step 0 with a softer ask (quick is short).
- `README.md`: promote the 1M-launch flag from the v2.1.7 status entry to a top-level "Recommended launch" section under Quick Start. Reference it from the Troubleshooting section.

**Files affected.**
- `plugins/harness/scripts/doctor.sh` (+~25 lines)
- `plugins/harness/commands/sprint.md` (+~5 lines, before §0 doctor invocation)
- `plugins/harness/commands/quick.md` (+~3 lines)
- `README.md` (+~10 lines under Quick Start)

**Risk.** Zero. Adds a banner; doesn't change pipeline logic.

**Test.** Run `bash scripts/doctor.sh` and verify the new banner appears. Run `/harness:sprint "demo"` in a Claude Code session and verify the confirmation prompt appears before doctor invocation.

---

### Change 2 — Drop per-FR story files

**Problem.** Per-FR story files (`features/NNN/stories/FR-NNN.md`) duplicate the aggregate contract with brittle hash-check enforcement.

**Evidence of duplication and brittleness.**
- `agents/planner.md:516` — invariant: *"stories must NEVER drift from the aggregate contract."*
- `agents/planner.md:519-525` — authoring rules forbid paraphrasing; ID-reference everything.
- `agents/planner.md:525` — *"The Evaluator (in EVALUATE mode) hash-checks each story's FR text against the aggregate contract. Drift = build fails."*
- `agents/evaluator.md` (read end-to-end) — **no hash-check step actually exists**. The Evaluator's EVALUATE workflow (Steps 1–7) does Spec Validation against `contract.md` only. The hash-check is a Planner-asserted invariant with no enforcing code. v2.x inconsistency.

**Why the assumption has staled.**
- BMAD V6's claim (planner.md:514): per-cycle reasoning improves when context is scoped to one FR vs the full bundled contract.
- Reality on Opus 4.7[1m]: a 10-FR contract is ~8 k tokens out of 1 M. Scoping is irrelevant.
- The actual Generator behavior (`generator.md:392` rule 2) reads the story per cycle, with fall-back to the aggregate contract if the story is missing — meaning the contract is already the source of truth; the story is a per-cycle index that grep can produce on demand.

**Drift-on-amend hazard.**
- `/harness:amend "FR-003 also accepts CSV"` → patches `contract.md`, does NOT auto-cascade to `stories/FR-003.md`. Per planner.md:525 invariant, the next BUILD cycle is supposed to fail on hash mismatch. Spurious failure for a user-authorized amendment. The hash-check is *de facto* unimplemented (per evaluator.md), so the failure currently doesn't fire — meaning the documented contract and the running behavior already disagree.

**Change.**

- `agents/planner.md`: remove §"Story Files (FR-4) — per-FR build artifacts" (planner.md:510-543). Remove story-related rows from the File Placement Summary table (planner.md:579-589). Remove story-related lines from the "Also Create" list and the 16-point self-validation (V-checks don't currently reference stories — verify on revision).
- `agents/generator.md`: rewrite Phase 2 rule 2 to read: *"Per-FR section read per cycle. Before each FR's RED step, locate the FR's section in `.harness/features/${FEATURE}/contract.md` (use grep on the FR-NNN ID) — that's your canonical per-cycle context. The aggregate contract is the source of truth; per-FR scoping is your responsibility per cycle."*
- `agents/evaluator.md`: confirm no removal needed (the hash-check section doesn't exist; the Spec Validation step in evaluator.md:535-547 already targets contract.md, which is correct).
- `commands/sprint.md`: remove the per-FR-story line from the Generator BUILD dispatch prompt (sprint.md:202: `> - .harness/features/${FEATURE}/stories/*.md`).
- `templates/features/story.md.txt`: delete.
- `plugins/harness/skills/harness/SKILL.md`: remove story file row from File Ownership Contract (SKILL.md:101) and Template Index (SKILL.md:436).
- `README.md`: remove story references from Pipeline section + Directory layout (README.md:288, README.md:296).

**Files affected.**
- `agents/planner.md` (~50 lines removed)
- `agents/generator.md` (~5 lines changed, no removal)
- `commands/sprint.md` (~2 lines removed)
- `templates/features/story.md.txt` (deleted, ~50 lines)
- `skills/harness/SKILL.md` (~5 lines removed)
- `README.md` (~3 lines removed)
- Net: ~115 LoC reduction.

**Risk.** Low. The story files were a soft addition (fall-back to contract was already documented). The "drift = build fails" rule was unenforced.

**Migration note.** Existing projects that already have `stories/` folders: these are read-only in the current codebase from this PR forward. They can be deleted manually; the harness ignores them. Document this in CHANGELOG.md.

**Test.**
- Greenfield `/harness:sprint` produces no `stories/` directory.
- Brownfield project with existing `stories/`: Generator BUILD reads contract.md FR sections successfully without referencing stories.
- `/harness:amend "FR-003: now also accepts CSV"` patches contract.md; subsequent BUILD reads the amended FR section without spurious drift failure.

**Anthropic alignment.** Direct quote: *"every component encodes an assumption that may go stale as models improve."* The story-file scoping assumption has staled.

**Contradiction with v2.0 spec.** The v2.0 design spec preserved per-FR stories explicitly (`docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md:112`). This change reverses that decision. The justification: v2.0 was on Opus 4.6 with 200 k context, where per-FR scoping had measurable benefit. Opus 4.7[1m] absorbs the full contract trivially. The same "every component encodes an assumption" rule that drove v2.0's removals applies here — applied a model-generation later.

---

### Change 3 — Generator pause `state.current_task` snapshot hardening

**Problem.** When the Generator writes `pause-questions.md` (generator.md:339-349) and exits, the orchestrator collects answers and re-dispatches a fresh Generator. The fresh Generator reads `state.current_task` from `manifest.yaml` (generator.md:307: *"Resuming build from FR-NNN"*) — but `state.current_task` is updated **after each commit**, not at pause time (generator.md:394-403). If the user runs **anything else** between pause and re-dispatch (`/harness:amend`, `/harness:audit`, an unrelated `/harness:resume` from another worktree, etc.), `state.current_task` may move. The fresh Generator then resumes from a different FR than the paused one was working on.

In practice the failure window is narrow (most users answer pause questions and proceed immediately). But the contract is loose, and the symptom is silent: the wrong FR runs, the previously-half-done FR is forgotten until a Spec Validation step catches it.

**Change.**

- `agents/generator.md` Phase 1.5 step 4: when writing `pause-questions.md`, also snapshot the current state inline. Add this section to the pause-questions.md template:

```
## State at pause (Generator-authored)
- Current FR: FR-NNN
- Last completed FR: FR-MMM (or "none" if pause is pre-first-FR)
- Last commit SHA: <short>
- Working tree status: <clean | dirty (N files staged, M unstaged)>
- ISO timestamp: <UTC timestamp>
```

- `templates/features/pause-questions.md.txt`: add the State at pause section template.
- `commands/sprint.md` §3a: when re-dispatching, the orchestrator includes the State at pause section verbatim in the dispatch prompt under a `--- PAUSE STATE SNAPSHOT (authoritative — use this over manifest if they disagree) ---` marker.
- `agents/generator.md` Phase 1 Orient: rule 3 (mid-build recovery) gains a sentence: *"If the dispatch prompt contains a `--- PAUSE STATE SNAPSHOT ---` block, prefer its values over manifest.yaml's `state.current_task` for resume orientation. The snapshot reflects state at pause time; the manifest may have moved due to interleaving commands."*

**Files affected.**
- `agents/generator.md` (+~15 lines, ~3 lines changed)
- `templates/features/pause-questions.md.txt` (+~10 lines)
- `commands/sprint.md` (+~5 lines in §3a re-dispatch prompt assembly)

**Risk.** None. Adds redundant state; orchestrator and agent prefer the more-authoritative source.

**Test.**
- Trigger a pause mid-FR-3; before answering, run `/harness:audit` (which doesn't move state.current_task, but verifies state-read works); answer the pause; verify Generator resumes at FR-3 specifically.
- More aggressive: after pause, manually edit manifest.yaml `state.current_task: FR-007`; answer the pause; verify Generator resumes at FR-3 (snapshot wins) and logs the manifest discrepancy.

**Anthropic alignment.** *"Use structured files to carry previous agent state and next steps across context boundaries."* The pause snapshot is exactly that — file-based state at the boundary, not state inferred from a globally-mutable file.

---

### Change 4 — Planner internal mode collapse (6 → 3 modes; user-facing commands unchanged)

**Problem.** `agents/planner.md` is 1,124 lines, of which ~600 lines are mode sections (CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND). The post-PLAN modes share ~95% of their procedure: read context → parse user change-request → write surgical patches to a `*-patches.md` file → exit without applying. Only differences: the patches file name, the marker the orchestrator uses in dispatch, and a few mode-specific constraints (AMEND can't touch constitution; CONSTITUTION-AMEND can only touch constitution; etc.).

Three duplications today:
- Patch discipline (≥3 lines context, surgical not whole-section, preserve IDs) repeated 4× across mode sections.
- Mode-specific constraints stated in BOTH planner.md mode sections AND the command files' dispatch prompts.
- Anti-patterns lists largely overlap (silently dropping items, rewriting whole sections, touching files outside scope).

**Why this matters.**
- Planner system prompt loads slower (~400 LoC of avoidable content).
- More text for Claude to triage when picking the right behavior — competing instructions slow reasoning.
- Maintenance: changing patch discipline (e.g., raising context lines from 3 to 5) requires touching 4 places today.
- Drift between planner.md mode sections and command file dispatch prompts is already present (e.g., constitution-amend mode in planner.md doesn't restate every gate from constitution-amend.md).

**Change.**

`agents/planner.md` collapses post-PLAN modes into a single `EDIT` mode that reads the dispatch-prompt marker to determine sub-behavior. The four sub-markers handled:

| Sub-marker | Sub-behavior | Patches file (set by orchestrator) | Special constraints |
|---|---|---|---|
| `--- AMENDMENT REQUEST ---` | Single-file targeted spec tweak | `features/NNN/amend-patches.md` | Single file expected; never touch constitution.md |
| `--- EDIT REQUEST ---` | Cascade-aware multi-file edit | `features/NNN/edit-patches.md` (or top-level) | Multi-file expected; never touch constitution.md; verify NFR feasibility via Context7 if stack changes |
| `--- CLARIFY ANSWERS ---` | Apply user-answered clarifications | `features/NNN/clarify-patches.md` | Touches only spec/ + contract.md |
| `--- CONSTITUTION AMENDMENT ---` | Constitution-only patch | `.harness/constitution-amend-patches.md` (top-level, global) | Only touches constitution.md; testable form required; preserve §-numbers |

Other modes:
- `PLAN` — unchanged.
- `CLARIFY-QUESTIONS` — stays separate. Different output (questions, not patches); different mental model (audit ambiguity, don't apply changes).
- `REVALIDATE` — stays separate. Different output (per-principle compliance report, not patches); different reads (NEW constitution + per-feature contract).

**Final mode count: 4** (PLAN, EDIT, CLARIFY-QUESTIONS, REVALIDATE), down from 6. Net Planner LoC reduction: ~400.

**Where mode-specific constraints move (single source of truth).**

Each user-facing command file (`commands/amend.md`, `commands/edit.md`, `commands/clarify.md`, `commands/constitution-amend.md`) authors the dispatch prompt with the mode-specific constraints inline:

```markdown
> You are being dispatched in EDIT mode.
> Marker: AMENDMENT
> Patches file: .harness/features/${FEATURE}/amend-patches.md
> Constraints (AMENDMENT-specific):
>   - Single file expected; if cascade needed, return UNCLEAR and recommend /harness:edit
>   - NEVER patch spec/constitution.md (route via OUT-OF-SCOPE → /harness:constitution-amend)
>   - Preserve all IDs (FR-NNN, NFR-NNN, etc.)
> User request:
> $ARGUMENTS
> [--- CONTEXT --- block follows]
```

`agents/planner.md` EDIT mode is mode-agnostic:
- Read the marker. Read the constraints stated in the dispatch.
- Read the spec context.
- Produce surgical before→after patches in the file the dispatch names.
- Write UNCLEAR / OUT-OF-SCOPE sections per the existing patch-file template.
- Exit. Never apply, never touch source.

**Files affected.**
- `agents/planner.md` (~400 lines removed; ~50 lines added for the unified EDIT mode procedure)
- `commands/amend.md` (~10 lines added — mode-specific constraints inlined into dispatch prompt)
- `commands/edit.md` (~15 lines added — same pattern)
- `commands/clarify.md` (~10 lines added — same pattern; CLARIFY-APPLY half of the procedure now uses EDIT mode with CLARIFY ANSWERS marker)
- `commands/constitution-amend.md` (~15 lines added — same pattern)
- `skills/harness/SKILL.md`: update mode list (SKILL.md mentions Planner modes in passing — verify on revision)

Net LoC: ~350 reduction.

**Risk.** Medium. Touches every spec-edit command file. Mitigation: each command file's procedure (orchestrator-side ceremony, gates, user confirmations) stays unchanged — only the dispatch prompt assembly is updated. Test plan covers each command's happy path.

**Test.**
- `/harness:amend "FR-003: now case-insensitive"` → produces amend-patches.md with the right shape; orchestrator applies; analyze passes.
- `/harness:edit "swap PostgreSQL to SQLite"` → produces edit-patches.md with patches across architecture.md + init.sh + relevant NFR section; orchestrator applies file-by-file; analyze + validate pass.
- `/harness:clarify` → CLARIFY-QUESTIONS produces clarifications.md (separate mode, untouched); user answers; orchestrator dispatches Planner EDIT mode with CLARIFY ANSWERS marker → produces clarify-patches.md; orchestrator applies.
- `/harness:constitution-amend "<reason ≥50 chars>"` → all 5 ceremony gates fire (in commands/constitution-amend.md, unchanged); inner Planner dispatch uses EDIT mode with CONSTITUTION AMENDMENT marker → produces constitution-amend-patches.md.

**Anthropic alignment.**
- *"Find the simplest solution possible…"* — collapse code-level duplication.
- Agent tool design pattern: agent.md system prompt = stable role; dispatch `prompt` parameter = per-task constraints. v2.x conflated the two; this change separates them cleanly.

---

### Change 5 — Drop `/harness:negotiate` standalone command

**Problem.** `/harness:negotiate` (commands/negotiate.md, 54 lines) is almost never user-invoked. Its three documented use-cases (commands/negotiate.md:13-15):
1. *"`/harness:resume` landed on phase 'negotiating' after session interruption"* — handled by `/harness:resume`'s phase routing, doesn't need a standalone command.
2. *"You edited the draft contract and want to re-negotiate"* — handled by `/harness:rewind negotiating` (existing).
3. *"Previous negotiation was escalated to human and you now want to restart it"* — same as case 2.

The procedure itself (Generator NEGOTIATE → Evaluator REVIEW-PROPOSAL → Generator FINALIZE-CONTRACT, ≤3 rounds) is canonically defined in `commands/sprint.md:127-167`. `commands/negotiate.md` largely re-points at sprint.md.

**Change.**

- Delete `plugins/harness/commands/negotiate.md`.
- Move the 3-round-cap rationale and escalation-to-human procedure (`commands/negotiate.md:34-42`) into `commands/sprint.md` §2c (where the procedure is already partially documented). Keep the procedure as-is — only the standalone front door is removed.
- `commands/resume.md` already references SKILL.md § Recovery for phase-`negotiating` handling. Verify the Recovery section in SKILL.md correctly describes the procedure inline (it does — SKILL.md:393-395).
- README.md: remove `/harness:negotiate` from the Phase management + lifecycle table (README.md:148).
- SKILL.md: remove the `/harness:negotiate` row from the Commands table (SKILL.md:35).

**Files affected.**
- `plugins/harness/commands/negotiate.md` (deleted, 54 lines)
- `plugins/harness/commands/sprint.md` (+~10 lines — escalation-to-human procedure inlined)
- `plugins/harness/skills/harness/SKILL.md` (~3 lines removed)
- `README.md` (~2 lines removed)

Net LoC: ~45 reduction. User-facing command count: 17 → 16.

**Risk.** Low. The procedure is preserved; only the standalone command is removed. Users hitting Recovery from `negotiating` phase use `/harness:resume` (already the right tool). Users wanting to restart negotiation use `/harness:rewind negotiating` (already the right tool).

**Test.** Trigger a sprint that gets interrupted during negotiation; run `/harness:resume`; verify the negotiate procedure resumes correctly. Trigger a sprint, after FINALIZE run `/harness:rewind negotiating`; verify negotiation re-runs.

**Migration note.** Users with muscle-memory `/harness:negotiate` get a "command not found" message. CHANGELOG.md documents the removal and points to the two correct entry points.

**Anthropic alignment.** *"Stripping away pieces that are no longer load-bearing."*

---

### Change 6 — Planner soft-signal size banner (no hard gate, per user call)

**Problem.** `agents/planner.md:546-567` defines a feature-size sanity check at Pass 2. Reads literally as advisory: *"If a single feature folder matches any oversized-feature signal below, flag it for split"* and *"surface the split to the human at the `/harness:analyze` gate for approval or override. Do NOT silently split."* This is correct as-is.

The user has explicitly stated: **trust the model on 1M context; no hard gate.** This change confirms the existing soft-only behavior aligns with that stance, with one clarification.

**Change.**

- `agents/planner.md:567` (the rationale paragraph): clarify that the gate is **advisory** and that on Opus 4.7[1m] the size signals are weaker than they were on Opus 4.5/4.6. Reword to:

> *"**Why this gate exists:** historically (Opus 4.5/4.6), a Generator dispatched to build a 20-FR foundation feature would exhaust its Claude Code budget mid-work and hard-stop with an uncommitted working tree. Recovery is possible (see generator.md pre-TDD scaffolding checkpoint rule), but preventing oversize at the Planner stage was the cheaper fix on those models. **On Opus 4.7[1m] the same gate is advisory only** — the larger context window largely absorbs multi-stratum work, and the user has chosen to trust the model. The signals here remain useful as a 'hey, this is huge, are you sure?' prompt for the human at the analyze gate, but the human is the decider, not this gate."*

- Confirm there is NO orchestrator code anywhere that hard-blocks on the size signals. Search `commands/sprint.md`, `commands/analyze.md` for any "if oversized → halt" logic. (Pre-spec audit confirms there is none today.)

**Files affected.**
- `agents/planner.md` (~5 lines reworded, no LoC change)

**Risk.** Zero. Doc-only clarification.

**Test.** N/A (doc change).

**Anthropic alignment.** *"With Opus 4.6 I dropped context resets from this harness entirely."* Same logic, applied to a different defensive component on Opus 4.7[1m].

---

## 5. Cross-cutting concerns

### 5.1 Dependency between Change #1 and the user's "trust the model" stance

Change #1 (1M-context confirmation) is the **foundation** for the user's stance. Without 1M context confirmation, "no hard size gate" reverts to the same failure mode that triggered this audit (your `001-foundation-and-ingestion` truncation). The two changes ship together or neither ships.

Concretely: the spec's Change #6 (soft gate stays advisory) is only safe given Change #1 is in place. CHANGELOG.md explicitly documents this dependency.

### 5.2 Single-PR atomicity vs git availability

The current working directory is reported as not-a-git-repo by the environment, but the README references `git tag v1.5.2`, `git branch v2-beta`, etc. — the project IS git-managed in normal use. Assume git is available when implementation begins. If for any reason it isn't, we ship without atomic-commit ceremony but the changes themselves are still atomic (single PR, single review).

### 5.3 No new tests required for documentation changes

Changes #1, #6 are doc-only. Changes #2, #3, #4, #5 each have a Test section above. Aggregate: one greenfield sprint, one brownfield sprint with story migration, one amend, one edit, one clarify, one constitution-amend. ~30 minutes of E2E exercise.

### 5.4 CHANGELOG entry

A new v2.2.0 (or v2.1.10) entry documents:
- Removed: per-FR story files; `/harness:negotiate` standalone.
- Changed: Planner agent slimmed (6 → 3 modes); Generator pause snapshot hardened; doctor 1M-context confirmation banner.
- Migration: existing `stories/` folders are ignored; can be deleted.
- Bumps: depends on whether this counts as breaking. Removing a user-facing command is breaking; bump minor → v2.2.0.

### 5.5 Predecessor spec contradiction

Change #2 (drop story files) reverses a v2.0 design decision. Document the reversal in the new CHANGELOG entry with the same rationale as in §4 Change #2: model capability evolved between v2.0 (Opus 4.6 / 200 k context) and v2.2 (Opus 4.7[1m] / 1M context); the assumption that drove inclusion in v2.0 has staled.

---

## 6. Investigations behind the design

### 6.1 Why doctor.sh can't reliably detect 1M context

Three approaches considered:

| Approach | Verdict |
|---|---|
| Read `$CLAUDE_MODEL` or similar env var | Claude Code does not currently set such an env var visible to plugin scripts (verified by inspecting current doctor.sh — no model-related env reads). Could ask Anthropic to expose it; not in scope. |
| Pin model in agent frontmatter (`model: claude-opus-4-7[1m]`) | Hardcodes a model version. Every Opus bump (4.7→4.8→5.0) breaks every project's agents until manually updated. Bad trade. |
| User-confirmation banner at sprint start | Reliable. Costs the user one keystroke per sprint. Anthropic-aligned (prose discipline + user agency, like every other v2.0 simplification). |

### 6.2 Why Planner pause stays in-context (AskUserQuestions) and Generator pause stays out-of-context (file-based)

| Concern | Planner | Generator |
|---|---|---|
| Discovery interactivity | High — user is at the keyboard during planning | Low — user may have walked away during a 30-min build |
| Per-question latency budget | Must be sub-second | Pause is a deliberate handoff; minutes are fine |
| Context budget | Planner runs are short; in-context Q&A is cheap | BUILD runs are long; in-context Q&A burns budget that could go toward TDD |

The asymmetry is correct. Change #3 hardens the Generator's existing file-based mechanism rather than unifying.

### 6.3 Why the audit family stays at 5 commands

Per `SKILL.md:289-318` mnemonic table, each answers a distinct question:
- `/analyze` = consistency (files talking to each other)
- `/validate` = completeness (each file self-sufficient)
- `/audit` = debt (stale/deferred things accumulating over time)
- `REVALIDATE` = backward compatibility (old features vs new constitution)
- `/retrospective` = reality alignment (spec vs what-was-built)

A spec can pass any 4 and fail the 5th; the failure modes are non-overlapping. Merging produces a meta-audit that's slower and harder to interpret. SKILL.md:309-318 already makes this case explicitly.

---

## 7. Rollback plan

Per change:

| Change | Rollback method |
|---|---|
| #1 — Doctor banner | Remove the new lines; banner-only, no behavior to revert |
| #2 — Story files removed | `git revert` the deletion; existing `stories/` folders are still readable but unused; restore the planner.md section + generator.md rule + sprint.md dispatch line |
| #3 — Pause snapshot | Remove the snapshot section from pause-questions.md.txt; orchestrator and generator fall back to manifest.yaml as today |
| #4 — Planner mode collapse | `git revert`; old mode sections restored. Each command file's dispatch prompt change is independent — partial revert per command is possible |
| #5 — `/harness:negotiate` removed | Restore commands/negotiate.md from git history; restore the README + SKILL.md table rows |
| #6 — Soft-gate clarification | Single-paragraph revert |

All changes are reversible at the file level. None touch persistent state (manifest.yaml schema, .harness/ folder structure beyond removing one optional directory).

---

## 8. Out of scope (deferred to v3 watch list)

- Stratum-splitting BUILD into N dispatches (N1).
- Pause-mechanic full unification (N2).
- Audit-family merge (N3).
- Mechanical 1M-context detection from doctor.sh (N4).
- Per-agent model pinning (N5).
- Story-file deprecation grace period mechanism (one-shot warning if existing project has stories/ folder; not worth the code).

ROADMAP.md gets a new entry: *"v2.2 stale-assumption pruning (story files, planner mode duplication, /negotiate command). v3 watch: stratum-splitting BUILD, pause unification, mechanical 1M-context detection."*

---

## 9. References

- `https://www.anthropic.com/engineering/harness-design-long-running-apps` — Rajasekaran 2026 (the ruler)
- `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md` — predecessor (this spec extends its logic)
- `docs/anthropic-alignment.md` — per-principle traceability (will gain rows for each Change here)
- `README.md:382-396` — v2.1.x patch history (context for what grew between v2.0 and now)
- The user's reported BUILD truncation incident: 178 tool uses, 347.5 k tokens, 36 min, no implementation-report.md (informal — referenced in §1 motivation)

---

## 10. Spec self-review (per superpowers:brainstorming)

- **Placeholder scan.** No "TBD" / "TODO" / vague items. Every change has concrete files, line counts, before/after, and tests.
- **Internal consistency.** Change #6 (soft gate stays) depends on Change #1 (1M context confirmed) — documented in §5.1. No other inter-change dependencies. Change #2's contradiction with the v2.0 spec is explicitly addressed in §4 Change #2 last paragraph + §5.5.
- **Scope check.** Six changes, ~5 hours, ~300 LoC reduction. Focused enough for a single implementation plan. Each change is independently testable.
- **Ambiguity check.** Each change has exactly one interpretation. The Planner mode collapse (#4) is the most complex — §4 Change #4 includes the mode-routing table (4 sub-markers, 4 patch-file targets) to remove ambiguity.

Self-review passes.
