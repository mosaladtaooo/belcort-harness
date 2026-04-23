# BELCORT Harness

**Planner → Generator → Evaluator pipeline for Claude Code.**
File-based, git-tracked, opinionated. Adapted from Anthropic's engineering research on long-running agent harnesses.

```
user idea  →  Planner (spec)  →  Generator ↔ Evaluator negotiate  →  Generator BUILD (TDD)  →  Evaluator EVALUATE (Playwright + grade)  →  retrospective  →  merge
```

Three fresh subagents. Isolated contexts. No chat back-channel. Every decision recorded on disk. Designed so the agent doing the work never sees the agent judging it — the GAN insight from Anthropic's research, which is the single most reliable lever for producing decent code from LLMs.

---

## Why this exists

Most "AI code generators" are a single LLM doing everything — planning, coding, self-grading — in one fat context. That setup produces confident-looking but fragile output: the generator reliably praises its own work, misses edge cases because its context is already contaminated with its own assumptions, and skips tests it knows are failing.

The fix — documented in [*Harness design for long-running application development*](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Rajasekaran 2026) — is **specialization through decomposition with isolated contexts**:

> *"Separating the agent doing the work from the agent judging it proves to be a strong lever."*

BELCORT is a production-grade implementation of that harness, shipped as a Claude Code plugin.

---

## Quick start

### Install

In Claude Code:

```
/plugin marketplace add https://github.com/mosaladtaooo/belcort-harness.git#v2-beta
/plugin install harness@belcort-harness
/reload-plugins
```

Verify: `/plugin` → Installed tab → `harness@2.1.1`. `/agents` → three custom agents listed: `harness:planner`, `harness:generator`, `harness:evaluator`.

### Initialize a project

```
cd path/to/your/project
/harness:doctor      # verify environment (MCPs, Node, git)
/harness:setup       # scaffolds .harness/ + project-local ./CLAUDE.md
```

### Run your first sprint

```
/harness:sprint "build a 2-FR todo app: user can add a todo with title; user can mark a todo complete"
```

Observe the full pipeline: Planner drafts spec → analyze auto-runs → human approval gate → Generator ↔ Evaluator negotiate the contract → Generator BUILD via TDD with atomic per-FR commits → Evaluator EVALUATE exercises the running app via Playwright and grades against 4 criteria with hard thresholds → tuning check captures any divergence between the Evaluator's judgment and yours → retrospective reconciles spec with what actually shipped → merge.

---

## The Anthropic philosophy (what this harness encodes)

Four principles from Rajasekaran 2026, quoted verbatim, and where each lives in BELCORT:

1. **Simplest solution first.** *"Find the simplest solution possible, and only increase complexity when needed."* Every component of this harness earns its existence. If you can't articulate the failure mode a component prevents on current models, it's slated for removal in the next assumption-test cycle.

2. **Every component encodes a stale-able assumption.** *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."* v2.0 removed ~900 lines of v1.3/1.4/1.5 defensive machinery whose assumptions no longer held on Opus 4.7 (progress-poller, phase-guard hook, `/harness:steer`, `/harness:assumption-test`, per-agent model pinning).

3. **File-based communication.** *"Communication was handled via files: one agent would write a file, another agent would read it."* Every subagent dispatch writes output to `.harness/features/NNN/*.md` — the orchestrator reads files, never conversation. The agent doing the work and the agent judging it share disk, not context.

4. **Context isolation is non-negotiable.** *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* Evaluator NEVER shares context with Generator. v2.1 migrated from `claude -p` subprocess dispatch to native Agent-tool dispatch — same isolation guarantee, 47% less boilerplate.

Plus one Trustworthy-Agents principle:

5. **Calibrated uncertainty beats confident guessing.** *"Models are trained through scenarios that place Claude in ambiguous situations, and then reinforce Claude's choice to pause."* The Generator has a pause protocol: when a mid-build ambiguity exceeds what Context7 or the contract can resolve, it writes `pause-questions.md` with a "default if unanswered" fallback per question, and the orchestrator surfaces them to the user. Procrastination is explicitly forbidden — every pause must document what the agent would do if the user ignored the question.

---

## The three agents

| Agent | Subagent type | Job | Tools | Modes |
|---|---|---|---|---|
| **Planner** | `harness:planner` | Expands a 1-4 sentence prompt into a product-grade spec (PRD + constitution + architecture + evaluator criteria + per-FR stories + build contract) | Read, Write, Context7 MCP | PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND |
| **Generator** | `harness:generator` | Negotiates the contract's HOW, then implements it via TDD. Delegates RED→GREEN→REFACTOR to `superpowers:test-driven-development`. Atomic per-FR commits. | Read, Write, Bash, Context7 MCP | NEGOTIATE, FINALIZE-CONTRACT, BUILD |
| **Evaluator** | `harness:evaluator` | Adversarial tester. Runs the built app through Playwright, grades against 4 criteria with hard thresholds, runs git-archaeology reward-hacking scan, produces pass/fail verdict with specific findings. | Read, Write, Bash, Playwright MCP | REVIEW-PROPOSAL, EVALUATE, REVALIDATE |

Each agent has a `<SUBAGENT-CONTEXT>` block at the top of its system prompt that explicitly forbids re-invoking the harness pipeline or dispatching further subagents. Subagents do ONE job per dispatch, write output to a file, and exit.

### Pipeline (canonical sprint flow)

```
/harness:sprint "<prompt>"
  │
  ├─ doctor preflight (blocks on CRITICAL env failures)
  ├─ Planner (PLAN mode, 2 passes: Pass 1 PRD+constitution, Pass 2 architecture+criteria+contract+stories)
  ├─ analyze (automatic cross-artifact consistency)
  ├─ HUMAN GATE — approve | /clarify | /amend | /edit | /rewind planning
  ├─ Generator (NEGOTIATE) → proposal.md
  ├─ Evaluator (REVIEW-PROPOSAL) → review.md  [iterate ≤3 rounds]
  ├─ Generator (FINALIZE-CONTRACT) → contract.md (final, with **Negotiated**: marker)
  ├─ Generator (BUILD via superpowers:test-driven-development) → source code + atomic commits + implementation-report.md
  │     ↳ may pause mid-build via pause-questions.md → orchestrator collects answers → re-dispatch
  ├─ Evaluator (EVALUATE) — calibration-mandatory examples.md read → Playwright test → Part-A binary gates Part-B numeric → reward-hacking git-archaeology scan → eval-report.md
  ├─ Tuning check — user agrees/disagrees with Evaluator; divergences logged to tuning-log.md
  ├─ if PASS → retrospective (drift analysis) → merge → manifest.phase = complete
  └─ if FAIL (retries < max) → Generator BUILD again with eval-report.md as retry context
```

---

## The 17 commands

### Entry points

| Command | When to use |
|---|---|
| `/harness:sprint "<prompt>"` | Full pipeline. Use for features >15 min of work, multiple components, novel decisions, or anything touching architecture. |
| `/harness:quick "<prompt>"` | Fast path. Skip Planner, write a minimal 2-4 AC contract inline, single Generator → Evaluator pass. Use for <30 min scoped tweaks with obvious approach. |
| `/harness:resume` | Recover from an interrupted sprint. Reads manifest + changelog + git log, dispatches the right subagent for the current phase. |
| `/harness:brainstorm "<vague idea>"` | Pre-plan exploration for ambiguous prompts (<2 sentences, "maybe", "not sure"). Interviews the user, writes `.harness/brainstorm-current.md`, which the next `/harness:sprint` consumes as additional context. |

### Spec-edit (fresh Planner dispatch + mechanical patch apply)

| Command | Purpose |
|---|---|
| `/harness:clarify` | Post-plan Q&A round. Planner identifies ambiguities, user answers, surgical patches applied. |
| `/harness:amend "<change>"` | Single-file targeted spec tweak (usually PRD or architecture). |
| `/harness:edit "<change>"` | Cascade-aware multi-file spec edit (stack swap, NFR tightening, anything touching ≥2 files). Auto-runs `/analyze` then `/validate`. |
| `/harness:constitution-amend "<reason ≥50 chars>"` | High-ceremony 5-gate constitutional change: typed confirmation, in-progress-feature handling, NEW-constitution vs current-spec analyze, per-feature REVALIDATE by Evaluator, mandatory ADR, final apply confirmation. |

All spec-edit commands follow the same safety protocol: **the orchestrator never authors spec content**. A fresh Planner subagent (clean context) produces patches to a `*-patches.md` file; the orchestrator presents diffs to the user; approved patches are applied mechanically via the Edit tool. This keeps the orchestrator's fat chat context out of spec files.

### Audit family

Five distinct questions, five distinct tools:

| Command / mode | Question it answers |
|---|---|
| `/harness:analyze` | *"Are the spec files internally consistent right now?"* (PRD ↔ architecture ↔ contract ↔ criteria — cross-reference integrity) |
| `/harness:validate` | *"Is every spec section complete and quality-gated?"* (16-point V1–V16 checklist) |
| `/harness:audit` | *"Do shipped features have deferred debt, stale known-issues, suspicious skip markers?"* (cross-feature, historical) |
| Evaluator REVALIDATE mode | *"Does each previously-shipped feature still comply with the NEW constitution?"* (only inside `/harness:constitution-amend`) |
| `/harness:retrospective` | *"Did the implementation drift from the spec?"* (post-build contract ↔ reality reconciliation) |

Mnemonic: **analyze** = consistency, **validate** = completeness, **audit** = debt, **REVALIDATE** = backward-compat, **retrospective** = reality.

### Phase management + lifecycle

| Command | Purpose |
|---|---|
| `/harness:negotiate` | Standalone Generator↔Evaluator negotiation (normally auto-invoked by sprint). |
| `/harness:rewind <phase>` | Archive-based reset to `planning` \| `analyzing` \| `negotiating` \| `building` \| `evaluating`. Files move to `.archive/TIMESTAMP/`, never deleted. Requires typed confirmation. |
| `/harness:tune-evaluator` | Review Evaluator divergence patterns from `tuning-log.md`; propose new calibration examples or (rarely) prompt edits. |
| `/harness:setup` | Project-local install: creates `.harness/` + `./CLAUDE.md` activation block. Idempotent. |
| `/harness:doctor` | Environment preflight. Blocks on CRITICAL failures (missing MCPs, no jq/python, outdated Node). Auto-runs at sprint/quick start. |

---

## File ownership contract

Every file under `.harness/` has exactly one writer. If you're not the designated writer, you're a reader.

| File | Writer |
|---|---|
| `manifest.yaml` | Orchestrator (state transitions); Planner (initial features); Generator BUILD (current_task per FR) |
| `spec/prd.md`, `spec/architecture.md`, `spec/constitution.md` | Planner — never the orchestrator directly |
| `evaluator/criteria.md`, `evaluator/examples.md` | Planner (init), orchestrator (during tuning check) |
| `features/NNN/contract.md` — draft | Planner |
| `features/NNN/contract.md` — final | Generator FINALIZE-CONTRACT (overwrites draft, MUST include `**Negotiated**:` marker) |
| `features/NNN/stories/FR-NNN.md` | Planner Pass 2; Generator BUILD may refine |
| `features/NNN/proposal.md` | Generator NEGOTIATE |
| `features/NNN/review.md` | Evaluator REVIEW-PROPOSAL |
| `features/NNN/implementation-report.md` | Generator BUILD |
| `features/NNN/eval-report.md` | Evaluator EVALUATE |
| `features/NNN/{amend,clarify,edit}-patches.md` | Planner (AMEND/CLARIFY-APPLY/EDIT modes) |
| `features/NNN/pause-questions.md` | Generator BUILD (mid-build clarification) |
| `.harness/constitution-amend-patches.md` | Planner CONSTITUTION-AMEND |
| `progress/changelog.md` | All agents append |
| `progress/decisions.md` | Orchestrator (ADR on any spec/prompt change) |
| `progress/known-issues.md` | Orchestrator (via retrospective) |

Rationale: the orchestrator's context contains the whole conversation; subagents have clean contexts. Letting the orchestrator edit spec files leaks conversational noise into the spec, which downstream subagents then inherit. The rule is prose-enforced (no mechanical hook in v2) and backstopped by the Evaluator's retrospective, which catches drift.

---

## v2 architecture — what changed from v1.x

### Subagent dispatch: `claude -p` subprocess → native Agent tool

**v1.x** shelled out for every dispatch:
```bash
CLAUDE_SUBAGENT=1 claude -p "<prompt>" \
  --append-system-prompt-file "agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

**v2.1+** uses Claude Code's native plugin-declared subagent types:

```
Agent tool → subagent_type: "harness:planner"
           → prompt: "You are being dispatched in PLAN mode..."
```

Cleaner, faster (no subprocess startup), no env-var isolation tricks, parallel dispatch available, structured return values.

### Installation: global CLAUDE.md → project-local CLAUDE.md

**v1.x** wrote rules into `~/.claude/CLAUDE.md`, polluting every Claude Code session with harness activation logic whether or not the current project used the harness.

**v2.0+** `/harness:setup` creates project-local `./CLAUDE.md` with a `BELCORT-HARNESS BEGIN v2` block. Scoped to projects that actually use the harness.

Legacy global installs: run `scripts/uninstall-rules.sh` once to remove the old block from `~/.claude/CLAUDE.md`.

### Commands removed

- **`/harness:steer`** — redundant with `/harness:amend` (for spec changes) and the evaluator retry loop (for quality issues).
- **`/harness:assumption-test`** — meta-audit tool that was never actually run in practice. Manual A/B is a 5-minute task when needed.

### Machinery removed

- **`progress-poller.sh` + heartbeat protocol** (~350 lines) — `claude -p` stdout already streams to the orchestrator; the poller solved a problem that didn't exist on modern Claude Code.
- **`phase-guard.sh` + FR-2 spec-edit hook** (~100 lines) — Opus 4.7 follows the prose "orchestrator doesn't edit spec files" rule. The mechanical enforcement hook was belt-and-suspenders that broke when tool namespaces changed.
- **Per-agent model pinning** (`config.models.{planner,generator,evaluator}`) — undocumented, unused.

### Audit matrix clarified

Added dedicated auto-invocations so users don't have to remember which audit to run when:

- `/amend` → auto-runs `/analyze` (consistency)
- `/edit` → auto-runs `/analyze` + `/validate` (consistency + completeness — cascade edits deserve both)
- `/clarify` → auto-runs `/analyze`
- `/constitution-amend` → includes a NEW-constitution vs current-spec `/analyze` gate BEFORE per-feature REVALIDATE (catches contradictions cheaply)

---

## Project-specific tools and MCPs

Subagents inherit the parent Claude Code session's full tool set — any MCP or skill you've installed is available. To guide the harness subagents toward project-specific tools:

1. Install the tool at the session level (not inside the plugin):
   ```
   claude mcp add figma -- npx -y @figma/mcp@latest
   /plugin install elements-of-style@some-marketplace
   ```

2. Edit your project's `./CLAUDE.md` (created by `/harness:setup`) and populate the `## Project-specific tools / MCPs / skills` section:
   ```markdown
   ### Project tools
   - **`mcp__figma`** — Planner may query for component trees when the PRD references an existing Figma design.
   - **`elements-of-style` skill** — Generator invokes this before writing any user-facing copy.
   ```

3. The orchestrator reads project CLAUDE.md before every subagent dispatch and includes relevant tool guidance in the Agent-tool `prompt` parameter under a `--- PROJECT TOOLS ---` marker.

No need to edit plugin files. Access is via inheritance; knowledge of when to use a tool is via project CLAUDE.md.

---

## Recommended companion plugins

None are required; each enhances a specific phase.

| Plugin | Used by | What it adds |
|---|---|---|
| [`superpowers`](https://github.com/obra/superpowers) | Generator BUILD | TDD skill (`test-driven-development`) drives the RED→GREEN→REFACTOR cycle. Strongly recommended. |
| `frontend-design` | Planner (Pass 2), Generator UI work | Design tokens + layout patterns for polished UI |
| `security-guidance` | Generator (pre-commit), Evaluator (Code Quality) | OWASP top-10 checks, secret-detection |
| `agentlint` | Evaluator Code Quality | 33 evidence-backed automated code checks |

`/harness:doctor` lists these and warns if missing.

---

## Directory layout

```
.harness/
├── manifest.yaml              # Single source of truth for project state
├── ROADMAP.md                 # Shipped / in-progress / planned features
├── init.sh                    # Project-health check (customize per stack)
├── spec/
│   ├── prd.md                 # Product requirements (WHAT + WHY, zero tech)
│   ├── architecture.md        # High-level tech direction (stack, ADRs)
│   ├── constitution.md        # 17 testable coding principles
│   └── evaluator-notes.md     # Project-specific calibration notes
├── evaluator/
│   ├── criteria.md            # 4-criterion rubric with hard thresholds
│   ├── examples.md            # 12 seeded few-shot calibration examples
│   └── tuning-log.md          # Evaluator-human divergence log
├── features/NNN-feature-name/
│   ├── contract.md            # Draft (Planner) → Final (Generator FINALIZE)
│   ├── stories/FR-NNN.md      # Per-FR build context (Planner Pass 2)
│   ├── proposal.md            # Generator's HOW (NEGOTIATE mode)
│   ├── review.md              # Evaluator's review of proposal
│   ├── implementation-report.md  # Generator's handoff after BUILD
│   ├── eval-report.md         # Evaluator's verdict (PASS/FAIL + findings)
│   ├── analysis-report.md     # /harness:analyze output
│   ├── retrospective.md       # /harness:retrospective drift analysis
│   └── .archive/TIMESTAMP/    # Rewind-archived files
└── progress/
    ├── changelog.md           # Append-only activity log (all agents)
    ├── decisions.md           # ADR log (orchestrator)
    └── known-issues.md        # Retrospective debt
```

All paths are relative to your project root. The harness never touches files outside `.harness/` except during Generator BUILD (source code + git commits) and the `./CLAUDE.md` activation rule file.

---

## Troubleshooting

### `Validation errors: agents: Invalid input` during `/plugin install`

You're on an older tag. v2.1.0+ uses the correct array format. Update: `/plugin marketplace remove belcort-harness && /plugin marketplace add https://github.com/mosaladtaooo/belcort-harness.git#v2-beta && /plugin install harness@belcort-harness`.

### Safety rails (force-push block, sudo block, .harness/ deletion block) seem inactive on Windows

Windows ships a `python3.exe` Microsoft Store PATH stub that resolves via `command -v python3` but doesn't execute. v2.1.1+ probes actual execution and falls back to `python` (3.x). Upgrade or install jq: `winget install jqlang.jq`.

### AgentLint hook errors look like mangled paths on Windows

If you see errors like `/usr/bin/bash: line 1: C:UserszhantAppDataLocalProgramsPythonPython312Scriptsagentlint.EXE: command not found`, the backslashes in the Windows path are being stripped inside MSYS/Git-Bash (the `\U`, `\A`, `\L` sequences eat themselves). This is an **AgentLint bug**, not belcort-harness — report upstream or uninstall agentlint if the noise bothers you. The error is tagged `non-blocking` and doesn't affect the harness pipeline.

### Generator paused because npm / npx / pnpm is blocked

Claude Code's default Bash-permission system may prompt or block npm-family commands. Generator BUILD can't run tests without them, so it pauses gracefully (pause-protocol working as designed). Fix by pre-allowing in Claude Code:

```
/allow Bash(npm *) Bash(npx *) Bash(pnpm *) Bash(node *)
```

Or add to `.claude/settings.json` → `permissions.allow`. Then `/harness:resume` — Generator picks up where it paused. `/harness:doctor` (v2.1.2+) warns if your settings don't pre-allow these commands.

### Evaluator can't find Playwright / Planner can't find Context7

Run `/harness:doctor`. It checks MCP registration. If missing:
```
claude mcp add playwright -- npx -y @playwright/mcp@latest
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
```
Or reinstall the harness plugin — its `.mcp.json` registers both automatically.

### "subagent_type 'harness:planner' not recognized"

Run `/reload-plugins`. If that doesn't work, restart Claude Code (close + reopen) — plugin.json's `agents` declaration is picked up on session start.

### Generator seems to skip TDD

Superpowers plugin missing. Install: `/plugin install superpowers@claude-plugins-official`. Generator BUILD mode delegates the RED→GREEN→REFACTOR cycle to `superpowers:test-driven-development`.

### Sprint interrupted mid-build

Run `/harness:resume`. It reads manifest + changelog + `git log --oneline | grep 'harness:'` and re-dispatches the correct subagent for the current phase. Mid-build recovery is supported — Generator BUILD reads `state.current_task` and skips already-completed FRs.

### Something went wrong; want to restart from an earlier phase

`/harness:rewind <phase>` archives current-phase artifacts to `.harness/features/NNN/.archive/TIMESTAMP/` and resets manifest state. Valid targets: `planning`, `analyzing`, `negotiating`, `building`, `evaluating`. Requires typed confirmation. Not destructive — archived files are recoverable.

---

## Design spec + implementation history

For full rationale behind every v2 change:
- `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md` — the design spec
- `docs/superpowers/plans/2026-04-21-belcort-v2-minimalist-refactor.md` — the 32-task implementation plan
- `docs/anthropic-alignment.md` — point-by-point trace from BELCORT design decisions back to Anthropic's engineering articles
- `CHANGELOG.md` — version history (v2.0.0 minimalist rewrite, v2.1.0 native Agent-tool dispatch, v2.1.1 project-tool propagation)

---

## References

**Primary sources:**
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Prithvi Rajasekaran, Anthropic Labs, 2026
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Anthropic Labs
- [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents) — Anthropic Research

**Adjacent influences:**
- [GitHub Spec Kit](https://github.com/github/spec-kit) — constitutional governance, clarify/amend patterns
- BMAD V6 — per-FR story files (Scrum Master pattern), two-pass Planner
- [Superpowers](https://github.com/obra/superpowers) — TDD skill, systematic-debugging, verification-before-completion, the 1% skill-activation rule

---

## Status

**v2.1.6 on `v2-beta` branch** (current) — iterating through live stress-test findings:
- v2.1.0 — native Agent-tool dispatch (plugin-declared `harness:planner/generator/evaluator` subagent types), migrated from `claude -p` subprocess pattern
- v2.1.1 — dropped `tools:` frontmatter allowlist (subagents inherit parent session's tool set); project-tools propagation via `./CLAUDE.md`
- v2.1.2 — stress-test patches: Windows python3-stub detection, `/quick` spec-drift check, `/clarify` ADR gap closed, doctor.sh checks for pre-allowed npm permissions + superpowers plugin
- v2.1.3 — removed ~413 lines of inline template duplication (5 templates → `@`-references + invariants); REVIEW-PROPOSAL now reads constitution.md + architecture.md to catch HOW-level violations the contract doesn't constrain
- v2.1.4 — aligned Evaluator tuning category vocabulary (fixes silent drop of `Wrong severity` / `Out of scope` entries); added watch-list for 1-2-entry categories in `/harness:tune-evaluator`; promoted 3-round negotiation rationale into `negotiate.md` Procedure with sharper escalation UX; added retrospective-vs-tuning clarifier to `SKILL.md`
- v2.1.5 — Planner feature-size gate (prevent oversized dispatches that exhaust Claude Code subagent budgets mid-build); pre-TDD scaffolding commit rule in `generator.md` (non-behavioral work now commits at logical group boundaries, not just post-FR); SKILL.md Recovery section expanded with hard-stop-mid-scaffolding case
- v2.1.6 — doc patch: replaced broken `.agentlint.toml` (never loaded — AgentLint reads `agentlint.yml`, not TOML) with proper `agentlint.yml`. `max-file-size` limit now set to 1500 globally since the rule supports only one `limit` option (verified in AgentLint source); rationale preserved as inline YAML comments.

See [`CHANGELOG.md`](CHANGELOG.md) for per-release detail. See [`ROADMAP.md`](ROADMAP.md) for the v3 watch list + parked items.

**v1.5.2 on `main`** — prior stable. Migration notes above. For existing installs, run `scripts/uninstall-rules.sh` once to remove the legacy global `~/.claude/CLAUDE.md` block, then `/harness:setup` in each project.

**License**: MIT.
**Author**: BELCORT AI Consulting `<tools@belcort.com>`.
**Repository**: https://github.com/mosaladtaooo/belcort-harness
