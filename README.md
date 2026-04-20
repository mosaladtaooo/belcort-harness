# BELCORT Harness — v1.5.2

> **v1.5.2** is a doc-polish release of the v1.5.x series. The pipeline implementation is
> unchanged from [v1.5.1](CHANGELOG.md). All internal file paths, command names, and
> behavioral rules are identical.

An opinionated **Planner → Generator → Evaluator** pipeline for Claude Code. Three fresh
subagents, file-based communication, adversarial QA, and a mandatory human gate after
planning. You supply a 1–4 sentence prompt; the harness orchestrates planning, contract
negotiation, test-driven implementation, and retrospective drift analysis — all auditable
via git.

This is **not** a framework or library. It is a set of markdown files and shell scripts
that shape how Claude Code behaves on substantial software projects.

Built for Claude Opus 4.7+ and Claude Code 2.1+. Tuned for TypeScript/Node.js full-stack
projects; the Planner can target any stack.

**v1.5.0 compatibility note:** v1.4 and earlier are non-functional on Claude Code 2.1+
due to a changed subagent dispatch pattern. See [Migrating from v1.4](#migrating-from-v14--v15x).

---

## Why this exists

Anthropic's published research identifies three compounding problems with naive
long-running agent setups:

**1. Context degradation across sessions.**
[Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
showed that agents lose coherence across context windows. Structured state handoffs —
progress files, git commits — outperform unstructured continuations.

**2. Generator and evaluator share context.**
Rajasekaran (2026) found that "separating the agent doing the work from the agent judging
it proves to be a strong lever" ([Harness Design for Long-Running Application Development](https://www.anthropic.com/engineering/harness-design-long-running-apps)).
When one agent both builds and grades the work, it optimises for the appearance of
correctness rather than correctness itself.

**3. Subagent opacity and over-confident acting.**
[Trustworthy Agents in Practice](https://www.anthropic.com/research/trustworthy-agents)
(2026) observes that subagent workflows "are no longer neatly visible as a single thread
of actions" (verbatim), creating an opacity problem as agent count scales. The same
article emphasises training models toward "raising concerns, seeking clarification, or
declining to proceed" rather than forging ahead on assumptions (verbatim). Paraphrased:
the antidote to subagent opacity is mandatory live observability and mandatory calibrated
pausing on ambiguity — both of which the harness implements explicitly.

BELCORT Harness addresses all three. See [docs/anthropic-alignment.md](docs/anthropic-alignment.md)
for a point-by-point decision-to-source map, including a v1.5 sub-table tying each new
feature to its specific source quote.

---

## Provenance

Three open-source traditions, each contributing a distinct dimension:

- **[GitHub SpecKit](https://github.com/github/spec-kit)** — constitutional priority
  ordering, surgical `/clarify` and `/analyze` patterns instead of whole-file regeneration,
  and explicit constitutional governance. BELCORT's `/harness:constitution-amend` adopts
  SpecKit's high-ceremony amendment model.
- **[BMAD-METHOD V6](https://github.com/bmad-code-org/BMAD-METHOD)** — the Scrum Master
  agent pattern of per-story files with full embedded context. BELCORT's FR-4 adopts this
  as `features/NNN/stories/FR-NNN.md`, read by the Generator at the start of each TDD
  cycle.
- **[Superpowers (obra)](https://github.com/obra/superpowers)** — the adversarial 1% rule,
  mandatory brainstorming before planning, and red-flag tables enumerating the specific
  rationalizations models use to skip TDD. BELCORT imports the TDD discipline and the
  anti-reward-hacking git-archaeology scan.

---

## How it works — three-agent pipeline

Each agent runs as a **fresh subagent** via
`CLAUDE_SUBAGENT=1 claude -p ... --append-system-prompt-file`. They never share
conversation context. They communicate exclusively via files in `.harness/`. This is the
GAN insight from Rajasekaran 2026 applied to code generation: "taking inspiration from
Generative Adversarial Networks (GANs), I designed a multi-agent structure with a
generator and evaluator agent."

### Planner ([agents/planner.md](plugins/harness/agents/planner.md))

Two passes. **Pass 1**: PRD + constitution — what and why, no file paths or components.
**Pass 2**: architecture direction + evaluator criteria + draft contract + per-FR story
files. Explicitly constrained to "stay focused on product context and high level technical
design rather than detailed technical implementation" (Rajasekaran 2026) — the HOW is for
the Generator and Evaluator to negotiate. Runs a 16-point self-validation before returning.

Writes: `spec/prd.md`, `spec/constitution.md`, `spec/architecture.md`,
`evaluator/criteria.md`, `features/NNN/contract.md` (draft),
`features/NNN/stories/FR-NNN.md` (one per FR), `init.sh`, `manifest.yaml`, `ROADMAP.md`.
Tools: Read, Write, mcp__context7. No Bash (narrowest tool surface).

### Generator ([agents/generator.md](plugins/harness/agents/generator.md))

Three modes. **NEGOTIATE**: proposes the HOW (component breakdown, data model, API shape,
test strategy per AC) to `proposal.md`. **FINALIZE-CONTRACT**: merges proposal + Evaluator
review into the final `contract.md`. **BUILD**: implements with strict
RED → GREEN → REFACTOR → COMMIT TDD, reading `stories/FR-NNN.md` per TDD cycle as
canonical per-cycle context. Contains explicit red-flag tables for the specific
rationalizations models use to skip TDD, plus the reward-hacking prohibition list.

Tools: Read, Write, Bash, mcp__context7.

### Evaluator ([agents/evaluator.md](plugins/harness/agents/evaluator.md))

Two modes. **REVIEW-PROPOSAL**: reviews the Generator's implementation plan before any
code is written — the cheapest point to catch architectural risks. **EVALUATE**: exercises
the running application via Playwright MCP, grades against four criteria with hard
thresholds, and runs the reward-hacking scan (git archaeology for test deletions, skip
markers, trivial assertions, same-commit test+impl patterns). Reads calibration examples
in `evaluator/examples.md` before every scoring pass to prevent leniency drift.

The Evaluator is **always dispatched as a separate process** from the Generator. Tools:
Read, Write, Bash, mcp__playwright.

**Evaluator criteria** (template at [templates/evaluator/criteria.md.txt](plugins/harness/templates/evaluator/criteria.md.txt); the runtime copy lives at `.harness/evaluator/criteria.md` inside each project, created by the Planner):

| Criterion | Threshold | How tested |
|-----------|-----------|-----------|
| Functionality | 6/10 | Playwright: all flows + edge cases |
| Code Quality | 6/10 | Source review against constitution |
| Test Coverage | 6/10 | Run suite + TDD evidence in git log |
| Product Depth | 5/10 | Use app as a real user, try to break it |

Any criterion below threshold = FAIL → Generator retries with detailed feedback. Max 3
retries (configurable via `config.max_retries` in `manifest.yaml`).

---

## The sprint flow

Full procedure in [commands/sprint.md](plugins/harness/commands/sprint.md):

1. **Brainstorm check (opt-in)** — scans the prompt for vagueness signals; if found,
   suggests `/harness:brainstorm` before locking in direction.
2. **Doctor** — environment preflight: Claude Code CLI, MCPs (context7, playwright), Node,
   git. Hard stop on CRITICAL failures. See [commands/doctor.md](plugins/harness/commands/doctor.md).
3. **Plan (two-pass)** — Planner subagent writes PRD, constitution, architecture, criteria,
   draft contract, and per-FR story files. Runs 16-point self-validation before returning.
   Orchestrator chmods `init.sh` (Planner has no Bash — v1.5.1 fix).
4. **Analyze** — cross-artifact consistency check (PRD ↔ architecture ↔ contract).
   CRITICAL findings halt the pipeline; warnings pass through. Runs BEFORE the human gate
   so the reviewer sees any drift before being asked to approve.
5. **Human gate** — you review `spec/prd.md`, `spec/architecture.md`,
   `features/NNN/contract.md`, plus the analyze report. Options: approve, `/harness:clarify`
   (Q&A auto-patch), `/harness:amend` (surgical tweak), `/harness:rewind planning`
   (fundamentally re-plan). **Do not proceed until explicitly approved.**
6. **Negotiate** — Generator writes `proposal.md`; Evaluator writes `review.md`; iterate
   up to 3 rounds; Generator finalizes `contract.md`. "Before each sprint, the generator
   and evaluator negotiated a sprint contract: agreeing on what 'done' looked like for
   that chunk of work before any code was written." (Rajasekaran 2026)
7. **Build (TDD)** — Generator implements against the negotiated contract, one FR at a
   time, with atomic per-FR commits (`[harness:build] FR-NNN: <behavior>`).
8. **Pause check** — if Generator wrote `pause-questions.md` (genuine mid-build
   ambiguity), orchestrator surfaces the questions, collects answers, re-dispatches.
   Max 3 pauses per sprint before escalation to `/harness:rewind negotiating`.
9. **Evaluate** — Evaluator tests the running app via Playwright, grades, runs
   reward-hacking scan, writes `eval-report.md`.
10. **Tuning check** — orchestrator asks whether you agree with the Evaluator's judgment;
    divergences feed `evaluator/tuning-log.md`. Pattern detection: ≥3 entries in the same
    category triggers a `/harness:tune-evaluator` prompt.
11. **Retrospective** — mandatory drift analysis: what was spec'd vs what was built; you
    approve any spec updates.
12. **Merge** — squash merge to main, ROADMAP.md updated, retry loop if FAIL (max 3).

---

## File layout

What `.harness/` contains. Authoritative per-file writer/reader table in
[SKILL.md § File Ownership Contract](plugins/harness/skills/harness/SKILL.md).

```
.harness/
├── manifest.yaml            # Live state: phase, current_feature, current_task
├── ROADMAP.md               # Shipped / in-progress / planned (product lifetime)
├── spec/                    # Global — persists across features
│   ├── prd.md               # Product requirements
│   ├── architecture.md      # Stack + high-level direction (no file paths)
│   ├── constitution.md      # Enforceable coding rules (immutable except via /constitution-amend)
│   └── evaluator-notes.md   # Project-specific Evaluator calibration (optional)
├── features/                # Per-feature artifacts
│   └── 001-example/
│       ├── contract.md      # Final negotiated contract (Evaluator's source of truth)
│       ├── stories/         # FR-4: per-FR story files (Planner writes, Generator reads per cycle)
│       │   └── FR-001.md
│       ├── proposal.md      # Generator's HOW (from negotiation)
│       ├── review.md        # Evaluator's review (from negotiation)
│       ├── implementation-report.md
│       ├── eval-report.md
│       └── _progress.jsonl  # FR-1: live heartbeat stream
├── evaluator/
│   ├── criteria.md          # 4-criterion grading rubric
│   ├── examples.md          # Few-shot calibration examples (mandatory pre-scoring read)
│   └── tuning-log.md        # Human-Evaluator divergence log (append-only)
├── progress/
│   ├── changelog.md         # Session log (append-only)
│   ├── decisions.md         # Architecture Decision Records
│   └── known-issues.md      # Minor deferred findings
└── init.sh                  # Project health check
```

---

## Installation

Requires Claude Code 2.1+ installed and working.

### Option A — Plugin install (recommended)

```
/plugin marketplace add mosaladtaooo/belcort-harness
/plugin install harness@belcort-harness
/harness:setup
```

Registers: the harness skill, three agent prompts, 19 slash commands, three hooks
(SessionStart + PreToolUse for Bash + PreToolUse for Edit/Write), and two MCP servers
(context7, playwright). The one-time `/harness:setup` patches `~/.claude/CLAUDE.md` with
harness behavioral rules that survive context compaction. The patch is idempotent,
version-aware, and removable via `scripts/uninstall-rules.sh`.

### Option B — Manual install

```bash
git clone https://github.com/mosaladtaooo/belcort-harness.git
cd belcort-harness
./install/install.sh
```

Follow the two manual steps the installer prints: append the CLAUDE.md snippet, register
hooks in `~/.claude/settings.json`.

Verify either install:

```bash
/harness:doctor
```

---

## Quick start

```bash
# In any project directory, start Claude Code, then:
/harness:sprint "Build a minimal bookmark manager with tags and search"
```

For a 3-FR project on Opus 4.7, expect roughly 15–20 minutes and ~$8–10 in API usage,
based on the v1.5.1 real-use test (Node.js CLI, 3 FRs, 10 ACs/ECs — see
[CHANGELOG.md](CHANGELOG.md)). Rajasekaran 2026 discusses the cost/quality trade-off of
harness overhead vs single-agent runs; read the essay for the authoritative numbers and
methodology rather than trusting any specific quote here. Calibrate expectations to
project size: a 30-FR epic costs far more than a 3-FR feature.

For anything under 15 minutes of genuine work, use `/harness:quick` instead.

---

## Command reference

19 commands, grouped by category. Each links to its procedure file.

| Command | What it does | Procedure |
|---------|-------------|-----------|
| **Pipeline** | | |
| `/harness:sprint "<prompt>"` | Full pipeline: brainstorm check → doctor → plan → human gate → analyze → negotiate → build → evaluate → tune → retro → merge | [sprint.md](plugins/harness/commands/sprint.md) |
| `/harness:quick "<prompt>"` | Skip planning. Minimal contract. Single build + QA pass. For <15 min tasks. | [quick.md](plugins/harness/commands/quick.md) |
| `/harness:resume` | Recover from any interrupted phase using `manifest.yaml` + `changelog.md` | [resume.md](plugins/harness/commands/resume.md) |
| **Spec evolution** | | |
| `/harness:brainstorm "<idea>"` | Pre-plan ambiguity surfacing — extracts silent assumptions before Planner locks direction | [brainstorm.md](plugins/harness/commands/brainstorm.md) |
| `/harness:clarify` | Post-plan structured Q&A: surface ambiguities, collect answers, auto-patch specs | [clarify.md](plugins/harness/commands/clarify.md) |
| `/harness:amend "<tweak>"` | Surgical spec amendment via fresh Planner subagent (never from orchestrator context) | [amend.md](plugins/harness/commands/amend.md) |
| `/harness:edit "<change>"` | Cascade-aware multi-file spec edit (stack swaps, NFR tightening) | [edit.md](plugins/harness/commands/edit.md) |
| `/harness:steer "<nudge>"` | Mid-build guidance — Generator picks it up at next TDD cycle boundary | [steer.md](plugins/harness/commands/steer.md) |
| `/harness:rewind <phase>` | Reset current feature to earlier phase. Archive-based (reversible). Requires typed confirmation. | [rewind.md](plugins/harness/commands/rewind.md) |
| `/harness:validate` | 16-point quality audit on existing spec files | [validate.md](plugins/harness/commands/validate.md) |
| `/harness:analyze` | Cross-artifact consistency check (PRD ↔ architecture ↔ contract) | [analyze.md](plugins/harness/commands/analyze.md) |
| `/harness:negotiate` | Standalone Generator ↔ Evaluator contract negotiation | [negotiate.md](plugins/harness/commands/negotiate.md) |
| **Per-sprint** | | |
| `/harness:retrospective` | Post-merge drift analysis — spec vs what was built; propose spec updates | [retrospective.md](plugins/harness/commands/retrospective.md) |
| `/harness:tune-evaluator` | Review divergence log; propose calibration improvements (examples first, prompt changes rarely) | [tune-evaluator.md](plugins/harness/commands/tune-evaluator.md) |
| `/harness:audit` | Verification debt scan — deferred issues, stale known-issues, TODO/FIXME without owners | [audit.md](plugins/harness/commands/audit.md) |
| **v1.5 additions** | | |
| `/harness:assumption-test "<component>"` | A/B a harness component on a canary spec — LOAD-BEARING / MARGINAL / OBSOLETE verdict + mandatory ADR. Quarterly cadence. | [assumption-test.md](plugins/harness/commands/assumption-test.md) |
| `/harness:constitution-amend "<reason>"` | High-ceremony constitution change: typed confirmation + ≥50-char reason + mandatory ADR + revalidation against every completed feature | [constitution-amend.md](plugins/harness/commands/constitution-amend.md) |
| **Infrastructure** | | |
| `/harness:doctor` | Environment preflight — Claude Code, MCPs, Node, git. Auto-runs at sprint/quick start. | [doctor.md](plugins/harness/commands/doctor.md) |
| `/harness:setup` | One-time install of harness behavioral rules into `~/.claude/CLAUDE.md` | [setup.md](plugins/harness/commands/setup.md) |

---

## What's new in v1.5

Full technical detail in
[docs/feature-contracts/v1.5-trustworthy-agents-deep-alignment.md](docs/feature-contracts/v1.5-trustworthy-agents-deep-alignment.md).
Polished in v1.5.1; documented in v1.5.2.

### Critical: Claude Code 2.x compatibility fix

v1.4 and earlier inlined the full ~55KB agent role prompt as the user message of
`claude -p`. On Claude Code 2.1+ this produced empty output — dispatched subagents wrote
no files. v1.5.0 moves the agent role to `--append-system-prompt-file` and frames the
user message as an explicit mode prompt. 14 dispatch sites across 5 command files
updated. **Upgrade to v1.5.0+ is required for Claude Code 2.1+ users.**

### FR-1 — Subagent observability streaming

Addresses the subagent-opacity problem described in Trustworthy Agents: subagent
workflows "are no longer neatly visible as a single thread of actions" (verbatim). Each
subagent appends JSONL milestones to
`_progress.jsonl`; the orchestrator polls every 10s and prints `[HH:MM AGENT] phase: msg`
lines during each dispatch. Toggle via `config.observability.heartbeat: false` for silent
CI runs.

Files added: [agents/_progress-protocol.md](plugins/harness/agents/_progress-protocol.md),
[scripts/progress-poller.sh](plugins/harness/scripts/progress-poller.sh).

### FR-2 — Hook-enforced spec-file ownership

The v1.3 File Ownership Contract ("orchestrator does NOT edit spec files") was prose-only.
v1.5 promotes it to a `pre-tool-use.sh` Edit/Write check gated on `state.phase`.
Unauthorized orchestrator writes to `spec/*`, `features/*/contract.md`, and
`evaluator/criteria.md` are now mechanically blocked. Dedicated spec-edit commands
(`/amend`, `/clarify`, `/edit`, etc.) set the phase via `scripts/phase-guard.sh` at entry
and restore it at exit. Subagents (`CLAUDE_SUBAGENT=1`) bypass the gate — they are the
canonical writers.

See [SKILL.md § Enforcement (FR-2)](plugins/harness/skills/harness/SKILL.md).

### FR-3 — Mid-build pause-and-ask

Generator gains a file-based pause path for genuine mid-build ambiguity. When the
contract describes the WHAT but the HOW is genuinely underdetermined, the Generator writes
`pause-questions.md` — each question with a mandatory "default if unanswered" fallback
(anti-procrastination clause). Orchestrator surfaces questions, collects answers,
re-dispatches a fresh Generator. Max 3 pauses per sprint before escalation to
`/harness:rewind negotiating`. Risk-aversion, API uncertainty, and refactor-style choices
are explicitly listed as invalid pause reasons in `generator.md §Pause Protocol`.

Template: [templates/features/pause-questions.md.txt](plugins/harness/templates/features/pause-questions.md.txt).

### FR-4 — Per-FR story files (BMAD V6)

Planner Pass 2 emits `features/NNN/stories/FR-NNN.md` per FR — self-contained context
containing: persona snippet (only those that apply), ACs/ECs as verbatim ID references
(never paraphrased), architectural slice, applicable constitution principles, and TDD
anchor (the observable behavior to test first). Generator BUILD reads the current story at
the start of each TDD cycle; aggregate `contract.md` is consulted only for cross-FR
concerns. Strict no-paraphrase invariant enforced: story files must reference contract
sections by ID. Evaluator hash-checks for drift.

Template: [templates/features/story.md.txt](plugins/harness/templates/features/story.md.txt).

### FR-5 — Component-as-assumption stress test

Operationalises Rajasekaran 2026's direct prescription: "Every component in a harness
encodes an assumption about what the model can't do on its own, and those assumptions are
worth stress testing." New `/harness:assumption-test "<component>"` runs an A/B with and
without a named component on a user-supplied canary spec; computes per-criterion deltas;
classifies verdict as `LOAD-BEARING` / `MARGINAL` / `OBSOLETE`. Mandatory ADR every run.

Seven testable components: `brainstorm`, `negotiation`, `two-stage-eval`, `red-flags`,
`calibration-examples`, `reward-hacking-scan`, `analyze`. Quarterly cadence recommended
(each test runs a sprint twice — expensive).

See [commands/assumption-test.md](plugins/harness/commands/assumption-test.md).

### FR-6 — Constitution amendment governance

The constitution was "immutable post-init" — correct in principle, brittle in practice.
New `/harness:constitution-amend` with five ceremony stages: (1) typed confirmation
(`I-AM-AMENDING-THE-CONSTITUTION`), (2) ≥50-char reason, (3) in-progress feature
handling, (4) mandatory ADR in `progress/decisions.md`, (5) revalidation against every
completed feature via Evaluator REVALIDATE mode. This is the ONLY authorized path to
modify `spec/constitution.md` after Planner Pass 1; the FR-2 hook permits constitution
writes only when `state.phase = constitution-amending`.

See [commands/constitution-amend.md](plugins/harness/commands/constitution-amend.md).

---

## Design decisions and sources

Condensed from [docs/anthropic-alignment.md](docs/anthropic-alignment.md).
Every direct quote below is verified against the source.

| Decision | Source | Quote / note |
|----------|--------|-------|
| Three agents as separate fresh subagents | [Rajasekaran 2026](https://www.anthropic.com/engineering/harness-design-long-running-apps) | "Taking inspiration from Generative Adversarial Networks (GANs), I designed a multi-agent structure with a generator and evaluator agent." |
| Evaluator never shares context with Generator | Rajasekaran 2026 | "Separating the agent doing the work from the agent judging it proves to be a strong lever." |
| Planner scoped to product + high-level direction | Rajasekaran 2026 | "Stay focused on product context and high level technical design rather than detailed technical implementation." |
| Contract negotiation before any code | Rajasekaran 2026 | "Before each sprint, the generator and evaluator negotiated a sprint contract: agreeing on what 'done' looked like for that chunk of work before any code was written." |
| File-based agent communication | Rajasekaran 2026 | "Communication was handled via files: one agent would write a file, another agent would read it and respond either within that file or with a new file." |
| Four hard-threshold criteria | Rajasekaran 2026 | "Each criterion had a hard threshold, and if any one fell below it, the sprint failed and the generator got detailed feedback on what went wrong." |
| Few-shot calibration for Evaluator | Rajasekaran 2026 | "I calibrated the evaluator using few-shot examples with detailed score breakdowns." |
| Tuning loop for human-Evaluator divergence | Rajasekaran 2026 | "The tuning loop was to read the evaluator's logs, find examples where its judgment diverged from mine, and update the QA's prompt to solve for those issues." |
| Criteria wording shapes Generator output | Rajasekaran 2026 | "The wording of the criteria steered the generator in ways I didn't fully anticipate." |
| Human gate after planning | [Trustworthy Agents](https://www.anthropic.com/research/trustworthy-agents) | "Claude shows the user its intended plan of action up-front. The user can review, edit, and approve the whole thing before anything happens." |
| Subagent observability (FR-1, v1.5) | Trustworthy Agents | "Subagents raise new questions about how users can understand and steer workflows that are no longer neatly visible as a single thread of actions." |
| Component stress-testing (FR-5, v1.5) | Rajasekaran 2026 | "Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing." |

**Intentional deviations** from Rajasekaran 2026 (BELCORT-specific or third-party):

- Constitution as immutable post-init → from [GitHub SpecKit](https://github.com/github/spec-kit)
- TDD RED → GREEN → REFACTOR discipline → from [Superpowers](https://github.com/obra/superpowers)
- File Ownership Contract → BELCORT-specific (prevents orchestrator-authored spec edits)
- Per-FR story files → from [BMAD-METHOD V6](https://github.com/bmad-code-org/BMAD-METHOD)
- `/harness:clarify` and `/harness:amend` → patterned after SpecKit but with surgical patches
  instead of whole-file regeneration

---

## When NOT to use this

- **Trivial tasks (<15 min).** Planning overhead exceeds benefit. Use `/harness:quick` or
  no harness.
- **General agent orchestration.** Use LangGraph or CrewAI. This harness is narrowly
  scoped to software development on a single codebase.
- **Replacing human review.** The human gate after planning is mandatory; the harness
  requires a human to review the spec before build begins.
- **Fully automated CI pipelines without oversight.** The harness is designed for
  human-in-the-loop sessions; critical decisions (approve spec, review divergence) require
  a human.

---

## Migrating from v1.4 → v1.5.x

**For existing projects:**

1. **Re-run `/harness:setup`** — installs the updated CLAUDE.md snippet (picks up v1.5
   behavioral rules, including subagent isolation guard).
2. **Re-run `/harness:doctor`** — verifies new components; existing v1.4 manifests pass
   all checks.
3. **Optional:** bump `harness.version: "1.5"` in `manifest.yaml` for accurate reporting.
   Existing `config.calibration_metrics`, `tuning_debt`, etc. carry over unchanged.
4. **Optional:** add `config.observability: { heartbeat: true }` to manifest to enable
   FR-1 live progress lines.

**For new projects:** plugin install handles everything; `/harness:sprint` works
immediately.

**No breaking schema changes.** All v1.5 manifest fields have safe defaults; v1.4
manifests load without modification.

---

## Compatibility

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Claude Code | 2.1 | Required for `--append-system-prompt-file`. v1.4 silently fails on 2.x. |
| Node.js | 18 | For npx-based MCP servers (context7, playwright) |
| OS | macOS / Linux | BSD and GNU sed/awk detected at runtime in hooks and scripts |
| Model | Claude Opus 4.7 | Default. Sonnet 4.6 supported for Planner via per-agent model pinning. |

Verified on Darwin (macOS) and Linux. Windows not tested.
See [scripts/doctor.sh](plugins/harness/scripts/doctor.sh) for the full preflight check list.

---

## Limitations and known gaps

As of [v1.5.1](CHANGELOG.md):

- **`/harness:assumption-test` partial automation.** Env-var-driven components
  (`brainstorm`, `analyze`, `calibration-examples`, `reward-hacking-scan`) support full
  A/B automation. Prompt-modifying components (`red-flags`, `two-stage-eval`,
  `negotiation`) require a temporary plugin copy with manual instructions printed by the
  script. Full automation is future work.
- **No shipped canary corpus.** `/harness:assumption-test` requires a user-supplied canary
  spec. A self-test canary corpus (F13) is deferred.
- **No bats-core self-tests.** Hooks and scripts are syntax-verified (`bash -n`) but not
  integration-tested. A bats-core suite is the next P0 for repo CI.
- **Planner cannot chmod `init.sh`.** Planner subagents intentionally lack Bash access
  (narrowest tool surface). `sprint.md` chmods `init.sh` explicitly after the Planner
  dispatch returns (v1.5.1 fix).

---

## Version history

| Version | Date | Theme |
|---------|------|-------|
| **v1.5.2** | 2026-04-20 | Doc-polish release. Pipeline unchanged from v1.5.1. |
| v1.5.1 | 2026-04-20 | Polish from first real end-to-end sprint: FINALIZE-CONTRACT permission gate, Planner chmod, atomic commit enforcement. |
| v1.5.0 | 2026-04-20 | Trustworthy-Agents deep alignment (FR-1–6) + critical Claude Code 2.x dispatch fix. |
| v1.4.0 | 2026-04-20 | SpecKit/BMAD alignment: coverage matrix, two-stage eval, RED FLAGS, brainstorm, per-agent model pinning. |
| v1.3.0 | 2026-04-19 | Amendment flow (`/clarify`, `/amend`, `/steer`, `/rewind`), reward-hacking defenses, file ownership contract. |
| v1.2.0 | 2026-04-18 | Plugin conversion. No design changes from v1.0. |
| v1.0.0 | 2026-04-18 | Initial public release. |

Full release notes: [CHANGELOG.md](CHANGELOG.md).

---

## License

[MIT](LICENSE).

## Acknowledgements

- Prithvi Rajasekaran and the Anthropic Labs team for publishing the underlying research
- The Claude Code engineering team for the Agent SDK and MCP protocol
- The GitHub SpecKit, BMAD-METHOD, and Superpowers communities for the open-source
  traditions this harness builds on

Not affiliated with Anthropic.
