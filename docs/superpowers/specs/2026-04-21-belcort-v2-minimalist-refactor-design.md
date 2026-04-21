# BELCORT Harness v2 — Minimalist Refactor (Design Spec)

**Date**: 2026-04-21
**Target model**: `claude-opus-4-7` (per `templates/manifest.yaml:7`)
**Refactor scope**: Option A (aggressive / minimalist) — remove any component that can't justify itself as load-bearing on Opus 4.7, consolidate duplication, demote hardcoded bash to natural-language instructions where the orchestrator can judge-and-execute via tool calls.

---

## 1. Context & Motivation

The BELCORT Harness has accumulated three versions of defensive machinery (v1.3, v1.4, v1.5) on top of the Anthropic-research core. The user's assessment: "we make this harness engine bloated after implemented bunch of feature that refered other harness framework like superpowers, gsd, specify." This refactor removes the accretion while preserving the Anthropic-aligned core, per the ruler below.

**What IS the Anthropic-aligned core (must preserve):**
- Three fresh subagents with isolated contexts (Planner, Generator, Evaluator).
- File-based communication under `.harness/features/NNN/*.md`.
- Generator↔Evaluator negotiation before code is written.
- Four-criterion grading with hard thresholds and few-shot calibration examples.
- Evaluator uses Playwright MCP to exercise the running app.
- Tuning loop that captures human-evaluator divergence and evolves calibration.
- Two-stage grading: Part A binary FR compliance gates Part B numeric quality scoring.
- Adversarial anti-leniency framing in the Evaluator prompt.
- Reward-hacking scan during EVALUATE mode (git archaeology for test deletions, skip markers, trivial assertions, etc.).

**What must be removed or simplified (accretion):**
- Global CLAUDE.md installation (pollutes non-harness sessions).
- Progress-poller + heartbeat infrastructure (`claude -p` streams stdout live; poller is solving a problem that doesn't exist on Opus 4.7).
- Phase-guard + FR-2 Edit/Write hook (mechanical enforcement of a prose rule that Opus 4.7 follows when stated).
- Assumption-test command + script (nobody runs it — `manifest.last_assumption_test` is empty).
- `/harness:steer` (third mid-build interrupt path blurring amend vs retry-loop).
- Per-agent model pinning config (unused, undocumented).
- Inline template content duplicated across agent files and template `.txt` files.
- Inline bash recipes for file-move/chmod/manifest-sed operations the orchestrator can do intelligently.

---

## 2. The Ruler (verbatim Anthropic + user-stated constraints)

**Anthropic's harness-design principles** (https://www.anthropic.com/engineering/harness-design-long-running-apps):
1. *"Find the simplest solution possible, and only increase complexity when needed."*
2. *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."*
3. *"Communication was handled via files: one agent would write a file, another agent would read it."*
4. Continuous-session on modern models: *"With Opus 4.6 I dropped context resets from this harness entirely."*
5. *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* — GAN isolation, non-negotiable.

**User-stated constraints:**
6. No content duplication — each fact lives in exactly one place; other files reference it.
7. Natural-language orchestrator instructions over hardcoded bash recipes where intelligence beats script.
8. Project-scoped state — rules + behavior activate only in harness projects.
9. All md/skill/core judge-decision must be smooth, CLEAR, and have NO CONFLICT.

---

## 3. Scope

### In scope
- Restructure `SKILL.md` to be the main skill (auto-invoked via Skill tool, like `superpowers:using-superpowers`).
- Shrink CLAUDE.md installation to project-local, ~20 lines.
- Consolidate templates to `plugins/harness/templates/` (single source of truth).
- Replace inline template content in agent files with `@` references.
- Replace inline bash recipes in command files with natural-language orchestrator instructions (keep bash only for `claude -p` dispatch, git worktree, hook contents).
- Remove obsolete components: progress-poller, phase-guard, assumption-test, steer, per-agent model pinning, heartbeat protocol.
- Simplify rewind.md (267 → ~80 lines).
- Simplify pre-tool-use.sh (drop FR-2 check; keep force-push/sudo/.harness-deletion/test-file-deletion guards).
- Reference `superpowers:test-driven-development` skill instead of inlining the RED/GREEN/REFACTOR procedure.
- Reference AgentLint/Security optional plugins in ONE place (`SKILL.md`).
- Add to `SKILL.md`: Pipeline Timing section, Orchestrator Behavior section, Template Index, Optional Plugins, State Persistence, State Awareness, Recovery.

### Out of scope
- Changes to the agent prompts' core decision logic (RED FLAGS tables, MODE routing, anti-leniency protocol, reward-hacking scan). Those stay.
- Changes to the actual pipeline phases (plan → analyze → negotiate → build → evaluate → retrospective).
- Adding new features.
- Changing the manifest schema beyond removing unused fields.

---

## 4. Target Architecture

### Pipeline (canonical, after refactor)

```
user prompt
   │
   ├─ [SessionStart hook] one-line nudge: "Harness detected; invoke the harness skill."
   │
   └─ [harness SKILL.md auto-invokes via Skill tool]
         │  Description matches trigger phrases (build, implement, new feature, etc.)
         │  OR user typed /harness:sprint "<prompt>"
         │
         ├─ [doctor.sh preflight]   — blocks on CRITICAL, warns on RECOMMENDED
         │
         ├─ [Planner subagent, PLAN mode, 2-pass]
         │    Pass 1: prd.md + constitution.md
         │    Pass 2: architecture.md + criteria.md + contract.md draft + stories/ + init.sh + roadmap + manifest
         │    Self-validation: 16-point checklist (planner owns)
         │
         ├─ [analyze automatic] — cross-artifact consistency (orchestrator-only)
         │    CRITICAL findings halt; warnings inform
         │
         ├─ [HUMAN GATE]
         │    approve   → negotiate
         │    /clarify  → Planner(CLARIFY-QUESTIONS) then Planner(CLARIFY-APPLY) then analyze
         │    /amend "<X>"  → Planner(AMEND) then analyze
         │    /edit "<X>"   → Planner(EDIT, cascade-aware) then analyze
         │    /rewind planning → archive & restart
         │
         ├─ [Generator(NEGOTIATE)] → proposal.md
         ├─ [Evaluator(REVIEW-PROPOSAL)] → review.md
         │    iterate ≤3 rounds; escalate to human if no agreement
         ├─ [Generator(FINALIZE-CONTRACT)] → contract.md (final, with **Negotiated**: marker)
         │
         ├─ [Generator(BUILD, TDD)]
         │    Reads per-FR story at features/NNN/stories/FR-NNN.md per cycle
         │    Uses superpowers:test-driven-development for RED/GREEN/REFACTOR
         │    BELCORT addition: atomic commit per FR `[harness:build] FR-NNN: <behavior>`
         │    BELCORT addition: append to progress/changelog.md per commit
         │    May pause: writes pause-questions.md → orchestrator surfaces → re-dispatch
         │    Outputs: source code, commits, implementation-report.md
         │
         ├─ [Evaluator(EVALUATE)]
         │    Reads examples.md FIRST (calibration)
         │    Playwright-tests the running app (happy + edge + error paths)
         │    Code quality review against constitution
         │    Test suite + TDD evidence scan (git archaeology)
         │    Reward-hacking scan (Step 4.5)
         │    Part A: binary FR/AC compliance (gates)
         │    Part B: 4-criterion numeric scoring
         │    Outputs: eval-report.md
         │
         ├─ [tuning check automatic]
         │    User: agree / disagree / partial
         │    If divergence: append to tuning-log.md, optionally examples.md
         │
         ├─ PASS → [retrospective] → merge → manifest.phase=complete
         │
         └─ FAIL (retries<max) → Generator(BUILD) with eval-report.md as retry context
             FAIL (retries≥max) → human decision (force-merge / manual-fix / max-increase / abandon)
```

### File structure (after refactor)

```
plugins/harness/
  .claude-plugin/
    plugin.json                       # version, name, description
  .mcp.json                           # context7 + playwright
  CLAUDE.md.snippet.txt              # ~20 lines, activation-only
  skills/harness/
    SKILL.md                         # MAIN skill — auto-invoked, pipeline+contract
  agents/
    planner.md                       # PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND
    generator.md                     # NEGOTIATE, FINALIZE-CONTRACT, BUILD
    evaluator.md                     # REVIEW-PROPOSAL, EVALUATE, REVALIDATE
    # DELETED: _progress-protocol.md
  commands/
    sprint.md                        # the full-pipeline procedure (≈250 lines, natural-language flow + minimal bash)
    quick.md                         # fast-path (≈80 lines)
    resume.md                        # ~5-line stub → SKILL.md § Recovery
    setup.md                         # project-local CLAUDE.md install + doctor
    doctor.md                        # thin wrapper over scripts/doctor.sh
    clarify.md                       # Planner(CLARIFY-*) dispatch + patch apply
    analyze.md                       # orchestrator-only consistency check
    amend.md                         # Planner(AMEND) dispatch + patch apply
    edit.md                          # Planner(EDIT, cascade) dispatch + patch apply
    negotiate.md                     # standalone negotiation re-run
    validate.md                      # 16-point static audit (references planner.md § self-validation)
    audit.md                         # verification-debt scan
    retrospective.md                 # drift analysis
    tune-evaluator.md                # calibration
    rewind.md                        # ~80 lines, simplified
    brainstorm.md                    # pre-plan ambiguity exploration
    constitution-amend.md            # high-ceremony constitutional change
    # DELETED: steer.md, assumption-test.md
  hooks/
    hooks.json                       # SessionStart + PreToolUse
    session-start.sh                 # ~10 lines — one-line nudge only
    pre-tool-use.sh                  # ~120 lines — force-push/sudo/.harness/test-file guards
  scripts/
    doctor.sh                        # ~300 lines, simplified
    setup.sh                         # new: project-local init (replaces install-rules.sh global write)
    uninstall-rules.sh               # kept as cleanup shim for users who installed globally pre-v2
    # DELETED: progress-poller.sh, phase-guard.sh, assumption-test.sh
    # MERGED: install-rules.sh → setup.sh
  templates/                         # SINGLE source of truth for all templates
    manifest.yaml
    ROADMAP.md
    init.sh.txt
    CLAUDE.md.project.txt            # new: project-local snippet template
    evaluator/
      criteria.md.txt
      examples.md.txt
      tuning-log.md.txt
    features/
      contract.md.txt
      proposal.md.txt
      review.md.txt
      implementation-report.md.txt
      eval-report.md.txt
      story.md.txt
      pause-questions.md.txt
    spec/
      evaluator-notes.md.txt
    progress/
      changelog.md
      decisions.md
      known-issues.md

# DELETED at repo root: templates/  (dev-only duplicate; merged into plugin templates/)

docs/
  anthropic-alignment.md             # keep — useful decision map
  feature-contracts/                 # historical, keep as-is
  superpowers/
    specs/
      2026-04-21-belcort-v2-minimalist-refactor-design.md  # this doc
```

### Canonical paths & single-source-of-truth rules

| Concept | Canonical source | Referenced by |
|---|---|---|
| Pipeline stages + timing | `SKILL.md § Pipeline` | sprint.md, quick.md, resume.md |
| Agent roles + MODE table | `SKILL.md § Agents` | `agents/{planner,generator,evaluator}.md` frontmatter |
| File ownership contract | `SKILL.md § File Ownership` | (prose rule; no mechanical hook) |
| TDD procedure | `superpowers:test-driven-development` skill (external) | generator.md BUILD mode references it |
| 16-point self-validation | `agents/planner.md § Self-Validation` | validate.md references this section |
| Evaluator criteria rubric | `templates/evaluator/criteria.md.txt` | planner.md PLAN mode, evaluator.md |
| Manifest schema | `templates/manifest.yaml` | SKILL.md references; no duplicate |
| Artifact templates (contract, proposal, review, etc.) | `templates/features/*.md.txt` | agent md files reference via `@` |
| Optional plugins (AgentLint, Security Guidance, Frontend Design) | `SKILL.md § Optional Plugins` | agent md files reference this section |
| Reward-hacking prohibitions | `agents/generator.md § REWARD-HACKING — FORBIDDEN` | pre-tool-use.sh comment + evaluator.md Step 4.5 |
| ADR format | `templates/progress/decisions.md` (template comment block) | all commands that append ADRs |

**Rule**: If a second file wants to describe any of these concepts, it writes a one-liner referencing the canonical source via `@` prefix. No re-statement, no summary.

---

## 5. Concrete Changes

### 5.1 `CLAUDE.md.snippet.txt` (72 → ~20 lines)

**Before**: 72 lines containing three-agents table, 1% rule, session-start behavior, trigger words, red flags, commands table, rules (duplicates SKILL.md).

**After**: ~20 lines. Activation-only:
- Header: "BELCORT Harness Engine is available in this project."
- 1% rule (one paragraph).
- Trigger-word detection (one paragraph).
- Pointer: "For pipeline, file ownership, TDD, and all other contracts, see the harness skill via the Skill tool."

### 5.2 `SKILL.md` (237 → ~180 lines after additions + deletions)

**Delete**:
- Lines 199-207 (Evaluator Criteria 4-row table) — reference `@templates/evaluator/criteria.md.txt` instead.
- Lines 210-227 (Manifest schema) — reference `@templates/manifest.yaml` instead.

**Keep as-is**:
- Activation section.
- Subagent Escape Hatch.
- Commands table (updated: remove `/harness:steer`, `/harness:assumption-test`).
- Subagent Isolation Protocol (including the `CLAUDE_SUBAGENT=1` + `--append-system-prompt-file` dispatch pattern).
- File Ownership Contract (prose only; drop the "Enforcement (FR-2)" paragraph — no hook).
- Agent Communication Protocol diagram.
- TDD Protocol (pointer to `superpowers:test-driven-development` + BELCORT additions).

**Add**:
- `## Pipeline Timing` — one diagram describing when each phase fires, which triggers are auto vs manual.
- `## Orchestrator Behavior (outside /harness:sprint)` — what to do on technical questions mid-build, scope-change requests, user chatter during phases. Prevents the "orchestrator edits specs because it didn't know better" failure mode.
- `## State Persistence` — what updates manifest.yaml and when; what appends to changelog/decisions/known-issues.
- `## State Awareness` — before every phase transition, orchestrator reads manifest + changelog + `git log --oneline | grep 'harness:'`.
- `## Recovery` — the resume procedure (hoisted from `commands/resume.md`).
- `## Optional Plugins` — AgentLint, Security Guidance, Frontend Design: install commands + how each integrates. Single source of truth referenced by generator.md, evaluator.md.
- `## Template Index` — canonical location of every template + one-line purpose.

### 5.3 `agents/planner.md`

**Delete**:
- Lines 54-69 (Progress Logging heartbeat) — heartbeat removed globally.
- Lines 391-489 (inlined criteria.md template — 98 lines). Replace with: "Read `@templates/evaluator/criteria.md.txt` as your skeleton. The template already encodes the weighting + wording decision points. Below are the principles for customising it." Keep the weighting/wording principle text (that's guidance, not template).

**Keep**:
- MODE routing table.
- RED FLAGS table (adversarial framing is Anthropic-aligned).
- Handling Fetched Content (prompt-injection defense).
- Pass 1 / Pass 2 procedure.
- CLARIFY, AMEND, CONSTITUTION-AMEND mode sections.
- 16-point self-validation checklist (this is the canonical home; validate.md references it).

**Modify**:
- Story-file section (~lines 594-625): condense. Keep the no-paraphrase invariant and the section list; remove the "why per-cycle reading" extended rationale — one line suffices.
- Init.sh / examples.md creation blocks (~lines 630-631): already reference templates correctly; just ensure the reference is the SOLE instruction (no inlined duplicate content nearby).

### 5.4 `agents/generator.md`

**Delete**:
- Lines 89-108 (Progress Logging heartbeat).
- Lines 452-540 (inlined Phase 2 RED/GREEN/REFACTOR/COMMIT procedure — 88 lines). Replace with: "Use `superpowers:test-driven-development` for each cycle. BELCORT-specific additions: (a) atomic commit per FR with message `[harness:build] FR-NNN: <behavior>`; (b) append to `progress/changelog.md` per commit with the template at `@templates/progress/changelog.md`."
- Line 403 and 473 references to `steering.md` — steer command is removed.

**Keep**:
- SUBAGENT-CONTEXT block.
- MODE routing.
- Tool section (Context7, filesystem, Bash, git, skills/plugins — de-dup the plugins section per §5.2's Optional Plugins).
- RED FLAGS table.
- Handling Fetched Content.
- NEGOTIATE mode (full procedure + proposal template reference).
- FINALIZE-CONTRACT mode (with the v1.5.1 fix for not-updating-manifest).
- **Pause Protocol (Phase 1.5)** — **KEEP per Q1 decision**. Calibrated-uncertainty principle. Has built-in anti-procrastination (default-if-unanswered) and 3-pause-then-rewind discipline.
- Phase 1 Orient, Phase 3 Self-Evaluate, Phase 4 Write Report, Phase 5 Update Progress.
- Behavioral Rules + Anti-Patterns + Reward-Hacking Forbidden sections (these are the delta from generic TDD).

### 5.5 `agents/evaluator.md`

**Delete**:
- Lines 316-334 (Progress Logging heartbeat).
- AgentLint/Security Guidance paragraph (lines 305-312) — move to SKILL.md § Optional Plugins, reference from here.

**Keep**:
- SUBAGENT-CONTEXT block.
- MODE routing (REVIEW-PROPOSAL, EVALUATE, REVALIDATE).
- Adversarial-tester framing + anti-leniency protocol.
- Handling Fetched Content (evaluator is most exposed — Playwright renders user content).
- REVIEW-PROPOSAL full procedure + review template.
- EVALUATE procedure: Setup → Functional Testing → Code Quality → Test Suite → Reward-Hacking Scan (Step 4.5) → Spec Validation → **Two-Stage Grading (Part A binary gates Part B numeric)** → Write Report.
- REVALIDATE procedure (for constitution amendments).
- Calibration-mandatory rule (NEVER score without reading examples.md first).

**Modify**:
- Setup block (line 394 onward): convert the inline `bash` heredoc to natural-language "read these files in this order before scoring" list. The bash is fine as a hint but don't ship it as a recipe — orchestrator/subagent decides.

### 5.6 Commands directory

#### 5.6.1 `commands/sprint.md` (584 → ~250 lines)

Major cuts:
- All `source .../progress-poller.sh` + `start_progress_poller` / `stop_progress_poller` / `trap` lifecycle (~60 lines across the file).
- `resolve_model_flag` helper (lines 62-75) and all `${MODEL_FLAG}` references — per-agent model pinning removed.
- `BRAINSTORM_CONTEXT` inline bash block (lines 80-86) — convert to "if `.harness/brainstorm-current.md` exists, orchestrator includes its content in the Planner dispatch."
- Post-dispatch brainstorm/progress file-move block (lines 117-127) — convert to natural-language instruction.
- Manifest sed for phase transition after FINALIZE (lines 271-277) — convert to "orchestrator updates `manifest.yaml → state.phase` to `building` using the Edit tool."
- Pause-loop inline bash (lines 336-413) — condense to ~30 lines of natural-language pause handling: "if `pause-questions.md` exists after Generator exits, surface questions, collect answers, re-dispatch with answers appended to context."
- Manifest increment awk (lines 372-379) — convert to natural-language "orchestrator increments `agent_checkins` in manifest."

Keep:
- Doctor preflight invocation (legit).
- `claude -p ... --append-system-prompt-file ...` dispatches (subagent boundary).
- `git worktree add` (legit).
- Sprint structure with all phases documented as natural-language orchestrator steps.

#### 5.6.2 `commands/quick.md`

Same treatment as sprint.md: remove poller lifecycle, model-pin; keep dispatch blocks.

#### 5.6.3 `commands/resume.md` (108 → ~10 lines)

Reduce to a thin stub: "Run the Recovery procedure documented in SKILL.md § Recovery." The phase-by-phase decision logic moves into SKILL.md.

#### 5.6.4 `commands/setup.md`

New procedure (replaces global-install behavior):
1. Create `.harness/` directory in current project.
2. Copy `@templates/manifest.yaml` → `.harness/manifest.yaml` (blank project fields).
3. Copy `@templates/CLAUDE.md.project.txt` → `./CLAUDE.md` (or append if `CLAUDE.md` already exists, using BELCORT-HARNESS begin/end markers).
4. Run doctor.sh preflight.
5. Report: "Harness ready in this project. Run `/harness:sprint \"<what to build>\"` to start."

Delete the global-install path from `install-rules.sh` (file itself becomes the new `setup.sh` that does project-local setup).

#### 5.6.5 Spec-edit commands (`amend.md`, `clarify.md`, `edit.md`, `tune-evaluator.md`, `retrospective.md`, `constitution-amend.md`)

Each loses:
- `source .../phase-guard.sh` + `phase_set "amending"` / `phase_restore` calls — phase-guard removed globally.

Each keeps:
- Planner/Evaluator subagent dispatch.
- Per-command procedure (precondition check, dispatch, apply patches, post-analyze, ADR logging, changelog append).

Convert: inline bash for manifest reads (`grep ... | awk ... | tr -d '"'`) to natural-language "orchestrator reads the current feature name from manifest.yaml."

#### 5.6.6 `commands/rewind.md` (267 → ~80 lines)

Collapse per-phase granular file-movement rules to:
1. Validate target phase is one of: planning, analyzing, negotiating, building, evaluating.
2. Preview: what will be archived, what manifest changes will happen, whether git branch will be touched.
3. Require explicit typed confirmation (`rewind to <target>`).
4. Archive: move whole feature folder to `.archive/TS/` OR selective move based on target (keep the minimal per-target mapping as a table, not as per-target bash blocks).
5. Reset manifest state.
6. Optional: git branch reset (with separate typed confirmation).
7. Log ADR + changelog.

#### 5.6.7 Removed commands

- `commands/steer.md` — DELETE entirely.
- `commands/assumption-test.md` — DELETE entirely.

### 5.7 Hooks

#### `hooks/session-start.sh` (52 → ~15 lines)

Keep: SUBAGENT GUARD (CLAUDE_SUBAGENT=1 bypass).
Keep: test for `.harness/manifest.yaml` existence.
Shrink injection: one line only — "Harness detected in this project. Invoke the harness skill via the Skill tool before acting." No manifest parsing, no phase extraction, no conditional text. The skill handles state reading.

#### `hooks/pre-tool-use.sh` (179 → ~120 lines)

Delete:
- FR-2 spec-file-edit check (lines 66-118).

Keep:
- JSON parsing infrastructure (jq/python3 fallback).
- Force-push block.
- Sudo block.
- `.harness/` deletion block.
- Test-file-deletion during `building` phase block.

#### `hooks/hooks.json`

Unchanged — same entries (SessionStart, PreToolUse × 3 matchers).

### 5.8 Scripts

#### `scripts/doctor.sh` (367 → ~300 lines)

Delete:
- Lines 139-152 (per-agent model-pin validation).
- Lines 225-263 (CLAUDE.md rules installation + sync check — no longer relevant for project-local CLAUDE.md; replaced with a project-local `.harness/` readiness check).

Keep:
- Claude Code CLI check.
- Git check.
- Node ≥20 check.
- npx check.
- jq/python3 JSON parser check (hook dependency).
- context7 MCP check.
- Playwright MCP check.
- Harness plugin presence.
- Project writable check.
- Git working tree status (RECOMMEND).
- Optional plugin checks (frontend-design, security-guidance, agentlint).

Add (minor):
- Agent file readability check: verify `${CLAUDE_PLUGIN_ROOT}/agents/{planner,generator,evaluator}.md` exist and are readable. If plugin is corrupt, flag before sprint.

#### `scripts/setup.sh` (new; replaces `install-rules.sh`)

Project-local initialization:
1. Create `.harness/` and subdirectories.
2. Copy templates (manifest, ROADMAP, progress/*).
3. Create or patch `./CLAUDE.md` with the ~20-line project snippet.
4. Print next steps.

#### `scripts/uninstall-rules.sh`

Keep as-is — legacy cleanup shim for users who installed globally before v2.

#### Deleted scripts
- `scripts/progress-poller.sh` — DELETE.
- `scripts/phase-guard.sh` — DELETE.
- `scripts/assumption-test.sh` — DELETE.

### 5.9 Templates

#### Consolidation to `plugins/harness/templates/`

Move from root `templates/` to `plugins/harness/templates/`:
- `manifest.yaml`
- `ROADMAP.md`
- `progress/changelog.md`, `progress/decisions.md`, `progress/known-issues.md`
- `spec/evaluator-notes.md.txt`
- `features/contract.md.txt`, `features/proposal.md.txt`, `features/review.md.txt`, `features/eval-report.md.txt`, `features/implementation-report.md.txt`
- `evaluator/examples.md.txt` (de-duplicate — plugin copy becomes canonical)
- `evaluator/tuning-log.md.txt`

Already at `plugins/harness/templates/`:
- `evaluator/criteria.md.txt`
- `features/pause-questions.md.txt`
- `features/story.md.txt`
- `init.sh.txt`

New templates to create:
- `plugins/harness/templates/CLAUDE.md.project.txt` — the ~20-line activation snippet for project-local CLAUDE.md.

Delete the root `templates/` directory once merge is verified.

#### Changes within templates

- `manifest.yaml`: DELETE `harness.last_assumption_test` block, `config.models.*` block, `config.observability.*` block. Keep everything else.
- `evaluator/criteria.md.txt`: unchanged (already the authoritative source).
- `evaluator/examples.md.txt`: unchanged (12 seeded calibration examples).
- Other templates: unchanged unless they contain steer/assumption-test references.

### 5.10 Docs

- `docs/anthropic-alignment.md`: KEEP as-is. Genuinely useful decision map. Update the v1.5 additions section to note what was removed in v2 and why.
- `docs/feature-contracts/`: KEEP historical contracts (v1.4, v1.5) as-is for provenance.
- `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md`: THIS document.
- `CHANGELOG.md`: add v2.0.0 entry listing the specific removals + restructures.

---

## 6. Removed Functionality (explicit list)

| Feature | Reason |
|---|---|
| `/harness:steer` + `steering.md` | Third mid-build interrupt path; retry-loop + amend already cover every real case |
| `/harness:assumption-test` + canary machinery | Never run (manifest field empty); can be done manually in 5min when needed |
| Per-agent model pinning (`config.models.{planner,generator,evaluator}`) | Undocumented, unused, adds conditional branches without payoff |
| Progress-poller + `_progress.jsonl` + heartbeat emission in all 3 agents + `_progress-protocol.md` | `claude -p` already streams stdout; poller solves a non-problem on Opus 4.7 |
| `phase-guard.sh` + FR-2 Edit/Write hook enforcement | Opus 4.7 follows explicit prose constraints; enforcement was defensive for a failure mode that no longer manifests |
| Global install of harness rules to `~/.claude/CLAUDE.md` | Pollutes non-harness sessions; violates simplicity-first at context-injection level |
| Inline evaluator-criteria template in planner.md (98 lines) | Duplicates `templates/evaluator/criteria.md.txt` |
| Inline TDD procedure in generator.md (88 lines) | Duplicates `superpowers:test-driven-development` skill |
| Heartbeat sections in planner/generator/evaluator.md (~60 lines total) | Poller removed — no consumers |
| AgentLint/Security install text in evaluator.md | Duplicated; moved to SKILL.md § Optional Plugins |
| `harness.last_assumption_test` manifest field | Feature removed |
| `config.observability.*` manifest fields | Feature removed |
| Root-directory `templates/` dir | Duplicated plugin templates; merged |

## 7. Preserved Functionality (explicit list)

| Feature | Why it stays |
|---|---|
| Three subagent architecture (Planner, Generator, Evaluator) | Anthropic-canonical GAN isolation |
| `CLAUDE_SUBAGENT=1` env + `--append-system-prompt-file` dispatch pattern | Subagent isolation mechanism; primary gate against self-orchestration loop |
| File-based communication under `.harness/features/NNN/*.md` | Anthropic-canonical |
| Generator↔Evaluator negotiation (proposal → review → finalize) | Anthropic's "sprint contract before code" |
| Part-A-gates-Part-B evaluation | Anthropic-aligned two-stage review |
| `examples.md` few-shot calibration (mandatory read before scoring) | Anthropic-documented calibration mechanism |
| 4-criterion grading with hard thresholds | Anthropic-documented |
| Playwright MCP-driven Evaluator functional testing | Anthropic-canonical |
| Tuning loop (divergence capture → examples.md append → optional prompt edit) | Anthropic-documented |
| Adversarial anti-leniency protocol in Evaluator | Anthropic-documented counter-measure |
| Reward-hacking git-archaeology scan (EVALUATE Step 4.5) | Trustworthy-Agents documented pattern |
| RED FLAGS tables in Planner and Generator | Adversarial prompting against model's known failure modes |
| Pause protocol (Generator mid-build clarification) | Trustworthy-Agents calibrated-uncertainty principle |
| 16-point Planner self-validation | Spec quality gate |
| `/harness:amend`, `/harness:clarify`, `/harness:edit`, `/harness:validate`, `/harness:analyze`, `/harness:negotiate`, `/harness:retrospective`, `/harness:tune-evaluator`, `/harness:audit`, `/harness:rewind`, `/harness:brainstorm`, `/harness:constitution-amend`, `/harness:setup`, `/harness:doctor`, `/harness:resume`, `/harness:sprint`, `/harness:quick` | All retain; some simplified |
| Per-FR story files (BMAD V6 pattern) | Documented benefit for cycle-scoped Generator context |
| Adaptive decomposition for 21+ FRs (per Q3) | Keep — multi-feature planning |
| Force-push / sudo / `.harness/` deletion / test-file-deletion guards | Generic safety rails, still load-bearing |
| Doctor environment preflight | Defensive machinery that pays off (silent MCP failures are real) |
| Constitution-amend high-ceremony governance | SpecKit-inspired; rare but legitimate |

---

## 8. Risks & Mitigations

### Risk 1: Removing FR-2 hook lets the orchestrator edit spec files by mistake
- **Likelihood**: Low on Opus 4.7 (instruction-following is reliable).
- **Impact**: Spec-file pollution with orchestrator chat context.
- **Mitigation**: Keep the prose rule prominent in SKILL.md; Evaluator's retrospective catches drift after the fact; if drift happens in practice, reinstate the hook as a targeted v2.1 fix.

### Risk 2: Heartbeat removal makes long subagent runs feel opaque
- **Likelihood**: Low — `claude -p` streams stdout; Claude Code CLI shows subagent progress.
- **Impact**: User wonders "is it stuck?" during long builds.
- **Mitigation**: Generator already commits per FR with `[harness:build]` tag — user can `git log --oneline` to see progress. Document this in SKILL.md.

### Risk 3: TDD skill dependency
- **Likelihood**: Medium — `superpowers:test-driven-development` is an external skill.
- **Impact**: If Superpowers isn't installed, generator.md has no TDD details.
- **Mitigation**: Doctor check: if Superpowers isn't installed, WARN. Generator's BUILD mode has a fallback one-paragraph summary of RED/GREEN/REFACTOR for the degraded case.

### Risk 4: Assumption-test removal means components aren't periodically re-verified
- **Likelihood**: Certain (feature deleted).
- **Impact**: Over time, another component could go stale the way progress-poller did.
- **Mitigation**: Include a ~1-paragraph section in `docs/anthropic-alignment.md` describing the manual A/B procedure (copy plugin to /tmp, edit it, run canary, compare eval-reports). User can invoke manually.

### Risk 5: Removing steer removes a legitimate nudge channel
- **Likelihood**: Low — the retry loop + amend cover 95% of cases.
- **Impact**: User wants to say "prefer library X" mid-build and now has no channel short of amend.
- **Mitigation**: Document the pattern in SKILL.md: "mid-build preferences should be captured in the constitution or PRD during planning; if they emerge mid-build, that's a signal the plan was incomplete — use /harness:amend or wait for the Evaluator."

### Risk 6: Project-local CLAUDE.md migration breaks existing users
- **Likelihood**: Medium — users who ran `/harness:setup` in v1.x have a global install.
- **Impact**: Confusion on upgrade.
- **Mitigation**: `scripts/setup.sh` detects the old global block, prints a note: "A legacy global install was detected at `~/.claude/CLAUDE.md`. Run `scripts/uninstall-rules.sh` to remove it if you no longer want the global activation." `uninstall-rules.sh` is kept specifically for this.

---

## 9. Success Criteria

After implementation, the refactor succeeds if ALL of these hold:

1. **LoC reduction ≥40%** across `plugins/harness/**` (excluding templates). Target: current ~6000 lines → ~3400.
2. **No duplicate content**: no fact or procedure is stated in more than one file. Verification: grep-based (e.g., "grep for the phrase 'fresh subagent' across all md files — appears only in SKILL.md and subagent-context blocks in agent files").
3. **Pipeline works end-to-end on a canary**: run `/harness:sprint "build a 2-FR todo app"` in a clean project, complete plan → negotiate → build → evaluate with the new structure, obtain PASS verdict.
4. **All `/harness:*` commands still functional** except the two explicitly removed (steer, assumption-test).
5. **Doctor passes on a fresh machine with Claude Code + context7 + playwright installed.**
6. **SessionStart hook injects ≤1 line.** Verified by dumping the hook output in a fresh shell.
7. **CLAUDE.md installation is project-local**, not `~/.claude/CLAUDE.md`.
8. **All template content is in `plugins/harness/templates/` only**; root `templates/` is deleted.
9. **No `source .../phase-guard.sh` or `source .../progress-poller.sh` lines remain** anywhere in `commands/**` or `scripts/**`.
10. **Generator's BUILD mode references `superpowers:test-driven-development`** instead of inlining the TDD procedure.
11. **SKILL.md has all seven added sections** (Pipeline Timing, Orchestrator Behavior, State Persistence, State Awareness, Recovery, Optional Plugins, Template Index).
12. **Every agent file references templates via `@`** and contains no duplicated template content.
13. **All orchestrator file-manipulation recipes in command md files are natural-language instructions**, not literal bash scripts — except `claude -p` dispatch, `git worktree` calls, and hook contents.
14. **Version bump to 2.0.0** in `plugin.json`, with a CHANGELOG entry.

---

## 10. Implementation Ordering (preview — full plan comes from writing-plans skill)

Rough sequencing for the implementation plan:

1. Update `plugin.json` version + add `CHANGELOG.md` v2.0.0 entry (non-destructive, sets expectations).
2. Consolidate `templates/` → `plugins/harness/templates/` (verify nothing breaks; delete root).
3. Shrink `hooks/session-start.sh`.
4. Strip FR-2 check from `hooks/pre-tool-use.sh`; delete `scripts/phase-guard.sh`.
5. Remove all `phase_set`/`phase_restore` calls across commands.
6. Remove heartbeat code: delete `scripts/progress-poller.sh`, delete `agents/_progress-protocol.md`, strip heartbeat sections from all three agents, strip poller lifecycle from all commands.
7. Delete `commands/steer.md`, `commands/assumption-test.md`, `scripts/assumption-test.sh`.
8. Remove per-agent model pinning: `resolve_model_flag` helper, `config.models.*` fields.
9. Restructure `CLAUDE.md.snippet.txt` (72 → 20 lines).
10. Create `scripts/setup.sh` (project-local install); update `commands/setup.md`.
11. Shrink `agents/planner.md` (remove inline criteria template, heartbeat).
12. Shrink `agents/generator.md` (remove heartbeat, inline TDD, steer refs).
13. Shrink `agents/evaluator.md` (remove heartbeat, duplicated plugin text).
14. Restructure `SKILL.md` (delete dup sections, add 7 new sections).
15. Shrink command md files (sprint, quick, resume, amend, clarify, edit, tune-evaluator, retrospective, constitution-amend, rewind) per natural-language rewrite.
16. Simplify `rewind.md` (267 → 80 lines).
17. Minor doctor.sh updates.
18. End-to-end canary sprint verification.
19. Update `docs/anthropic-alignment.md` with v2 delta.

---

## 11. Answered Open Questions (from Socratic round)

- **Q1 (pause protocol)**: KEEP. Best-practice recommendation grounded in Trustworthy-Agents calibrated-uncertainty principle; existing implementation has anti-procrastination guards (default-if-unanswered, 3-pause-then-rewind) that prevent misuse.
- **Q2 (templates directory)**: Consolidate to `plugins/harness/templates/`. Rationale: `${CLAUDE_PLUGIN_ROOT}` is the only path Claude Code resolves when plugin is installed; root `templates/` is only reachable in dev checkout.
- **Q3 (adaptive multi-feature decomposition for 21+ FRs)**: KEEP. Low-cost feature; just more folders and same contract-per-folder mechanics.

---

## 12. References

- Anthropic: *Harness design for long-running application development* (Rajasekaran 2026). https://www.anthropic.com/engineering/harness-design-long-running-apps
- Anthropic: *Trustworthy agents in practice*. https://www.anthropic.com/research/trustworthy-agents
- BELCORT v1.5 decision map: `docs/anthropic-alignment.md`
- Superpowers TDD skill (external, referenced): `superpowers:test-driven-development`

---

*End of design spec. Next step: user reviews this document, then we move to the writing-plans skill to produce the step-by-step implementation plan.*
