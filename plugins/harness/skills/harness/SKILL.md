---
name: harness
description: BELCORT Planner → Generator → Evaluator pipeline. Invoke when the user runs a /harness:* slash command, when .harness/manifest.yaml is present, or when the user describes a substantial build task (3+ components, >15 minutes of work) and has not yet activated the harness. The procedure for each command lives in commands/*.md — this skill is the shared context: activation rules, agent communication protocol, subagent isolation, and TDD contract.
---

# BELCORT Harness Engine

A Planner → Generator → Evaluator pipeline for Claude Code, adapted from Anthropic's research on long-running agent harnesses. Three fresh subagents, each with clean context, communicating through files in `.harness/`.

This skill is a **reference manual**, not a procedure. Each slash command has its own self-contained procedure in `commands/*.md`. This file holds the cross-cutting contracts every command depends on.

## Activation

This skill is live when any of the following are true:
- The SessionStart hook detected `.harness/manifest.yaml` in the current directory (the hook injected `<harness-state>` into context)
- The user ran `/harness:sprint`, `/harness:quick`, `/harness:resume`, or any other `/harness:*` command — the command file in `commands/` is your entry point; this skill is the shared context
- The user described something to build with ≥1% chance the harness would help (the 1% rule in `~/.claude/CLAUDE.md`)

## SUBAGENT ESCAPE HATCH

**If you were dispatched as a subagent** — your prompt contains a `<SUBAGENT-CONTEXT>` block — **SKIP this skill entirely.** Subagents do one specific job (planning, generating, evaluating). They do NOT orchestrate the pipeline, do NOT re-invoke `/harness:*` commands, do NOT read this SKILL.md for procedure. The orchestrator is the only agent that reads this skill.

## Commands

Each procedure lives in its own file under `commands/`. This is a pointer table, not the procedure itself.

| Command | File | What it does |
|---|---|---|
| `/harness:brainstorm "<idea>"` | [commands/brainstorm.md](../../commands/brainstorm.md) | Pre-plan exploration for vague/ambiguous requests. Interviews the user, surfaces silent assumptions, writes `.harness/brainstorm-current.md` so the subsequent `/harness:sprint` has a concrete prompt. Orchestrator-only (no subagent dispatch). |
| `/harness:sprint "<prompt>"` | [commands/sprint.md](../../commands/sprint.md) | Full pipeline: plan → analyze → [human gate] → negotiate → build → evaluate → tuning → retrospect → merge |
| `/harness:quick "<prompt>"` | [commands/quick.md](../../commands/quick.md) | Fast: skip Planner, minimal contract, single build+QA pass |
| `/harness:resume` | [commands/resume.md](../../commands/resume.md) | Recover from any phase using `manifest.yaml` + `changelog.md` |
| `/harness:clarify` | [commands/clarify.md](../../commands/clarify.md) | Post-plan structured Q&A — surface spec ambiguities, collect answers in files, auto-patch specs. Runs before human approval gate. |
| `/harness:analyze` | [commands/analyze.md](../../commands/analyze.md) | Cross-artifact consistency check (PRD ↔ architecture ↔ contract) |
| `/harness:negotiate` | [commands/negotiate.md](../../commands/negotiate.md) | Generator ↔ Evaluator contract negotiation (pre-build) |
| `/harness:validate` | [commands/validate.md](../../commands/validate.md) | 16-point quality audit on existing spec files |
| `/harness:edit "<change>"` | [commands/edit.md](../../commands/edit.md) | Cascade-aware spec edit via fresh Planner subagent (EDIT mode). Produces cross-file patches in `edit-patches.md`, user approves per-file, orchestrator mechanically applies. For multi-file coordinated changes (stack swaps, NFR tightening). |
| `/harness:amend "<tweak>"` | [commands/amend.md](../../commands/amend.md) | Safe post-plan spec amendment via a fresh Planner subagent (AMEND mode). Produces before→after patches in `amend-patches.md`, user confirms, orchestrator mechanically applies. **Never edits spec from orchestrator context.** Solves the post-plan tweak pollution failure mode. |
| `/harness:retrospective` | [commands/retrospective.md](../../commands/retrospective.md) | Post-merge drift analysis + spec sync |
| `/harness:tune-evaluator` | [commands/tune-evaluator.md](../../commands/tune-evaluator.md) | Review divergence log, propose calibration updates |
| `/harness:audit` | [commands/audit.md](../../commands/audit.md) | Verification debt scan |
| `/harness:rewind <phase>` | [commands/rewind.md](../../commands/rewind.md) | Reset the current feature to an earlier phase. Archive-based (reversible via file copy). Requires explicit typed confirmation. Use when a phase went fundamentally wrong. |
| `/harness:setup` | [commands/setup.md](../../commands/setup.md) | Initialise the harness in the current project: creates `.harness/` from templates and writes project-local `./CLAUDE.md` activation rules. Idempotent. (v2.0+: no global `~/.claude/CLAUDE.md` write.) |
| `/harness:doctor` | [commands/doctor.md](../../commands/doctor.md) | Environment preflight — verifies MCPs, Node, git, plugins. Auto-runs at sprint/quick start and blocks on CRITICAL failures. |
| `/harness:constitution-amend "<reason>"` | [commands/constitution-amend.md](../../commands/constitution-amend.md) | High-ceremony constitution change: typed confirmation + ≥50-char reason + in-progress handling + mandatory ADR + revalidation against every completed feature. The ONLY authorized path to modify spec/constitution.md after Planner Pass 1. |

## Subagent Isolation Protocol

This is the GAN insight from the Anthropic harness research: **the agent judging the work must have separate context from the agent doing the work.** Violations invalidate the whole pipeline.

### Dispatch mechanism (v2.1.0+)

Subagents are dispatched via the **Agent tool** using plugin-declared `subagent_type` values:

- `harness:planner` — Planner agent (PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND modes)
- `harness:generator` — Generator agent (NEGOTIATE, FINALIZE-CONTRACT, BUILD modes)
- `harness:evaluator` — Evaluator agent (REVIEW-PROPOSAL, EVALUATE, REVALIDATE modes)

These are declared in `plugin.json` (`"agents": "./agents/"`) and resolve to the YAML-frontmatter-headed `.md` files in `agents/`. Each frontmatter specifies `tools:` (default allowlist) and `description:` (when Claude should use this agent).

Prior versions (≤2.0.0) used `claude -p` subprocess dispatch with `--append-system-prompt-file` + `--allowedTools` + `CLAUDE_SUBAGENT=1` env-var guard. v2.1.0 migrated to native Agent-tool dispatch, which provides the same fresh-context-window isolation without the subprocess overhead, env-var tricks, or stdout-parsing.

### Rules every command follows

1. **Every dispatch is a fresh Agent-tool call.** No nested conversation, no shared context. The Agent tool guarantees a fresh context window per dispatch — the subagent sees its system prompt (from `agents/<name>.md`) and the `prompt` parameter, nothing from the parent's conversation.

2. **The Evaluator MUST NEVER share context with the Generator.** Always two separate Agent-tool calls. The Agent tool's context isolation enforces this at the platform level.

3. **The `prompt` parameter carries three things**: (a) an explicit mode sentence ("You are being dispatched in PLAN mode" / NEGOTIATE / BUILD / EVALUATE / REVIEW-PROPOSAL / FINALIZE-CONTRACT / AMEND / CLARIFY-QUESTIONS / CLARIFY-APPLY / REVALIDATE / CONSTITUTION-AMEND / EDIT), (b) the concrete task framing for that mode, (c) the user's original request or the context-file list.

4. **The `<SUBAGENT-CONTEXT>` block inside each agent.md is the isolation gate.** It tells the subagent: "you were dispatched for ONE job; do NOT re-invoke the harness pipeline; if SessionStart or SKILL.md fires in your context, SKIP IT." On Opus 4.7+, instruction-following is reliable — this prose rule is sufficient. Nothing mechanical enforces it beyond the Agent tool's native context isolation.

5. **Subagents write output to files** under `.harness/features/<current>/<filename>.md`; the orchestrator reads those files after the Agent-tool call returns. The Agent tool's return string is a summary, not the authoritative artifact. File-based communication per Anthropic's canonical pattern.

6. **No env-var tricks.** The legacy `CLAUDE_SUBAGENT=1` check in `session-start.sh` is retained as a backward-compat shim for any external `claude -p` invocations (rare), but within the harness pipeline no command sets it — Agent-tool dispatches are the single dispatch path.

### Parallel-dispatch potential (unused today)

The Agent tool supports multiple Agent calls in one message — they run in parallel. The current pipeline is sequential (Planner → analyze → Negotiate → Build → Evaluate). If a future version benefits from parallelism (e.g., revalidating 10 completed features concurrently during `/harness:constitution-amend` Step 7), that's a single refactor away: emit N Agent tool calls in one message instead of a sequential loop.

## File Ownership Contract

Every file under `.harness/` has exactly one writer per phase. If you're not the designated writer, you're a reader — do NOT write, not even to "fix" something.

**This is the contract that keeps the orchestrator from silently corrupting spec files with its own fat chat context.** When the human tweaks a plan mid-flow, the orchestrator's instinct is to just edit the file directly. Don't. The orchestrator's context contains an entire conversation's worth of unrelated tokens. The spec files should contain only what a subagent wrote with a clean context. If the orchestrator starts editing spec files, the whole isolation property breaks and subsequent agents inherit the orchestrator's noise.

| File | Writer | Readers |
|---|---|---|
| `manifest.yaml` → `state.*` transitions | Orchestrator | All agents (read-only) |
| `manifest.yaml` → `features.*`, `verification_debt.*`, `tuning_debt.*` | Orchestrator | All agents (read-only) |
| `ROADMAP.md` | Planner (init); Retrospective (update) | All agents |
| `spec/prd.md` | Planner Pass 1 | All agents; Retrospective may propose drift-driven updates |
| `spec/architecture.md` | Planner Pass 2 | All agents; Retrospective may propose drift-driven updates |
| `spec/constitution.md` | Planner Pass 1 (initial); `/harness:constitution-amend` ONLY (FR-6) — high-ceremony amendment behind typed confirmation + ≥50-char reason + revalidation against every completed feature | All agents |
| `spec/evaluator-notes.md` | Orchestrator (during tuning check) | Evaluator EVALUATE |
| `evaluator/criteria.md` | Planner Pass 2 | All agents; `/harness:tune-evaluator` may propose updates |
| `evaluator/examples.md` | Orchestrator (during tuning check) | Evaluator EVALUATE |
| `evaluator/tuning-log.md` | Orchestrator (on divergence) | `/harness:tune-evaluator` |
| `features/NNN/contract.md` — **DRAFT** | Planner | Generator NEGOTIATE |
| `features/NNN/contract.md` — **FINAL** (overwrites draft) | Generator FINALIZE-CONTRACT | Generator BUILD, Evaluator |
| `features/NNN/stories/FR-NNN.md` (FR-4) | Planner Pass 2 (initial); Generator BUILD (refinements during build, e.g., implementation log entries) | Generator BUILD per TDD cycle (canonical per-cycle context); Evaluator EVALUATE (cross-checks story narrative against aggregate contract — drift = build fails) |
| `features/NNN/proposal.md` | Generator NEGOTIATE | Evaluator REVIEW-PROPOSAL, Generator BUILD |
| `features/NNN/review.md` | Evaluator REVIEW-PROPOSAL | Generator FINALIZE-CONTRACT, Generator BUILD |
| `features/NNN/analysis-report.md` | Orchestrator (`/harness:analyze`) | Human, subsequent orchestrator phases |
| `features/NNN/implementation-report.md` | Generator BUILD | Evaluator EVALUATE |
| `features/NNN/eval-report.md` | Evaluator EVALUATE | Generator (on retry) |
| `features/NNN/retrospective.md` | Orchestrator (`/harness:retrospective`) | Human |
| `features/NNN/amend-patches.md` | Planner AMEND | Orchestrator (applies to spec/) — ephemeral record of the amendment |
| `features/NNN/clarifications.md` | Planner CLARIFY-QUESTIONS | User (fills in answers); Planner CLARIFY-APPLY |
| `features/NNN/clarify-patches.md` | Planner CLARIFY-APPLY | Orchestrator (applies to spec/) — ephemeral |
| `features/NNN/edit-patches.md` (or top-level `.harness/edit-patches.md` when no active feature) | Planner EDIT | Orchestrator (applies to spec/ + `init.sh`) — ephemeral |
| `features/NNN/pause-questions.md` | Generator BUILD (mid-build clarification) | User answers; orchestrator re-dispatches Generator |
| `.harness/constitution-amend-patches.md` (top-level, global) | Planner CONSTITUTION-AMEND | Orchestrator applies to `spec/constitution.md` after user + revalidation approve |
| `.harness/.revalidation-<ts>/<FEATURE>.md` | Evaluator REVALIDATE (per completed feature) | Orchestrator aggregates into backport/grandfather decisions |
| `progress/changelog.md` | All agents append | All agents |
| `progress/decisions.md` | Orchestrator (ADR on any spec/prompt change) | All agents |
| `progress/known-issues.md` | Orchestrator — **three writers**: (a) `/harness:retrospective` on post-merge drift capture (primary); (b) `/harness:edit` Step 6 when a cascade-edit defers a V-gate failure ("defer-to-sprint"); (c) `/harness:audit` when the user chooses "record as debt" for a finding. Append-only; entries persist across sprints. | Retrospective (dedup against existing entries); Audit (verification-debt scan starts here); Planner CLARIFY-QUESTIONS (skip ambiguities already recorded); human |

### The "orchestrator does not edit spec files" rule

If you (as orchestrator) receive user feedback that requires modifying `spec/*` or `features/NNN/contract.md`, you MUST:

1. NOT use `Edit` or `Write` from your own context on those files
2. Dispatch the right subagent in the right mode (`/harness:edit`, `/harness:amend`, `/harness:clarify`, `/harness:tune-evaluator`, `/harness:constitution-amend`, etc.)
3. Let the subagent produce a structured diff
4. Present the diff to the human before applying

The temptation is to "just edit it, it's one line." Resist. Even a one-line edit from the orchestrator starts a precedent that lets human chatter bleed into spec files, and that's exactly the failure mode the harness is designed to prevent.

**Enforcement note (v2.0.0+).** This rule is prose-only. There is no mechanical hook enforcement; Opus 4.7 follows the constraint when stated explicitly. If the orchestrator ever drifts (edits a spec file directly), the Evaluator's retrospective will surface the drift as a finding during post-merge reconciliation.

## Agent Communication Protocol

Agents NEVER share conversation context. They communicate exclusively via `.harness/` files. Each feature has its own folder under `.harness/features/NNN-name/` for scoped artifacts.

```
GLOBAL files (persist across features):
  .harness/spec/          — prd.md, architecture.md, constitution.md, evaluator-notes.md (optional)
  .harness/evaluator/     — criteria.md (grading rubric), examples.md, tuning-log.md
  .harness/ROADMAP.md     — shipped / in-progress / planned / considered
  .harness/manifest.yaml  — current state + feature tracking
  .harness/progress/      — changelog.md, decisions.md (ADRs), known-issues.md (append-only)

PER-FEATURE files (isolated in .harness/features/NNN-name/):
  contract.md              — what this feature builds (Planner writes draft, negotiate finalizes)
  proposal.md              — Generator's implementation plan (written during negotiate)
  review.md                — Evaluator's review of the proposal (written during negotiate)
  implementation-report.md — what was built (Generator writes)
  eval-report.md           — PASS/FAIL verdict (Evaluator writes)
  analysis-report.md       — cross-artifact check (optional, from /harness:analyze)
  retrospective.md         — drift analysis (optional, from /harness:retrospective)
```

### Flow

```
Planner      → writes → spec/, evaluator/criteria.md,
                        features/NNN/contract.md (DRAFT),
                        ROADMAP.md (in-progress entry), manifest.yaml
[analyze]    → reads  → spec/, features/NNN/contract.md
             → writes → features/NNN/analysis-report.md
[negotiate]  → Generator writes features/NNN/proposal.md
               Evaluator writes features/NNN/review.md
               (iterate up to 3 rounds)
               Generator writes features/NNN/contract.md (FINAL, overwrites draft)
Generator    → reads  → spec/, features/NNN/contract.md (final)
             → writes → source code, git commits, progress/changelog.md,
                        features/NNN/implementation-report.md
Evaluator    → reads  → evaluator/criteria.md, evaluator/examples.md,
                        spec/evaluator-notes.md (if exists),
                        features/NNN/implementation-report.md,
                        features/NNN/contract.md (final), spec/
             → writes → features/NNN/eval-report.md
[retro]      → reads  → features/NNN/* + source code
             → writes → features/NNN/retrospective.md, spec updates, ROADMAP.md

On retry:
Generator    → reads  → features/NNN/eval-report.md (what failed)
             → writes → fixes + updated implementation-report.md

Tuning (after every evaluation, PASS or FAIL):
[orchestrator asks human]
[if divergence]
Orchestrator → writes → .harness/evaluator/tuning-log.md (append)
             → writes → .harness/evaluator/examples.md (if calibration example agreed)
             → writes → .harness/spec/evaluator-notes.md (if project-specific)

Periodic / on pattern detection:
[/harness:tune-evaluator]
Orchestrator → reads  → .harness/evaluator/tuning-log.md
             → writes → .harness/evaluator/examples.md (new examples)
                      → ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/evaluator.md (prompt changes, rare)
                      → .harness/progress/decisions.md (ADR for any prompt change)
```

### Retrospective vs tuning — two different loops

These run back-to-back after every sprint and are easy to confuse. They measure different axes and write different artifacts:

| Loop | Question it answers | Inputs | Outputs |
|---|---|---|---|
| **Retrospective** (Step 5a in sprint.md) | "Does what we built match what we said we'd build? Has reality drifted from the spec?" | `contract.md`, `implementation-report.md`, actual code | `retrospective.md`, spec updates (via /amend), `known-issues.md` |
| **Tuning** (Step 5a-pre in sprint.md, and `/harness:tune-evaluator`) | "Did the Evaluator's judgment match human judgment? Is the grader calibrated?" | `eval-report.md`, human verdict on it | `tuning-log.md`, `examples.md`, rarely `evaluator.md` prompt edits |

Retrospective audits the **work product** (did we build the right thing?). Tuning audits the **judge** (is the grader grading correctly?). A sprint can pass retrospective and fail tuning (we built what we said, but the Evaluator approved a broken feature), or pass tuning and fail retrospective (Evaluator graded correctly, but what we built drifted from the spec). Both checks are required to keep the pipeline honest — the Evaluator keeps the Generator honest; the tuning loop keeps the Evaluator honest.

## TDD Protocol (Generator enforces)

Every FR/AC in the contract follows this cycle:

1. **RED** — write the failing test first, run it, confirm it fails
2. **GREEN** — write the minimum code to make it pass
3. **REFACTOR** — clean up with tests staying green
4. **COMMIT** — atomic: `[harness:build] <behavior description>`

No code without a failing test. No exceptions. The Evaluator verifies test-first discipline via `git log` archaeology.

## Session Start Behavior

When starting a new Claude Code session in any project:

```
IF .harness/manifest.yaml exists:
  The SessionStart hook has already injected <harness-state> with phase + current feature.
  IF phase ≠ "complete":
    Mention: "This project has harness state (phase: [X]).
              Run /harness:resume to continue."
```

Don't auto-resume — just notify. The user may want to do something else first.

## Evaluator Criteria

See `@templates/evaluator/criteria.md.txt` for the authoritative criteria skeleton, thresholds, and calibration guidance. The Planner copies and customises this template into `.harness/evaluator/criteria.md` during PLAN mode Pass 2.

## Manifest schema

See `@templates/manifest.yaml` for the authoritative schema with all fields, defaults, and inline comments. The Planner (during init) writes the first manifest from this template; subsequent agents read and update specific fields per the File Ownership Contract above.

## Rules

1. If `.harness/manifest.yaml` exists, read it before doing anything else.
2. Evaluator is ALWAYS a separate subagent — never self-evaluate in the same context.
3. Every technical decision must align with `.harness/spec/constitution.md`.
4. Agents communicate via `.harness/` files, never via shared context.
5. When uncertain, ask the human ONE focused question.
6. Planner does NOT specify files, components, data models, or API paths — those are negotiated between Generator and Evaluator before building.

## Pipeline Timing

When each step runs — "auto" = no user input required; "gate" = blocks waiting for user; "manual" = user invokes explicitly.

| Step | When it fires | Who triggers |
|---|---|---|
| `doctor` preflight | Start of `/harness:sprint`, `/harness:quick`, `/harness:setup` | auto |
| Planner (PLAN) | After doctor passes | auto |
| `analyze` | After Planner returns, before human gate | auto |
| Human gate | After analyze completes | **gate** |
| `clarify` | Auto-suggested at human gate if Planner's report lists ≥3 silent defaults OR user's approval text contains uncertainty words ("maybe", "not sure", "probably"). Also user-manual. | auto-suggest or manual |
| Generator NEGOTIATE → Evaluator REVIEW (≤3 rounds) → Generator FINALIZE | After user approves at human gate | auto |
| Generator BUILD | After FINALIZE returns | auto |
| Pause protocol | Only if Generator writes `pause-questions.md` mid-build | auto-surface, **gate** for answers |
| Evaluator EVALUATE | After Generator BUILD returns | auto |
| Tuning check | After every EVALUATE (PASS or FAIL) | **gate** (user answers agree / disagree / partial) |
| Retrospective | On PASS verdict | auto; **gate** for drift-update approvals |
| Merge | After retrospective approval | auto |
| Retry | On FAIL with retries<max | auto loops back to Generator BUILD |
| `amend`, `edit`, `rewind`, `constitution-amend`, `tune-evaluator`, `audit`, `validate`, `retrospective` (standalone), `negotiate` (standalone), `brainstorm` | User invokes explicitly | **manual** |

## Audit Commands — which question each answers

Five commands/modes look audit-ish. They answer **different** questions and are NOT interchangeable. This table is the single authoritative clarifier — individual command files refer here instead of re-explaining.

| Command | Question it answers | Scope | When it runs | Writes |
|---|---|---|---|---|
| `/harness:analyze` | *"Are the spec files internally consistent right now?"* (PRD ↔ architecture ↔ contract ↔ criteria — do FRs trace to UJs, do ACs exist for every FR, do NFRs have verification steps, does the contract cover every FR?) | Cross-artifact in `spec/` + current feature | Auto after every spec-mutating command (`/amend`, `/edit`, `/clarify`, Step 6 of `/constitution-amend`); auto in `/sprint` post-Planner | `features/NNN/analysis-report.md` (or `_global/` for between-features edits) |
| `/harness:validate` | *"Is every spec section complete and quality-gated?"* (the 16-point V1–V16 checklist from planner.md: every FR has ≥2 ACs, every NFR is SMART, every stack choice has documented rationale, scope boundary has ≥3 items, etc.) | Every file under `spec/` | Manual only; auto-invoked by `/edit` Step 6 (cascade edits only — `/amend` skips this because single-file changes rarely break completeness) | Report to screen only; no file (V-gate failures are deferred to `progress/known-issues.md` if the user chooses) |
| `/harness:audit` | *"Do any shipped features have deferred debt, stale known-issues, suspicious skip markers, TODO/FIXME without owners?"* (verification-debt across features, across time) | Cross-feature, historical | Manual only; typically weekly/monthly cadence | Report to screen only |
| Evaluator **REVALIDATE** mode | *"Does each previously-shipped feature still comply with the NEW constitution?"* (per-principle PASS/FAIL audit against amended constitution) | Per completed feature × per constitution principle | Only inside `/harness:constitution-amend` Step 7 | `.harness/.revalidation-<ts>/<FEATURE>.md` |
| `/harness:retrospective` | *"Did the implementation drift from the spec?"* (contract ↔ actually-built code reconciliation — positive, negative, neutral drift) | Current feature, post-build | Auto after PASS in `/sprint`; manual standalone post-merge | `features/NNN/retrospective.md` + spec/ updates on user approval |

### Mnemonic

- **analyze** = consistency (files talking to each other)
- **validate** = completeness (each file self-sufficient)
- **audit** = debt (stale/deferred things accumulating over time)
- **REVALIDATE** = backward compatibility (old features vs new constitution)
- **retrospective** = reality alignment (spec vs what-was-built)

### Why not merge them

Each catches a distinct failure class:
- A spec can be consistent (analyze passes) but incomplete (validate catches missing ACs).
- A spec can be complete (validate passes) but inconsistent (analyze catches a dangling AC reference).
- A spec can be both (analyze+validate pass) but accumulating debt (audit catches stale known-issues).
- A spec can be flawless but the shipped code drifted (retrospective catches it).
- A constitution amendment that passes current-spec analyze can still invalidate past features (REVALIDATE catches it).

Keeping them separate keeps each fast + cheap + single-purpose. Fusing them produces a meta-audit that's slower and harder to interpret — worse for every use case.

## Orchestrator Behavior (outside /harness:sprint)

When the user interacts with the orchestrator while a harness is active but outside a dispatched subagent, the orchestrator:

1. **Reads state first.** `.harness/manifest.yaml` + `.harness/progress/changelog.md` + `git log --oneline | grep 'harness:' | head -5`. Don't rely on conversational memory of prior messages — state files are authoritative.

2. **Does not edit spec files directly.** If the user asks for a spec change, route through `/harness:amend`, `/harness:clarify`, `/harness:edit`, or `/harness:constitution-amend`. Even a "just one word" edit leaks the orchestrator's fat chat context into the spec.

3. **Answers technical questions about the project by reading the spec.** Don't invent details from conversational memory. If the spec doesn't answer the question, say so and offer `/harness:clarify` or propose the answer be captured via `/harness:amend`.

4. **Refuses to start coding when a harness is active.** The Generator in BUILD mode is the authorized writer of source. If the user asks for code mid-sprint, remind them the Generator is (or will be) doing that work and offer to dispatch it.

5. **Handles scope-change requests as amendments.** "Actually, let's also support X" is an amendment of the PRD; route through `/harness:amend`.

6. **Escalates ambiguity.** If the user's request is genuinely ambiguous, ask ONE focused question. Do not guess silently (this is the calibrated-uncertainty principle from Anthropic's Trustworthy Agents research).

7. **Propagates project-specific tool/MCP guidance to subagents.** Before dispatching any subagent via the Agent tool, the orchestrator scans project `./CLAUDE.md` for a `## Project-specific tools / MCPs / skills` section (or any `### Project tools` subsection). If present, it includes the relevant tool-guidance lines in the Agent-tool `prompt` parameter under a `--- PROJECT TOOLS ---` marker.

   Rationale: as of v2.1.1+, agent frontmatter declares no `tools:` allowlist — subagents inherit the parent session's full tool set. This is the industry-standard Claude Code plugin pattern (matches Vercel, Superpowers) and survives Claude Code's runtime tool-namespace renaming (e.g., `mcp__context7` → `mcp__plugin_harness_context7__*`). But inheritance gives access, not knowledge — the orchestrator's job is to tell each dispatched subagent *which* project-specific tools are relevant to the task at hand, so the agent actually reaches for them.

   Example dispatch prompt fragment (appended by orchestrator when project CLAUDE.md declares Figma MCP):
   ```
   --- PROJECT TOOLS ---
   This project uses mcp__figma. When the PRD references existing Figma designs, query the component tree via mcp__figma before making architecture decisions.
   ```

   Agents remain free to use ANY tool in the session (inheritance). The project-tools section is a HINT for what's likely relevant, not a restriction.

## State Persistence

What updates what, and when:

| File | Updated by | When |
|---|---|---|
| `manifest.yaml → state.phase` | Orchestrator | At every phase transition (planning → analyzing → negotiating → building → evaluating → retrospective → complete) |
| `manifest.yaml → state.current_feature` | Planner (init); Orchestrator (on new sprint) | Start of PLAN mode; start of new sprint |
| `manifest.yaml → state.current_task` | Generator BUILD | After each FR commit (FR-NNN progresses) |
| `manifest.yaml → state.retry_count` | Orchestrator | On FAIL verdict + retry |
| `manifest.yaml → state.last_session` | Orchestrator; Generator | At every dispatch boundary |
| `manifest.yaml → features.*` | Orchestrator | After Planner init, after merge |
| `manifest.yaml → tuning_debt.*` | Orchestrator | After each tuning-check divergence log |
| `manifest.yaml → constitution.amendments` | Orchestrator | After `/harness:constitution-amend` applies |
| `progress/changelog.md` | ALL agents (append-only) | At every significant milestone — Planner on plan complete, Generator on each FR commit, Evaluator on verdict, spec-edit commands on apply |
| `progress/decisions.md` | Orchestrator (append-only ADR) | On any spec or prompt change (amend, edit, clarify, constitution-amend, tune-evaluator prompt tweak, rewind) |
| `progress/known-issues.md` | Orchestrator (via `/harness:retrospective`) | Post-merge drift analysis, verification-debt capture |
| `ROADMAP.md` | Planner (init); Retrospective (update) | Init; every retrospective |

## State Awareness

Before every phase transition, the orchestrator MUST:

1. `cat .harness/manifest.yaml` — read `state.phase`, `state.current_feature`, `state.current_task`, `state.retry_count`, `state.last_session`.
2. `tail -20 .harness/progress/changelog.md` — see recent activity.
3. `git log --oneline | grep 'harness:' | head -5` — cross-check commits against what the changelog claims.
4. If any of these disagree (e.g., git shows FR-005 committed but changelog says FR-003 was last), **do not silently proceed**. Print the conflict clearly and ask the user which to trust.

**Staleness signals** — surface a warning before dispatching if any of these hold:
- `state.last_session` is ≥ 24 hours old (an unrelated session may have modified files).
- `git status --porcelain` shows uncommitted changes to any file under `.harness/` that wasn't the current phase's designated writer.
- Files referenced in the current phase (e.g., `features/${FEATURE}/contract.md` for a build) have mtime newer than the corresponding `changelog.md` entry.

**Subagent-side state checks** — every subagent's INPUT section authoritatively lists what it must read before acting. Generator BUILD re-reads `state.current_task` + recent changelog + git log at each cycle boundary for mid-build recovery (see generator.md Phase 1 Orient). Evaluator reads `state.current_feature` in Setup. Planner PLAN writes the initial state; CLARIFY/AMEND/EDIT/CONSTITUTION-AMEND modes read the current spec the orchestrator just passed. **Subagents never bypass the dispatched context by reading "whatever file happens to be latest"** — they read the files their MODE's INPUT section lists.

This is the Anthropic "continuous-session" pattern: state lives in files, agents read them live rather than carrying state in conversational memory.

## Recovery (what `/harness:resume` does)

When `/harness:resume` is invoked (or when the user implicitly resumes a mid-sprint session):

1. Read state (per "State Awareness" above).
2. Run `bash .harness/init.sh` for health check. If init.sh missing: copy from `@templates/init.sh.txt`, chmod +x, then run.
3. Print the status report to the user (project name, feature, phase, current_task, retry_count, recent commits, recent changelog).
4. Phase-specific recovery:
   - **`planning`**: check which spec files exist. If PRD present but architecture missing, Planner was mid-Pass-2 — re-dispatch PLAN mode.
   - **`analyzing`**: if `analysis-report.md` exists, present findings + proceed to human gate. Otherwise re-run `/harness:analyze`.
   - **`negotiating`**: inspect `proposal.md`/`review.md` — dispatch the appropriate Generator/Evaluator mode next (NEGOTIATE → REVIEW-PROPOSAL → FINALIZE-CONTRACT). If ≥3 rounds with no agreement, escalate to human.
   - **`building`**: mid-build recovery. First determine whether the stop was graceful (`pause-questions.md` exists → handle per sprint.md pause flow) or a hard-stop (subagent returned truncated, no pause file, may have uncommitted work).
     - **Hard-stop mid-TDD** (per-FR commits exist on branch): read `state.current_task` + changelog to find last completed FR. Re-dispatch Generator BUILD: "Resume from FR-NNN. Previous commits: [list]. Skipping completed FRs."
     - **Hard-stop mid-scaffolding** (zero FR commits, uncommitted worktree, Generator was in pre-TDD phase): scan `git log` for `[harness:scaffold] ... (checkpoint)` commits and the latest `scaffold-checkpoint` changelog entry. The "Next:" line tells you where to resume. Re-dispatch: "Resume from commit [hash]. Scaffolding groups done: [list]. Continue with [next group]." If NO scaffold-checkpoints exist (legacy Generator pre-v2.1.5, or rule skipped): manually checkpoint-commit the worktree, show the human what's on disk, ask them to confirm done vs in-flight, then re-dispatch with narrower scope.
   - **`evaluating`**: if `eval-report.md` exists, check whether tuning-check ran (look for a tuning-log entry referencing this feature today). If not, run tuning-check. Then proceed to PASS/FAIL handling.
   - **`retrospective`**: if `retrospective.md` exists, present drift findings + await approval. Otherwise re-run retrospective.
   - **`complete`**: report last shipped feature + offer `/harness:sprint "<next>"`.
5. On any ambiguity, ask the user ONE focused question before proceeding.

## Optional Plugins

Installed plugins that the harness integrates with if available. None required; all enhance specific phases.

| Plugin | Used by | What it adds | Install |
|---|---|---|---|
| `frontend-design` | Planner (Pass 2), Generator (BUILD UI work) | Design tokens + layout patterns; produces more polished UI | `/plugin install frontend-design@claude-plugins-official` |
| `security-guidance` | Generator (pre-commit), Evaluator (Code Quality) | OWASP Top 10 checks, secret-detection, injection-flaw scan | `/plugin install security-guidance@claude-plugins-official` |
| `agentlint` | Evaluator (Code Quality, before manual review) | 33 evidence-backed checks across 5 dimensions; catches patterns humans miss | `/plugin install agentlint@claude-plugins-official` |
| `superpowers` | Generator (BUILD — TDD cycle), Evaluator (systematic-debugging when stuck) | TDD skill owns the RED/GREEN/REFACTOR discipline per the Superpowers pattern; required for Generator BUILD mode | `/plugin install superpowers@claude-plugins-official` |

The doctor (`/harness:doctor`) checks for these and warns if missing. Generator and Evaluator reference this section for integration guidance rather than duplicating install/usage details.

## Template Index

The plugin ships the following canonical templates at `${CLAUDE_PLUGIN_ROOT}/templates/`. Agents reference these via `@templates/<path>` rather than inlining content.

| Template | Path | Purpose |
|---|---|---|
| Manifest | `manifest.yaml` | Project-state source of truth; copied into `.harness/manifest.yaml` at setup |
| Roadmap | `ROADMAP.md` | Shipped / in-progress / planned / considered list |
| Init script | `init.sh.txt` | Project-health check; Planner customises per stack |
| Project CLAUDE.md | `CLAUDE.md.project.txt` | Activation snippet installed into `./CLAUDE.md` |
| Evaluator criteria | `evaluator/criteria.md.txt` | 4-criterion rubric skeleton; Planner customises in Pass 2 |
| Evaluator examples | `evaluator/examples.md.txt` | 12 seeded few-shot calibration examples |
| Evaluator tuning log | `evaluator/tuning-log.md.txt` | Divergence-capture log skeleton |
| Evaluator notes | `spec/evaluator-notes.md.txt` | Project-specific calibration notes |
| Contract | `features/contract.md.txt` | Final negotiated build contract skeleton |
| Proposal | `features/proposal.md.txt` | Generator NEGOTIATE proposal skeleton |
| Review | `features/review.md.txt` | Evaluator REVIEW-PROPOSAL skeleton |
| Eval report | `features/eval-report.md.txt` | Evaluator EVALUATE report skeleton |
| Implementation report | `features/implementation-report.md.txt` | Generator BUILD handoff skeleton |
| Story | `features/story.md.txt` | Per-FR build story (BMAD V6 pattern) |
| Pause questions | `features/pause-questions.md.txt` | Generator pause protocol file |
| Progress — changelog | `progress/changelog.md` | Append-only activity log |
| Progress — decisions | `progress/decisions.md` | ADR template |
| Progress — known issues | `progress/known-issues.md` | Post-retrospective issue list |
