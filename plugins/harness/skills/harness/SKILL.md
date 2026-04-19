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
| `/harness:sprint "<prompt>"` | [commands/sprint.md](../../commands/sprint.md) | Full pipeline: plan → analyze → [human gate] → negotiate → build → evaluate → tuning → retrospect → merge |
| `/harness:quick "<prompt>"` | [commands/quick.md](../../commands/quick.md) | Fast: skip Planner, minimal contract, single build+QA pass |
| `/harness:resume` | [commands/resume.md](../../commands/resume.md) | Recover from any phase using `manifest.yaml` + `changelog.md` |
| `/harness:clarify` | [commands/clarify.md](../../commands/clarify.md) | Post-plan structured Q&A — surface spec ambiguities, collect answers in files, auto-patch specs. Runs before human approval gate. |
| `/harness:analyze` | [commands/analyze.md](../../commands/analyze.md) | Cross-artifact consistency check (PRD ↔ architecture ↔ contract) |
| `/harness:negotiate` | [commands/negotiate.md](../../commands/negotiate.md) | Generator ↔ Evaluator contract negotiation (pre-build) |
| `/harness:validate` | [commands/validate.md](../../commands/validate.md) | 16-point quality audit on existing spec files |
| `/harness:edit "<change>"` | [commands/edit.md](../../commands/edit.md) | Cascade-aware spec edit via fresh Planner subagent. Produces cross-file patches, user approves per-file, orchestrator mechanically applies. For multi-file coordinated changes (stack swaps, NFR tightening). |
| `/harness:amend "<tweak>"` | [commands/amend.md](../../commands/amend.md) | Safe post-plan spec amendment via a fresh Planner subagent. Produces before→after patches, user confirms, orchestrator mechanically applies. **Never edits spec from orchestrator context.** Solves the post-plan tweak pollution failure mode. |
| `/harness:retrospective` | [commands/retrospective.md](../../commands/retrospective.md) | Post-merge drift analysis + spec sync |
| `/harness:tune-evaluator` | [commands/tune-evaluator.md](../../commands/tune-evaluator.md) | Review divergence log, propose calibration updates |
| `/harness:steer "<nudge>"` | [commands/steer.md](../../commands/steer.md) | Mid-build steering — append a guidance note the Generator picks up at the next TDD cycle boundary. Lightweight alternative to amend/rewind for implementation nudges. |
| `/harness:audit` | [commands/audit.md](../../commands/audit.md) | Verification debt scan |
| `/harness:rewind <phase>` | [commands/rewind.md](../../commands/rewind.md) | Reset the current feature to an earlier phase. Archive-based (reversible via file copy). Requires explicit typed confirmation. Use when a phase went fundamentally wrong. |
| `/harness:setup` | [commands/setup.md](../../commands/setup.md) | One-time install of harness rules into `~/.claude/CLAUDE.md` |
| `/harness:doctor` | [commands/doctor.md](../../commands/doctor.md) | Environment preflight — verifies MCPs, Node, git, plugins. Auto-runs at sprint/quick start and blocks on CRITICAL failures. |

## Subagent Isolation Protocol

This is the GAN insight from the Anthropic harness research: **the agent judging the work must have separate context from the agent doing the work.** Violations invalidate the whole pipeline.

Rules every command follows:
1. Each agent runs as a **fresh subagent** via `CLAUDE_SUBAGENT=1 claude -p "..."` — not a nested Claude conversation. The `CLAUDE_SUBAGENT=1` env var is required: the SessionStart hook reads it and skips `<harness-state>` injection, preventing the self-orchestration loop where a dispatched subagent re-reads SKILL.md and tries to re-dispatch its own subagents.
2. The Evaluator MUST NEVER share context with the Generator. Always dispatch as separate processes.
3. Every dispatch prompt includes a `<SUBAGENT-CONTEXT>` block telling the subagent: you were dispatched for ONE job; do NOT re-invoke the harness pipeline; if SessionStart or SKILL.md fires in your context, SKIP IT. This is the backup safety net — the `CLAUDE_SUBAGENT=1` env var is the primary gate.
4. Subagents write their output to `.harness/features/<current>/<filename>.md`, the orchestrator reads those files — never back-channel via conversation.

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
| `spec/constitution.md` | Planner Pass 1 only — **immutable thereafter** | All agents |
| `spec/evaluator-notes.md` | Orchestrator (during tuning check) | Evaluator EVALUATE |
| `evaluator/criteria.md` | Planner Pass 2 | All agents; `/harness:tune-evaluator` may propose updates |
| `evaluator/examples.md` | Orchestrator (during tuning check) | Evaluator EVALUATE |
| `evaluator/tuning-log.md` | Orchestrator (on divergence) | `/harness:tune-evaluator` |
| `features/NNN/contract.md` — **DRAFT** | Planner | Generator NEGOTIATE |
| `features/NNN/contract.md` — **FINAL** (overwrites draft) | Generator FINALIZE-CONTRACT | Generator BUILD, Evaluator |
| `features/NNN/proposal.md` | Generator NEGOTIATE | Evaluator REVIEW-PROPOSAL, Generator BUILD |
| `features/NNN/review.md` | Evaluator REVIEW-PROPOSAL | Generator FINALIZE-CONTRACT, Generator BUILD |
| `features/NNN/analysis-report.md` | Orchestrator (`/harness:analyze`) | Human, subsequent orchestrator phases |
| `features/NNN/implementation-report.md` | Generator BUILD | Evaluator EVALUATE |
| `features/NNN/eval-report.md` | Evaluator EVALUATE | Generator (on retry) |
| `features/NNN/retrospective.md` | Orchestrator (`/harness:retrospective`) | Human |
| `progress/changelog.md` | All agents append | All agents |
| `progress/decisions.md` | Orchestrator (ADR on any spec/prompt change) | All agents |
| `progress/known-issues.md` | Orchestrator (`/harness:retrospective`) | All agents |

### The "orchestrator does not edit spec files" rule

If you (as orchestrator) receive user feedback that requires modifying `spec/*` or `features/NNN/contract.md`, you MUST:

1. NOT use `Edit` or `Write` from your own context on those files
2. Dispatch the right subagent in the right mode (`/harness:edit`, `/harness:amend`, `/harness:clarify`, `/harness:tune-evaluator`, etc.)
3. Let the subagent produce a structured diff
4. Present the diff to the human before applying

The temptation is to "just edit it, it's one line." Resist. Even a one-line edit from the orchestrator starts a precedent that lets human chatter bleed into spec files, and that's exactly the failure mode the harness is designed to prevent.

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

## Evaluator Criteria (4 gradable dimensions)

| Criterion | Threshold | How tested |
|-----------|-----------|-----------|
| Functionality | 6/10 | Playwright: exercise all flows + edge cases |
| Code Quality | 6/10 | Source review against constitution |
| Test Coverage | 6/10 | Run suite + check TDD evidence in git log |
| Product Depth | 5/10 | Use app as real user, try to break it |

ANY criterion below threshold = FAIL → Generator retries with feedback.

## Manifest schema

```yaml
harness: { version: "1.2", model: "claude-opus-4-7", model_tuning_revision: 0 }
project: { name: "", description: "" }
config: { max_retries: 3, max_negotiation_rounds: 3, testing: { unit: vitest, e2e: playwright } }
state:
  phase: planning|analyzing|negotiating|building|evaluating|retrospective|complete
  current_feature: "001-feature-name"
  current_task: "FR-005"
  negotiation_round: 0
  retry_count: 0
features: { completed: [], in_progress: "", planned: [] }
verification_debt: { deferred: [], pending_human: [] }
tuning_debt:
  unreviewed_divergences: 0
  patterns_pending: []
```

## Rules

1. If `.harness/manifest.yaml` exists, read it before doing anything else.
2. Evaluator is ALWAYS a separate subagent — never self-evaluate in the same context.
3. Every technical decision must align with `.harness/spec/constitution.md`.
4. Agents communicate via `.harness/` files, never via shared context.
5. When uncertain, ask the human ONE focused question.
6. Planner does NOT specify files, components, data models, or API paths — those are negotiated between Generator and Evaluator before building.
