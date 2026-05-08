# BELCORT v2 Minimalist Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the v2 minimalist refactor specified at `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md` — remove v1.3/1.4/1.5 accretion, consolidate duplication, demote hardcoded bash to natural-language instructions where the orchestrator can judge-and-execute via tool calls.

**Architecture:** Five phases, 30 tasks. Phase ordering matters: deletions first (no dependencies), then restructures (depend on cleanup), then SKILL.md overhaul (depends on referenced content existing), then command rewrites (depend on SKILL.md `@` targets), then validation. Each task has exact paths, exact edit content, and a verification step.

**Tech Stack:** Bash (hooks + doctor + dispatch), Markdown (prompts + commands + skill + templates), YAML (manifest), Claude Code plugin API, Anthropic SDK subagent dispatch.

**Pre-work (DO BEFORE TASK 1):**

- The working directory `C:\Users\zhant\Desktop\belcort-harness-harness-v1.5-trustworthy-agents-deep-alignment` is NOT a git repo (per environment inspection). **No `git commit` steps included.** Instead: snapshot before starting.
- Run once, before Task 1:
  ```bash
  cp -r "C:/Users/zhant/Desktop/belcort-harness-harness-v1.5-trustworthy-agents-deep-alignment" \
        "C:/Users/zhant/Desktop/belcort-harness-v1.5.bak-$(date +%Y%m%d-%H%M%S)"
  ```
- All file paths in this plan are relative to the project root (the directory named `belcort-harness-harness-v1.5-trustworthy-agents-deep-alignment`). Use absolute paths when invoking tools.

**Out-of-scope (do not touch during this refactor):**
- Agent prompts' core decision logic (RED FLAGS tables, MODE routing, anti-leniency, reward-hacking scan).
- Pipeline phases themselves.
- New feature work.

---

# PHASE 1 — Safe Deletions & Mechanical Cleanup

These tasks have no inter-dependencies and can be done in any order. They only delete or strip content; nothing new is authored yet.

---

## Task 1: Version bump + CHANGELOG v2.0.0 entry

**Files:**
- Modify: `plugins/harness/.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`

Prerequisites: none.

- [ ] **Step 1: Read plugin.json to confirm current version**

Read `plugins/harness/.claude-plugin/plugin.json`. Confirm current version line reads `"version": "1.5.2",`.

- [ ] **Step 2: Bump version**

Edit `plugins/harness/.claude-plugin/plugin.json`:
- old_string: `"version": "1.5.2",`
- new_string: `"version": "2.0.0",`

- [ ] **Step 3: Read CHANGELOG.md to see current top entry**

Read the first 30 lines of `CHANGELOG.md` to identify the first existing `## [X.Y.Z]` heading.

- [ ] **Step 4: Prepend the v2.0.0 entry**

Edit `CHANGELOG.md`. Use the first existing `## [` heading as `old_string` anchor; prepend the block below before it.

- old_string (example — substitute actual first heading you found): `## [1.5.2]`
- new_string:
  ```markdown
  ## [2.0.0] — 2026-04-21

  ### Removed
  - `/harness:steer` command + `features/NNN/steering.md`. Mid-build steering collapses into `/harness:amend` (spec change) or the evaluator retry loop (quality).
  - `/harness:assumption-test` + `scripts/assumption-test.sh` (287 lines). Never run in practice; manual A/B is a 5-minute task when needed.
  - `scripts/progress-poller.sh` + `agents/_progress-protocol.md` + heartbeat sections in all three agents. `claude -p` streams stdout natively; the poller solved a non-problem on Opus 4.7.
  - `scripts/phase-guard.sh` + FR-2 spec-file-edit enforcement in `hooks/pre-tool-use.sh`. Prose rule in SKILL.md suffices on Opus 4.7.
  - Per-agent model pinning (`config.models.{planner,generator,evaluator}`). Unused, undocumented.
  - Global CLAUDE.md installation. Rules now install project-local via `/harness:setup`.

  ### Changed
  - `skills/harness/SKILL.md` promoted to auto-invoked skill (trigger-phrase matching). `/harness:*` slash commands remain as explicit entry points.
  - `SessionStart` hook reduced from ~50 lines of state injection to ~15 lines — one-line "harness detected, invoke skill" nudge. State reading moves into the skill.
  - Generator BUILD mode references `superpowers:test-driven-development` for RED/GREEN/REFACTOR; BELCORT-specific rules (atomic per-FR commits, reward-hacking prohibition) retained inline.
  - `/harness:rewind` simplified from 267 to ~80 lines.
  - All template content consolidated to `plugins/harness/templates/`. Root `templates/` deleted.
  - Command files rewritten as natural-language procedures. Bash retained only for `claude -p` dispatch, `git worktree`, and hook contents.

  ### Migration
  - Users who installed v1.x rules globally: run `scripts/uninstall-rules.sh` once to remove the legacy `~/.claude/CLAUDE.md` block, then `/harness:setup` in each project to install the new project-local rules.

  ### Architecture
  - ~45% LoC reduction. Pipeline and Anthropic-aligned core unchanged.
  - Full rationale: `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md`.

  ```

- [ ] **Step 5: Verify changes**

Grep: `grep '"version"' plugins/harness/.claude-plugin/plugin.json` → expect `"version": "2.0.0",`
Grep: `grep '## \[2.0.0\]' CHANGELOG.md` → expect one hit.

---

## Task 2: Consolidate templates directory

Goal: make `plugins/harness/templates/` the single source of truth; delete root `templates/`.

**Files:**
- Create/move: files from `templates/` → `plugins/harness/templates/`
- Delete: `templates/` (root directory, after move)
- Delete: duplicate `plugins/harness/templates/evaluator/examples.md.txt` (root copy becomes canonical after move)

Prerequisites: none (the plan creates a backup in pre-work).

- [ ] **Step 1: Inventory both template directories**

Bash: `ls -la templates/ plugins/harness/templates/ 2>&1`

Expected: root `templates/` has subdirs `evaluator/`, `features/`, `progress/`, `spec/`, plus `manifest.yaml` and `ROADMAP.md`. Plugin `templates/` has `evaluator/criteria.md.txt`, `evaluator/examples.md.txt`, `features/pause-questions.md.txt`, `features/story.md.txt`, `init.sh.txt`.

- [ ] **Step 2: Move root templates into plugin templates**

Bash (merges contents, keeps plugin's `criteria.md.txt` and `examples.md.txt` since those are the canonical plugin copies for evaluator, but brings in all root-only files like `tuning-log.md.txt`, `contract.md.txt`, etc.):

```bash
# Move all files that don't exist in plugin templates
cd "C:/Users/zhant/Desktop/belcort-harness-harness-v1.5-trustworthy-agents-deep-alignment"
mkdir -p plugins/harness/templates/progress plugins/harness/templates/spec

# Root-only files to move (verified from spec §5.9):
mv -n templates/manifest.yaml                                   plugins/harness/templates/manifest.yaml
mv -n templates/ROADMAP.md                                      plugins/harness/templates/ROADMAP.md
mv -n templates/progress/changelog.md                           plugins/harness/templates/progress/changelog.md
mv -n templates/progress/decisions.md                           plugins/harness/templates/progress/decisions.md
mv -n templates/progress/known-issues.md                        plugins/harness/templates/progress/known-issues.md
mv -n templates/spec/evaluator-notes.md.txt                     plugins/harness/templates/spec/evaluator-notes.md.txt
mv -n templates/features/contract.md.txt                        plugins/harness/templates/features/contract.md.txt
mv -n templates/features/proposal.md.txt                        plugins/harness/templates/features/proposal.md.txt
mv -n templates/features/review.md.txt                          plugins/harness/templates/features/review.md.txt
mv -n templates/features/eval-report.md.txt                     plugins/harness/templates/features/eval-report.md.txt
mv -n templates/features/implementation-report.md.txt           plugins/harness/templates/features/implementation-report.md.txt
mv -n templates/evaluator/tuning-log.md.txt                     plugins/harness/templates/evaluator/tuning-log.md.txt

# Root examples.md.txt is kept only if plugin version doesn't exist — but plugin version DOES exist,
# so we discard the root duplicate:
rm -f templates/evaluator/examples.md.txt
```

- [ ] **Step 3: Verify all expected files exist in plugin templates**

Bash:
```bash
ls plugins/harness/templates/manifest.yaml \
   plugins/harness/templates/ROADMAP.md \
   plugins/harness/templates/progress/changelog.md \
   plugins/harness/templates/progress/decisions.md \
   plugins/harness/templates/progress/known-issues.md \
   plugins/harness/templates/spec/evaluator-notes.md.txt \
   plugins/harness/templates/features/contract.md.txt \
   plugins/harness/templates/features/proposal.md.txt \
   plugins/harness/templates/features/review.md.txt \
   plugins/harness/templates/features/eval-report.md.txt \
   plugins/harness/templates/features/implementation-report.md.txt \
   plugins/harness/templates/features/pause-questions.md.txt \
   plugins/harness/templates/features/story.md.txt \
   plugins/harness/templates/evaluator/criteria.md.txt \
   plugins/harness/templates/evaluator/examples.md.txt \
   plugins/harness/templates/evaluator/tuning-log.md.txt \
   plugins/harness/templates/init.sh.txt
```

Expected: every path listed, no "No such file" errors.

- [ ] **Step 4: Delete root templates directory**

Bash: `rm -rf templates/`

- [ ] **Step 5: Verify root templates gone**

Bash: `[ ! -d templates ] && echo "OK — root templates/ deleted" || echo "FAIL — root templates/ still exists"`

Expected: `OK — root templates/ deleted`

---

## Task 3: Delete steer command + steering references

**Files:**
- Delete: `plugins/harness/commands/steer.md`
- Modify: `plugins/harness/agents/generator.md` (remove steering.md references)
- Modify: `plugins/harness/skills/harness/SKILL.md` (remove /harness:steer row from commands table)
- Modify: `plugins/harness/CLAUDE.md.snippet.txt` (no steer mention currently — verify)

Prerequisites: Task 1 complete (version bumped, so users know this is the breaking change).

- [ ] **Step 1: Delete steer.md**

Bash: `rm plugins/harness/commands/steer.md`

- [ ] **Step 2: Remove steering references from generator.md (Phase 1 Orient)**

Read `plugins/harness/agents/generator.md`. Find the block around line 403 that reads:

- old_string (exact — verify by reading first):
  ```
  2. **Read `.harness/features/{current-feature}/steering.md` if it exists.** This file carries mid-build nudges from the orchestrator (via `/harness:steer`). Treat each note as implementation guidance — not a contract change. If a note contradicts the contract, flag it in `implementation-report.md` under "Known Rough Edges" rather than silently obeying either. The contract wins unless an `/harness:amend` has rewritten it.
  3. **Run `bash .harness/init.sh`** to verify project health. If it fails, fix before proceeding.
  ```
- new_string:
  ```
  2. **Run `bash .harness/init.sh`** to verify project health. If it fails, fix before proceeding.
  ```
- Renumber subsequent steps in the same block: the existing "3." becomes "2.", "4." becomes "3." etc. Apply the renumber as a separate Edit if needed (read the block first to see the current numbering).

- [ ] **Step 3: Remove steering reference from generator.md (Phase 2 Build with TDD intro)**

Read `plugins/harness/agents/generator.md` around line 473 to locate:

- old_string (exact — verify):
  ```
  **Before each deliverable, re-read `.harness/features/{current-feature}/steering.md`.** The orchestrator may have appended new notes during the previous TDD cycle. Steering notes take effect at the NEXT cycle boundary — reading them here is how that promise is kept.

  ```
- new_string: (empty — delete the paragraph and its trailing blank line)

- [ ] **Step 4: Remove /harness:steer row from SKILL.md commands table**

Read `plugins/harness/skills/harness/SKILL.md`. Find line ~40:

- old_string:
  ```
  | `/harness:steer "<nudge>"` | [commands/steer.md](../../commands/steer.md) | Mid-build steering — append a guidance note the Generator picks up at the next TDD cycle boundary. Lightweight alternative to amend/rewind for implementation nudges. |
  ```
- new_string: (empty line removal — use `replace_all: false`)

- [ ] **Step 5: Verify no steer references remain**

Grep: `grep -rn "steer\|steering" plugins/harness/`
Expected: only results in `CHANGELOG.md` (intentional — documents the removal). Any hits under `plugins/harness/agents/`, `plugins/harness/commands/`, `plugins/harness/skills/` are stale and must be cleaned.

---

## Task 4: Delete assumption-test command + script + manifest field

**Files:**
- Delete: `plugins/harness/commands/assumption-test.md`
- Delete: `plugins/harness/scripts/assumption-test.sh`
- Modify: `plugins/harness/templates/manifest.yaml` (remove `harness.last_assumption_test` block)
- Modify: `plugins/harness/skills/harness/SKILL.md` (remove /harness:assumption-test row from commands table)

Prerequisites: Task 2 complete (templates consolidated, so we know which manifest.yaml to edit).

- [ ] **Step 1: Delete both files**

Bash:
```bash
rm plugins/harness/commands/assumption-test.md
rm plugins/harness/scripts/assumption-test.sh
```

- [ ] **Step 2: Remove last_assumption_test block from manifest.yaml template**

Read `plugins/harness/templates/manifest.yaml`. Find the block (spec §5.9, templates/manifest.yaml lines ~10-17):

- old_string:
  ```
    # FR-5 Component-as-Assumption stress test (Rajasekaran 2026). /harness:assumption-test
    # writes here. /harness:audit reads it to remind the user which components are due for
    # quarterly retesting. Empty values = no test ever run.
    last_assumption_test:
      date: ""               # ISO date of last test
      component: ""          # component tested (brainstorm|negotiation|two-stage-eval|red-flags|calibration-examples|reward-hacking-scan|analyze)
      canary: ""             # path to the canary spec used
      verdict: ""            # LOAD-BEARING | MARGINAL | OBSOLETE
  ```
- new_string: (empty — delete the whole block)

- [ ] **Step 3: Remove /harness:assumption-test row from SKILL.md**

Read `plugins/harness/skills/harness/SKILL.md`. Find line ~45:

- old_string:
  ```
  | `/harness:assumption-test "<component>"` (v1.5) | [commands/assumption-test.md](../../commands/assumption-test.md) | Stress-test a harness component on a canary spec — A/B with vs without, LOAD-BEARING/MARGINAL/OBSOLETE verdict. Operationalises Rajasekaran 2026's "removing one component at a time and reviewing what impact it had." Quarterly cadence. |
  ```
- new_string: (empty)

- [ ] **Step 4: Verify**

Grep: `grep -rn "assumption-test\|last_assumption_test" plugins/harness/`
Expected: only `CHANGELOG.md` hits. No hits under `agents/`, `commands/`, `scripts/`, `templates/`, `skills/`.

---

## Task 5: Delete progress-poller + heartbeat protocol doc

**Files:**
- Delete: `plugins/harness/scripts/progress-poller.sh`
- Delete: `plugins/harness/agents/_progress-protocol.md`

Prerequisites: Tasks 3, 4 done (reduces conflicting edits).

- [ ] **Step 1: Delete both files**

Bash:
```bash
rm plugins/harness/scripts/progress-poller.sh
rm plugins/harness/agents/_progress-protocol.md
```

- [ ] **Step 2: Verify**

Bash:
```bash
[ ! -f plugins/harness/scripts/progress-poller.sh ] && \
[ ! -f plugins/harness/agents/_progress-protocol.md ] && \
  echo "OK — both deleted" || echo "FAIL"
```

Expected: `OK — both deleted`

---

## Task 6: Strip heartbeat sections from all three agent files

**Files:**
- Modify: `plugins/harness/agents/planner.md` (lines ~54-69)
- Modify: `plugins/harness/agents/generator.md` (lines ~89-108)
- Modify: `plugins/harness/agents/evaluator.md` (lines ~316-334)

Prerequisites: Task 5 done (the referenced `_progress-protocol.md` is now gone).

- [ ] **Step 1: Strip from planner.md**

Read `plugins/harness/agents/planner.md` lines 54-70 to confirm. Apply edit:

- old_string:
  ```
  ## PROGRESS LOGGING — Heartbeat to orchestrator

  Read the shared protocol: [`_progress-protocol.md`](_progress-protocol.md). It exists so the human watching `/harness:sprint` can see what you're doing in real time without breaking subagent isolation. Closes the Trustworthy Agents §opacity-at-scale anti-pattern.

  **Emit heartbeat lines at:**
  - `{"phase":"start","msg":"PLAN mode (Pass 1) beginning"}` at mode start
  - `{"phase":"pass-2-start","msg":"architecture + criteria + contract"}` at the Pass 1 → Pass 2 boundary
  - `{"phase":"fr-drafted","fr":"FR-NNN","msg":"<one-line summary>"}` per FR captured
  - `{"phase":"self-validate","msg":"running 16-point checklist"}` at self-validation start
  - `{"phase":"complete","msg":"<N>/16 passed, all artifacts written"}` at mode end

  CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND modes are short — emit only `start` and `complete`.

  Rate limit: max 1 line per 30s except boundary events. **Do NOT emit:** decisions/rationale (→ spec files), errors (→ stdout), questions to user (→ AskUserQuestions). Skip silently if `config.observability.heartbeat: false` in `manifest.yaml`.

  The emission is one shell line — see the protocol doc for the exact `printf` pattern.

  ---

  ```
- new_string: (empty — delete the section; the following `## HANDLING FETCHED CONTENT` section immediately follows)

- [ ] **Step 2: Strip from generator.md**

Read `plugins/harness/agents/generator.md` lines 89-109 to confirm, then apply:

- old_string:
  ```
  ## PROGRESS LOGGING — Heartbeat to orchestrator

  Read the shared protocol: [`_progress-protocol.md`](_progress-protocol.md). BUILD mode often runs for 20+ minutes — without heartbeat the human has no window into what you're doing. This closes the Trustworthy Agents §opacity-at-scale gap.

  **Emit heartbeat lines at TDD phase boundaries (BUILD mode):**
  - `{"phase":"start","msg":"BUILD mode beginning, current_task=FR-NNN"}` at mode start
  - `{"phase":"RED","fr":"FR-NNN","msg":"writing failing test"}` before each red phase
  - `{"phase":"GREEN","fr":"FR-NNN","msg":"minimum impl to pass"}` after green
  - `{"phase":"REFACTOR","fr":"FR-NNN","msg":"<what you cleaned>"}` after refactor
  - `{"phase":"COMMIT","fr":"FR-NNN","msg":"<commit summary>"}` after commit
  - `{"phase":"PAUSE","fr":"FR-NNN","msg":"writing pause-questions.md"}` if you invoke pause
  - `{"phase":"BLOCKED","msg":"<one-line blocker>"}` for unexpected errors needing >1min recovery
  - `{"phase":"complete","msg":"all FRs done, implementation-report written"}` at mode end

  NEGOTIATE and FINALIZE-CONTRACT modes are short — emit only `start`, `complete`.

  Rate limit: max 1 line per 30s EXCEPT boundary events (RED/GREEN/REFACTOR/COMMIT) — boundaries always emit. **Do NOT emit:** decisions/rationale (→ implementation-report.md), test output (→ stdout), questions (→ pause-questions.md), multi-line content, secrets.

  Skip silently if `config.observability.heartbeat: false` in `manifest.yaml`. The emission is one shell line — see the protocol doc for the exact `printf` pattern.

  ---

  ```
- new_string: (empty)

- [ ] **Step 3: Strip from evaluator.md**

Read `plugins/harness/agents/evaluator.md` lines 316-335 to confirm, then apply:

- old_string:
  ```
  ## PROGRESS LOGGING — Heartbeat to orchestrator

  Read the shared protocol: [`_progress-protocol.md`](_progress-protocol.md). EVALUATE mode often runs for many minutes (Playwright + edge cases + reward-hacking scan); without heartbeat the human can't tell if you're testing edge cases or stuck. Closes the Trustworthy Agents §opacity-at-scale gap.

  **Emit heartbeat lines at (EVALUATE mode):**
  - `{"phase":"start","msg":"EVALUATE mode, app at <url>"}` at mode start
  - `{"phase":"testing-fr","fr":"FR-NNN","msg":"happy + N edge cases"}` per FR you start testing
  - `{"phase":"testing-ac","ac":"AC-NNN-N","msg":"<what you're checking>"}` per AC
  - `{"phase":"reward-hacking-scan","msg":"git archaeology, 6 checks"}` when Step 4.5 begins
  - `{"phase":"finding","msg":"<severity> — <one-line title>"}` when you log a finding
  - `{"phase":"scoring","msg":"Part A binary then Part B numeric"}` at scoring start
  - `{"phase":"complete","msg":"verdict: PASS|FAIL"}` at mode end

  REVIEW-PROPOSAL mode is shorter — emit only `start`, `{"phase":"verdict","msg":"agreed|needs-revision"}`, `complete`.

  Rate limit: max 1 line per 30s except boundary events (per-FR start, per-AC start, finding logged, mode transitions). **Do NOT emit:** Playwright DOM dumps, score rationale (→ eval-report.md), screenshots, raw test output, secrets.

  Skip silently if `config.observability.heartbeat: false` in `manifest.yaml`. The emission is one shell line — see the protocol doc for the exact `printf` pattern.

  ---

  ```
- new_string: (empty)

- [ ] **Step 4: Verify**

Grep: `grep -rn "heartbeat\|_progress-protocol\|_progress\.jsonl\|_progress-planner" plugins/harness/agents/`

Expected: zero hits.

- [ ] **Step 5: Verify no stale references in manifest template**

Grep: `grep -n "observability\|heartbeat\|poll_interval" plugins/harness/templates/manifest.yaml`

Expected: still has the `observability` block — that's removed in Task 13.

---

## Task 7: Remove observability.* block from manifest.yaml template

**Files:**
- Modify: `plugins/harness/templates/manifest.yaml`

Prerequisites: Task 6 done (agents no longer emit).

- [ ] **Step 1: Read current manifest template to locate block**

Read `plugins/harness/templates/manifest.yaml`. Confirm the `observability:` block (currently around lines 73-82).

- [ ] **Step 2: Apply edit**

- old_string:
  ```
    # Subagent observability — closes Trustworthy Agents §opacity-at-scale.
    # When true, each subagent appends one JSONL milestone per boundary event to
    # .harness/features/${FEATURE}/_progress.jsonl, and the orchestrator polls and
    # surfaces them as `[HH:MM AGENT] phase: msg` lines while the dispatch runs.
    # Set to false for fully silent runs (e.g., CI batch jobs where no human is watching).
    # Protocol details: plugins/harness/agents/_progress-protocol.md
    observability:
      heartbeat: true             # subagents emit milestones, orchestrator polls every 10s
      poll_interval_seconds: 10   # orchestrator's reader cadence
      rate_limit_seconds: 30      # max 1 non-boundary emission per agent per N seconds

  ```
- new_string: (empty)

- [ ] **Step 3: Verify**

Grep: `grep -n "observability\|heartbeat\|poll_interval" plugins/harness/templates/manifest.yaml`

Expected: zero hits.

---

## Task 8: Remove per-agent model pinning (manifest field + doctor check)

**Files:**
- Modify: `plugins/harness/templates/manifest.yaml` (remove `config.models.*` block)
- Modify: `plugins/harness/scripts/doctor.sh` (remove agent-model pin validation loop)

Prerequisites: none.

- [ ] **Step 1: Remove config.models.* block from manifest template**

Read `plugins/harness/templates/manifest.yaml`. Locate lines ~52-62 (config.models block + its comment header):

- old_string:
  ```
    # Per-agent model pinning (BMAD-inspired: planning and implementation don't need the same model).
    # Each agent can override harness.model above. Leave as "" to use the default.
    # Recommended splits:
    #   - planner: claude-sonnet-4-6   (large context, cheaper, planning is mostly reading+writing docs)
    #   - generator: claude-opus-4-7   (strongest coding model — default)
    #   - evaluator: claude-opus-4-7   (adversarial reasoning benefits from strongest model — default)
    # If you change any of these, /harness:doctor will verify the model IDs are valid.
    models:
      planner: ""     # e.g., "claude-sonnet-4-6" to run planning on a cheaper model
      generator: ""   # typically left empty (uses harness.model)
      evaluator: ""   # typically left empty (uses harness.model)

  ```
- new_string: (empty)

- [ ] **Step 2: Remove model-pin validation loop from doctor.sh**

Read `plugins/harness/scripts/doctor.sh` lines 136-152. Apply:

- old_string:
  ```
  # Per-agent model overrides — if manifest pins a model, verify it looks like a
  # valid Claude model ID (not a typo). Does not check availability — that happens
  # at dispatch time. This is a sanity check against 'claude-ops-4.7' (typo) etc.
  if [ -f ".harness/manifest.yaml" ]; then
    for agent in planner generator evaluator; do
      model=$(awk -v key="$agent" '/^[[:space:]]*models:/{in_m=1;next} in_m && $1==key":"{gsub(/"/,"",$2); print $2; exit}' .harness/manifest.yaml 2>/dev/null || true)
      # Skip if empty (default) or doesn't look set
      [ -z "$model" ] && continue
      if printf '%s' "$model" | grep -qE '^claude-(opus|sonnet|haiku)-[0-9]+(-[0-9]+)?(-[a-z0-9]+)?$'; then
        add_result "RECOMMEND" "PASS" "Agent model pin: ${agent}" "pinned to ${model}"
      else
        add_result "RECOMMEND" "WARN" "Agent model pin: ${agent}" \
          "pinned to '${model}' — does not match claude-<opus|sonnet|haiku>-N-M pattern (typo?)" \
          "Edit .harness/manifest.yaml → config.models.${agent} or clear it to use the default"
      fi
    done
  fi

  ```
- new_string: (empty)

- [ ] **Step 3: Verify**

Grep: `grep -rn "config\.models\|resolve_model_flag\|model_flag" plugins/harness/`

Expected: hits only in `plugins/harness/commands/sprint.md` and possibly `quick.md` (those are cleaned in Task 17/18). Zero hits in `templates/`, `scripts/doctor.sh`, agents.

---

# PHASE 2 — Restructures & Hook/Script Rewrites

Phase 1 cleaned. Phase 2 rewrites the remaining scaffolding.

---

## Task 9: Shrink SessionStart hook to minimal nudge

**Files:**
- Rewrite: `plugins/harness/hooks/session-start.sh`

Prerequisites: Phase 1 complete.

- [ ] **Step 1: Read current hook to see structure**

Read `plugins/harness/hooks/session-start.sh`.

- [ ] **Step 2: Overwrite file with new content**

Write `plugins/harness/hooks/session-start.sh` (overwriting) with:

```bash
#!/bin/bash
# BELCORT Harness — SessionStart Hook (v2)
# Minimal: detect harness, nudge the skill. State reading is done by the skill
# itself — this hook is only a 1-line trigger.

set -u

# SUBAGENT GUARD — must come BEFORE any injection so CLAUDE_SUBAGENT=1 dispatched
# subagents don't inherit harness-state context.
if [ "${CLAUDE_SUBAGENT:-0}" = "1" ]; then
  exit 0
fi

# Only act if there's an active harness in this directory.
[ -f ".harness/manifest.yaml" ] || exit 0

cat <<'EOF'
<harness-state>
BELCORT Harness detected in this project (.harness/manifest.yaml present).

Invoke the harness skill via the Skill tool before acting. The skill reads
manifest.yaml, progress/changelog.md, and git log to figure out the current
phase and recommend next steps. Do not answer technical questions or start
coding about this project until the skill has run.
</harness-state>
EOF

exit 0
```

- [ ] **Step 3: Verify line count and content**

Bash: `wc -l plugins/harness/hooks/session-start.sh`
Expected: ≤20 lines.

Grep: `grep -c "grep.*manifest" plugins/harness/hooks/session-start.sh`
Expected: `0` (no more manifest field extraction in the hook).

---

## Task 10: Strip FR-2 spec-file-edit check from pre-tool-use.sh

**Files:**
- Modify: `plugins/harness/hooks/pre-tool-use.sh`

Prerequisites: none.

- [ ] **Step 1: Read current hook to locate FR-2 block**

Read `plugins/harness/hooks/pre-tool-use.sh` lines 65-120.

- [ ] **Step 2: Apply edit — delete FR-2 block**

- old_string (starts from the comment header, ends before "Only Bash invocations" comment):
  ```
  # ─────────────────────────────────────────────────────────────
  # FR-2: Spec-file ownership guard (Edit / Write)
  # ─────────────────────────────────────────────────────────────
  # Enforces the SKILL.md File Ownership Contract: the orchestrator does NOT
  # edit spec files — only fresh subagents (with clean context) or one of the
  # dedicated spec-edit commands (which set state.phase first).
  #
  # Without this guard, the rule was prose-only and a future Claude could
  # violate it by Edit-ing .harness/spec/* directly from the orchestrator's
  # fat-context session, leaking conversational noise into spec files.
  #
  # Bypass conditions (any one allows):
  #   1. CLAUDE_SUBAGENT=1     — subagents are the canonical writers
  #   2. state.phase ∈ {amending, clarifying, editing, tuning, retrospective,
  #      constitution-amending} — the active command set the phase via
  #      phase_set in scripts/phase-guard.sh
  #   3. file is NOT under guarded paths
  if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    TARGET=$(parse_json_field '.tool_input.file_path')
    case "$TARGET" in
      */.harness/spec/*|*/.harness/features/*/contract.md|*/.harness/evaluator/criteria.md)
        # Subagents bypass — they are the authorized writers per File Ownership
        if [ "${CLAUDE_SUBAGENT:-0}" != "1" ]; then
          # Orchestrator path: must be in an authorized spec-edit phase
          ALLOWED_PHASES="amending clarifying editing tuning retrospective constitution-amending"
          CURRENT_PHASE=""
          if [ -f ".harness/manifest.yaml" ]; then
            CURRENT_PHASE=$(grep '^[[:space:]]*phase:' .harness/manifest.yaml 2>/dev/null \
                              | head -1 | awk -F: '{print $2}' | tr -d '" ' | head -c 30)
          fi
          AUTHORIZED=0
          for p in $ALLOWED_PHASES; do
            [ "$CURRENT_PHASE" = "$p" ] && { AUTHORIZED=1; break; }
          done
          if [ "$AUTHORIZED" = "0" ]; then
            # Pretty-print the target path relative to PWD if possible
            REL_TARGET="${TARGET#$PWD/}"
            echo "BLOCKED: orchestrator may not edit ${REL_TARGET} during phase=${CURRENT_PHASE:-<unset>}." >&2
            echo "Spec files have designated writers (see SKILL.md File Ownership Contract)." >&2
            echo "To make a spec change, use one of:" >&2
            echo "  /harness:amend \"<change>\"        — targeted spec amendment" >&2
            echo "  /harness:clarify                   — surface ambiguities, batch-answer" >&2
            echo "  /harness:edit \"<change>\"         — multi-file coordinated edit" >&2
            echo "  /harness:tune-evaluator           — calibrate criteria/examples" >&2
            echo "  /harness:retrospective            — sync spec with what was built" >&2
            echo "  /harness:constitution-amend \"<reason>\" — high-ceremony constitution change" >&2
            exit 1
          fi
        fi
        ;;
    esac
  fi

  ```
- new_string: (empty)

- [ ] **Step 3: Verify**

Grep: `grep -n "FR-2\|phase-guard\|ALLOWED_PHASES\|orchestrator may not edit" plugins/harness/hooks/pre-tool-use.sh`
Expected: zero hits.

Grep: `grep -n "force push\|sudo\|cannot delete .harness\|deleting test files" plugins/harness/hooks/pre-tool-use.sh`
Expected: still present (force-push, sudo, .harness deletion, test-file-deletion guards are preserved).

---

## Task 11: Delete phase-guard.sh

**Files:**
- Delete: `plugins/harness/scripts/phase-guard.sh`

Prerequisites: Task 10 done.

- [ ] **Step 1: Delete**

Bash: `rm plugins/harness/scripts/phase-guard.sh`

- [ ] **Step 2: Verify**

Bash: `[ ! -f plugins/harness/scripts/phase-guard.sh ] && echo "OK" || echo "FAIL"`

Expected: `OK`.

---

## Task 12: Remove phase_set/phase_restore calls across all spec-edit commands

**Files (all modified):**
- `plugins/harness/commands/amend.md`
- `plugins/harness/commands/clarify.md`
- `plugins/harness/commands/edit.md`
- `plugins/harness/commands/tune-evaluator.md`
- `plugins/harness/commands/retrospective.md`
- `plugins/harness/commands/constitution-amend.md`

Prerequisites: Task 11 done (the referenced script is gone, so its call sites must also go).

- [ ] **Step 1: Grep to find every call site**

Grep: `grep -rn "phase_set\|phase_restore\|phase-guard" plugins/harness/commands/`

Record every file + line. Expected ~6 files, ~12 call sites (phase_set + phase_restore per file).

- [ ] **Step 2: Edit amend.md — remove Step 0 (phase_set) and Step Final (phase_restore)**

Read `plugins/harness/commands/amend.md` lines 39-50 (Step 0: Phase guard section). Apply:

- old_string (Step 0 block):
  ```
  ### Step 0: Phase guard (FR-2)

  Set the phase so the FR-2 spec-ownership hook authorizes the orchestrator's `Edit` calls in Step 4. Without this, the hook will block the patch application as an unauthorized orchestrator-side spec edit.

  ```bash
  source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
  phase_set "amending"
  ```

  The phase persists in `manifest.yaml` across this command's tool calls. It's restored to the prior value at Step Final (success OR failure path).

  ```
- new_string: (empty — remove entire Step 0 section)

Find Step Final section (~lines 180-190). Apply:

- old_string:
  ```
  ### Step Final: Restore phase (FR-2)

  Restore the previous phase so subsequent orchestrator activity reverts to the default hook posture (spec edits blocked).

  ```bash
  source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
  phase_restore
  ```

  Run this even on early-exit paths (e.g., the user cancels in Step 3, the precondition check fails in Step 1). The guard is idempotent — calling it without a prior `phase_set` is a no-op.

  ```
- new_string: (empty — remove entire Step Final section)

- [ ] **Step 3: Edit clarify.md — same pattern**

Read `plugins/harness/commands/clarify.md`. Find and remove any `phase_set`/`phase_restore` blocks (pattern: `source "${CLAUDE_PLUGIN_ROOT...phase-guard.sh"` followed by `phase_set` or `phase_restore`). Remove the surrounding "Phase guard (FR-2)" section heading if present.

- [ ] **Step 4: Edit edit.md — same pattern**

Same surgical removal in `plugins/harness/commands/edit.md`.

- [ ] **Step 5: Edit tune-evaluator.md — same pattern**

Same in `plugins/harness/commands/tune-evaluator.md`.

- [ ] **Step 6: Edit retrospective.md — same pattern**

Same in `plugins/harness/commands/retrospective.md`.

- [ ] **Step 7: Edit constitution-amend.md — same pattern**

Same in `plugins/harness/commands/constitution-amend.md`.

- [ ] **Step 8: Verify all removed**

Grep: `grep -rn "phase_set\|phase_restore\|phase-guard" plugins/harness/commands/ plugins/harness/skills/`

Expected: zero hits across commands/ and skills/.

Grep: `grep -n "phase-guard\|phase_set\|phase_restore" plugins/harness/skills/harness/SKILL.md`
Expected: hit may exist at line 106 in the "Enforcement (FR-2, v1.5+)" paragraph — that's removed in Task 21 (SKILL.md overhaul).

---

## Task 13: Strip poller lifecycle from sprint.md

**Files:**
- Modify: `plugins/harness/commands/sprint.md`

Prerequisites: Task 5 done (scripts/progress-poller.sh deleted).

NOTE: This task removes poller-related code from sprint.md but does NOT do the full bash-to-prose rewrite yet (that's Task 23). After this task, sprint.md has no poller references but still has most of its inline bash.

- [ ] **Step 1: Remove `source ... progress-poller.sh` lines**

Grep first to locate: `grep -n "progress-poller" plugins/harness/commands/sprint.md`

For each hit, remove the entire line. Pattern lines look like:
```
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
```

- [ ] **Step 2: Remove all `start_progress_poller` and `stop_progress_poller` calls**

Grep: `grep -n "start_progress_poller\|stop_progress_poller" plugins/harness/commands/sprint.md`

For each hit, remove the entire line.

- [ ] **Step 3: Remove `PROGRESS_FILE=...` and `PLANNER_PROGRESS=...` assignments**

Grep: `grep -n 'PROGRESS_FILE=\|PLANNER_PROGRESS=\|_progress\.jsonl\|_progress-planner' plugins/harness/commands/sprint.md`

For each hit, remove the entire line (also remove any `trap "stop_progress_poller ..."` lines that referenced these).

- [ ] **Step 4: Remove `trap "stop_progress_poller ..."` and `trap - EXIT` pairs**

Grep: `grep -n "stop_progress_poller.*EXIT\|trap - EXIT" plugins/harness/commands/sprint.md`

Remove matching lines. The `trap` calls were wrapping `claude -p` invocations — keep the `claude -p` call itself, just remove its trap wrapper.

- [ ] **Step 5: Remove poller-progress file-move blocks**

Grep: `grep -n "_progress-planner" plugins/harness/commands/sprint.md`

If the hits are inside a `mv` block (file-move the planner progress file into the feature folder — around line 124-127), delete the whole `if [ -f "$PLANNER_PROGRESS" ]...fi` block.

- [ ] **Step 6: Verify**

Grep: `grep -n "progress-poller\|_progress\.jsonl\|PLANNER_PROGRESS\|PROGRESS_FILE\|start_progress_poller\|stop_progress_poller" plugins/harness/commands/sprint.md`
Expected: zero hits.

---

## Task 14: Remove resolve_model_flag helper + MODEL_FLAG usage from sprint.md and quick.md

**Files:**
- Modify: `plugins/harness/commands/sprint.md`
- Modify: `plugins/harness/commands/quick.md` (if it has any model flag usage — verify first)

Prerequisites: Task 8 done.

- [ ] **Step 1: Remove resolve_model_flag function definition from sprint.md**

Read `plugins/harness/commands/sprint.md` lines 60-78 to locate. Apply:

- old_string:
  ```
  **Per-agent model resolution** (BMAD-inspired): the manifest at `config.models.{planner,generator,evaluator}` can override the default `harness.model` per agent. Planning is usually cheaper on Sonnet than Opus. Use this helper pattern before every dispatch:

  ```bash
  # Resolve the model for a given agent — falls back to harness.model if override is blank.
  # Usage: MODEL_FLAG=$(resolve_model_flag planner)
  resolve_model_flag() {
    local agent="$1"
    local default_model per_agent
    default_model=$(grep '^[[:space:]]*model:' .harness/manifest.yaml | head -1 | awk -F'"' '{print $2}')
    per_agent=$(awk -v key="$agent" '/^[[:space:]]*models:/{in_m=1;next} in_m && $1==key":"{gsub(/"/,"",$2); print $2; exit}' .harness/manifest.yaml)
    local chosen="${per_agent:-$default_model}"
    [ -n "$chosen" ] && printf -- "--model %s" "$chosen"
  }
  ```

  Call `resolve_model_flag planner` before the Planner dispatch, and add the returned flag (if any) to the `claude -p` invocation.

  ```
- new_string: (empty)

- [ ] **Step 2: Remove all MODEL_FLAG= and ${MODEL_FLAG} usage from sprint.md**

Grep: `grep -n "MODEL_FLAG\|resolve_model_flag" plugins/harness/commands/sprint.md`

For each hit:
- Lines assigning `MODEL_FLAG=$(resolve_model_flag ...)` → delete the line.
- `claude -p` lines containing `${MODEL_FLAG}` → remove the `${MODEL_FLAG} \` token (keep the `claude -p` dispatch, just drop the variable substitution and the trailing backslash-continuation before `--append-system-prompt-file`).
- Comment lines about model resolution → delete.

- [ ] **Step 3: Check quick.md**

Grep: `grep -n "MODEL_FLAG\|resolve_model_flag" plugins/harness/commands/quick.md`

If hits exist, apply same cleanup. If none, skip.

- [ ] **Step 4: Verify**

Grep: `grep -rn "MODEL_FLAG\|resolve_model_flag" plugins/harness/`
Expected: zero hits (except possibly CHANGELOG.md documenting the removal).

---

# PHASE 3 — Snippets, Setup, Agent Shrinks

Phase 3 replaces installer + CLAUDE.md snippet + compresses agent prompt files.

---

## Task 15: Create project-local CLAUDE.md.project.txt template

**Files:**
- Create: `plugins/harness/templates/CLAUDE.md.project.txt`

Prerequisites: Task 2 done (templates consolidated).

- [ ] **Step 1: Write the file**

Create `plugins/harness/templates/CLAUDE.md.project.txt` with:

```markdown
# BELCORT Harness Engine — Active in this project

`.harness/manifest.yaml` is present — this project uses the BELCORT Harness pipeline (Planner → Generator → Evaluator) for substantial build tasks.

## The 1% rule

If there is even a 1% chance the harness should be active for a given request, invoke the harness skill via the Skill tool BEFORE any other response. This includes clarifying questions. Not optional. Cannot rationalize out.

## Trigger phrases

When the user's prompt contains any of: `build`, `create`, `implement`, `make an app`, `develop`, `set up a project`, `new feature`, AND the task would take more than ~15 minutes of real work — suggest `/harness:sprint`.

Skip the suggestion for: quick questions ("how do I X?"), single-line fixes, conversational requests, explicit manual-help asks.

## Where the rest lives

For pipeline flow, file ownership, TDD contract, MCP setup, and every other operating rule — see the harness skill. It's auto-invoked by the Skill tool when needed, or by any `/harness:*` slash command. Do not re-state its contents here; let the skill be the single source of truth.
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/templates/CLAUDE.md.project.txt`
Expected: 15–25 lines.

---

## Task 16: Shrink CLAUDE.md.snippet.txt (legacy global-install snippet)

**Files:**
- Rewrite: `plugins/harness/CLAUDE.md.snippet.txt`

Prerequisites: Task 15 done (project-local template exists).

NOTE: The legacy snippet is kept as a minimal backward-compat marker for users whose global CLAUDE.md still has the v1.x BELCORT-HARNESS block. New installs use the project-local CLAUDE.md.project.txt; old installs get a short compatibility stub.

- [ ] **Step 1: Overwrite file**

Write `plugins/harness/CLAUDE.md.snippet.txt` with:

```markdown
# BELCORT Harness Engine — DEPRECATED global snippet

**Notice (v2.0.0+):** BELCORT Harness rules are now installed PROJECT-LOCAL into each project's `./CLAUDE.md` via `/harness:setup`. The global `~/.claude/CLAUDE.md` block this snippet was installed into is no longer used by the harness.

**To migrate from v1.x:**
1. Run `scripts/uninstall-rules.sh` once to remove this block from `~/.claude/CLAUDE.md`.
2. In each harness project, run `/harness:setup` to install the project-local `./CLAUDE.md`.
3. Done — activation rules now live only where they're relevant.

See: `plugins/harness/templates/CLAUDE.md.project.txt` for the new project-local snippet.
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/CLAUDE.md.snippet.txt`
Expected: ≤15 lines.

---

## Task 17: Create scripts/setup.sh for project-local installation

**Files:**
- Create: `plugins/harness/scripts/setup.sh`

Prerequisites: Task 15 done.

- [ ] **Step 1: Write the script**

Create `plugins/harness/scripts/setup.sh` with:

```bash
#!/usr/bin/env bash
# BELCORT Harness — Project-local Setup (v2)
# Creates .harness/ with baseline templates and installs the project CLAUDE.md.
# Idempotent; safe to run multiple times.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEMPLATES="$PLUGIN_ROOT/templates"

if [ ! -d "$TEMPLATES" ]; then
  echo "ERROR: templates directory not found at $TEMPLATES" >&2
  exit 1
fi

# 1. Create .harness/ structure
mkdir -p .harness/spec .harness/evaluator .harness/features .harness/progress

# 2. Copy baseline templates if not already present (never overwrite user's customisations)
copy_if_missing() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    echo "  keep: $dst (already exists, not overwriting)"
  else
    cp "$src" "$dst"
    echo "  new:  $dst"
  fi
}

copy_if_missing "$TEMPLATES/manifest.yaml"                          ".harness/manifest.yaml"
copy_if_missing "$TEMPLATES/ROADMAP.md"                             ".harness/ROADMAP.md"
copy_if_missing "$TEMPLATES/progress/changelog.md"                  ".harness/progress/changelog.md"
copy_if_missing "$TEMPLATES/progress/decisions.md"                  ".harness/progress/decisions.md"
copy_if_missing "$TEMPLATES/progress/known-issues.md"               ".harness/progress/known-issues.md"
copy_if_missing "$TEMPLATES/evaluator/criteria.md.txt"              ".harness/evaluator/criteria.md"
copy_if_missing "$TEMPLATES/evaluator/examples.md.txt"              ".harness/evaluator/examples.md"
copy_if_missing "$TEMPLATES/evaluator/tuning-log.md.txt"            ".harness/evaluator/tuning-log.md"

# 3. Install or patch project-local CLAUDE.md
PROJECT_CLAUDE_MD="./CLAUDE.md"
SNIPPET="$TEMPLATES/CLAUDE.md.project.txt"
BEGIN_MARKER="<!-- BELCORT-HARNESS BEGIN v2 -->"
END_MARKER="<!-- BELCORT-HARNESS END -->"

if [ ! -f "$SNIPPET" ]; then
  echo "ERROR: project snippet template missing at $SNIPPET" >&2
  exit 1
fi

touch "$PROJECT_CLAUDE_MD"

# Strip any existing BELCORT-HARNESS block (any version)
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
awk '
  /<!-- BELCORT-HARNESS BEGIN/ { skip=1; next }
  /<!-- BELCORT-HARNESS END -->/ { skip=0; next }
  !skip { print }
' "$PROJECT_CLAUDE_MD" > "$TMP"

# Append fresh block
{
  cat "$TMP"
  [ -s "$TMP" ] && echo ""
  echo "$BEGIN_MARKER"
  cat "$SNIPPET"
  echo "$END_MARKER"
} > "$PROJECT_CLAUDE_MD"

echo ""
echo "✓ BELCORT Harness installed in this project."
echo "  .harness/            — harness state directory"
echo "  ./CLAUDE.md          — project-local activation rules (scoped to this project only)"
echo ""
echo "Next: run '/harness:doctor' to verify the environment, then '/harness:sprint \"<what to build>\"' to start."

# 4. Legacy global-install check (non-fatal warning)
if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q "<!-- BELCORT-HARNESS BEGIN" "$HOME/.claude/CLAUDE.md"; then
  echo ""
  echo "NOTE: A legacy global BELCORT-HARNESS block was detected at ~/.claude/CLAUDE.md."
  echo "      In v2+ the harness rules install project-local, not globally. You can remove"
  echo "      the legacy global block by running: bash '$PLUGIN_ROOT/scripts/uninstall-rules.sh'"
fi
```

- [ ] **Step 2: Make it executable-friendly (note: on Windows the chmod may no-op)**

Bash: `chmod +x plugins/harness/scripts/setup.sh 2>/dev/null || true`

- [ ] **Step 3: Verify**

Bash: `head -20 plugins/harness/scripts/setup.sh`
Expected: starts with `#!/usr/bin/env bash` and contains the "BELCORT Harness — Project-local Setup" comment.

---

## Task 18: Update commands/setup.md to use the new scripts/setup.sh

**Files:**
- Rewrite: `plugins/harness/commands/setup.md`

Prerequisites: Task 17 done.

- [ ] **Step 1: Overwrite file**

Write `plugins/harness/commands/setup.md` with:

```markdown
---
description: Initialize BELCORT Harness in the current project. Creates .harness/ with templates and installs project-local activation rules into ./CLAUDE.md. Idempotent; safe to re-run.
---

# `/harness:setup`

One-time per-project installer. Scaffolds `.harness/` from the bundled templates and writes a project-local `./CLAUDE.md` with the harness activation rules.

As of v2.0.0, installation is PROJECT-LOCAL. There is no longer a global `~/.claude/CLAUDE.md` write. This keeps harness-specific context out of unrelated projects.

## Procedure

### Step 1: Run the setup script

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
```

The script:
1. Creates `.harness/` with `spec/`, `evaluator/`, `features/`, `progress/` subdirectories.
2. Copies baseline templates (manifest, ROADMAP, progress files, evaluator criteria + examples + tuning-log) into `.harness/`. Never overwrites existing user-customised files.
3. Writes the project-local activation snippet into `./CLAUDE.md` (appending to existing content inside `<!-- BELCORT-HARNESS BEGIN v2 -->` … `<!-- BELCORT-HARNESS END -->` markers).
4. Warns if a legacy global `~/.claude/CLAUDE.md` block from v1.x is detected — suggests the cleanup command.

### Step 2: Run the doctor

After setup, verify the environment:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

On exit 0: tell the user "Environment ready. Run `/harness:sprint \"<prompt>\"`."
On non-zero: show the doctor's full report (includes copy-paste fix commands) and stop.

### Step 3: Tell the user what happened

Summarise: files created in `.harness/`, project CLAUDE.md patched, any legacy global block detected. Give the exact next-step command.

## Notes

- Setup is per-project. If you work in multiple harness projects, run setup in each.
- Re-running setup is safe: existing files in `.harness/` are preserved; only the `./CLAUDE.md` BELCORT-HARNESS block is refreshed.
- To migrate from v1.x global install: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-rules.sh"` once to drop the legacy global block. Then `/harness:setup` in each project.
- To uninstall from a project: remove `.harness/` and the BELCORT-HARNESS block from `./CLAUDE.md`. The plugin remains installed; other projects are unaffected.
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/commands/setup.md`
Expected: 30–50 lines.

Grep: `grep -n "install-rules\.sh\|~/.claude/CLAUDE\.md" plugins/harness/commands/setup.md`
Expected: only the legacy-migration note reference.

---

## Task 19: Shrink agents/planner.md (remove inline criteria template + heartbeat aftermath)

**Files:**
- Modify: `plugins/harness/agents/planner.md`

Prerequisites: Task 6 done (heartbeat sections removed).

- [ ] **Step 1: Locate the inline criteria template**

Read `plugins/harness/agents/planner.md` lines 391-500. Confirm the block starts with `### Template for `.harness/evaluator/criteria.md`` and ends at the `## Build Contract:` heading.

- [ ] **Step 2: Apply edit — collapse inline template to @ reference**

- old_string:
  ```
  ### Template for `.harness/evaluator/criteria.md`

  ```
  # Evaluation Criteria

  ## Weighting Decision
  ```

(The old_string continues through the entire 98-line inlined template — for the actual Edit call, include everything from `### Template for` through the end of the closing ` ``` ` code fence before `### Self-check before finalizing criteria.md`.)

- new_string:
  ```
  ### Template for `.harness/evaluator/criteria.md`

  **Canonical source:** read `@templates/evaluator/criteria.md.txt` (resolves to `${CLAUDE_PLUGIN_ROOT}/templates/evaluator/criteria.md.txt`). That file contains the full skeleton with all four criteria pre-populated and calibration anchors in place. Copy its content as the starting point for `.harness/evaluator/criteria.md`, then customise per the Weighting + Wording principles above. Do NOT author criteria from scratch — the template encodes the decisions Anthropic's harness research documents.

  ```

- [ ] **Step 3: Verify inline template removed**

Bash: `wc -l plugins/harness/agents/planner.md`
Expected: reduced by ~90 lines from pre-Task-6 state (precise line count will depend on which edits landed; just confirm the shrinkage happened).

Grep: `grep -c "^# Evaluation Criteria$\|^## Weighting Decision$" plugins/harness/agents/planner.md`
Expected: `0` (those headings only lived inside the inlined template; now they live only in `templates/evaluator/criteria.md.txt`).

- [ ] **Step 4: Check for stray `@templates/...` references that should resolve cleanly**

Grep: `grep -n "@templates/\|\${CLAUDE_PLUGIN_ROOT.*templates" plugins/harness/agents/planner.md`
Expected: multiple hits (criteria template, story template, examples, init.sh, pause-questions). Each should point to a file that exists in `plugins/harness/templates/`.

Bash (verify each referenced template exists):
```bash
for t in evaluator/criteria.md.txt evaluator/examples.md.txt features/story.md.txt features/pause-questions.md.txt init.sh.txt; do
  [ -f "plugins/harness/templates/$t" ] && echo "OK: $t" || echo "MISSING: $t"
done
```
Expected: all OK.

---

## Task 20: Shrink agents/generator.md (remove inline TDD procedure + steer/heartbeat aftermath)

**Files:**
- Modify: `plugins/harness/agents/generator.md`

Prerequisites: Tasks 3, 6 done (steer + heartbeat gone).

- [ ] **Step 1: Replace Phase 2 Build with TDD body with Superpowers reference**

Read `plugins/harness/agents/generator.md`. Locate the Phase 2 section (~lines 452-540 in the original file, shifted up by the heartbeat removal). It starts with `### Phase 2: Build with TDD` and extends through the `STEP D — COMMIT + PROGRESS LOG` block.

Apply:

- old_string (identify block spanning from `### Phase 2: Build with TDD` through end of STEP D and the trailing `**Repeat A→B→C→D for each deliverable in the contract.**` line — read the file to capture exact bounds, then do one Edit):
  ```
  ### Phase 2: Build with TDD
  ...  [full inlined TDD procedure across ~88 lines]  ...
  **Repeat A→B→C→D for each deliverable in the contract.**

  ```
- new_string:
  ```
  ### Phase 2: Build with TDD

  **Use `superpowers:test-driven-development` as your TDD engine.** Invoke the skill via the Skill tool at the start of Phase 2. It owns the RED → GREEN → REFACTOR discipline per test.

  **BELCORT-specific additions on top of the base TDD cycle:**

  1. **Atomic commit per FR.** After one FR's RED → GREEN → REFACTOR is complete, commit with message `[harness:build] FR-NNN: <one-line behavior>`. Do NOT bundle multiple FRs into a single commit — the Evaluator's reward-hacking scan (git archaeology) depends on per-FR commits as audit evidence. If you find yourself about to write `FR-001/002/003` in a single commit message, STOP and break it apart.

  2. **Per-FR story read per cycle.** Before each FR's RED step, `cat .harness/features/${FEATURE}/stories/FR-NNN.md` — that's your canonical per-cycle context (FR text + ACs + ECs + personas + architectural slice + TDD anchor). If the story file doesn't exist (legacy feature pre-FR-4), fall back to the relevant section of the aggregate `contract.md`.

  3. **After each commit, update progress tracking for mid-build recovery:**
     - `.harness/manifest.yaml` → `state.current_task` = next FR you're about to work on; `state.last_session` = current ISO timestamp.
     - Append to `.harness/progress/changelog.md`:
       ```markdown
       ## YYYY-MM-DD HH:MM — features/NNN — FR-NNN completed
       - Commit: [short hash]
       - Tests added: [N] unit, [N] E2E
       - Next: FR-NNN
       ```
     This per-FR logging is CRITICAL for resumption. If the session ends mid-build, the next Generator subagent reads the changelog and knows exactly where to resume.

  4. **Commit message describes BEHAVIOR, not implementation.**
     GOOD: `[harness:build] FR-003: User can create a new todo with title`
     BAD:  `[harness:build] Add TodoForm component and POST handler`

  **Repeat the TDD cycle for each deliverable in the contract.**

  ```

- [ ] **Step 2: Verify the replacement landed**

Grep: `grep -n "STEP A — RED\|STEP B — GREEN\|STEP C — REFACTOR\|STEP D — COMMIT" plugins/harness/agents/generator.md`
Expected: zero hits (those step headers were part of the inlined TDD block).

Grep: `grep -n "superpowers:test-driven-development" plugins/harness/agents/generator.md`
Expected: at least one hit in the new Phase 2 section.

- [ ] **Step 3: Scan for any remaining references to `pause-questions` to ensure the pause protocol (Phase 1.5) is intact**

Grep: `grep -n "pause-questions\|Pause Protocol" plugins/harness/agents/generator.md`
Expected: multiple hits in Phase 1.5 section (pause protocol is KEPT per Q1 decision).

---

## Task 21: Shrink agents/evaluator.md (de-duplicate AgentLint/Security plugin text)

**Files:**
- Modify: `plugins/harness/agents/evaluator.md`

Prerequisites: Task 6 done.

- [ ] **Step 1: Remove AgentLint + Security Guidance plugin install paragraphs**

Read `plugins/harness/agents/evaluator.md` lines 300-315. Apply:

- old_string:
  ```
  ### AgentLint (if installed)
  Run automated code quality checks: 33 evidence-backed checks across 5 dimensions.
  Use this BEFORE your manual review — it catches patterns humans (and LLMs) systematically miss.
  Install: `/plugin install agentlint@claude-plugins-official`

  ### Security Guidance (if installed)
  Run OWASP-based security scan as part of code quality review.
  Install: `/plugin install security-guidance@claude-plugins-official`

  ---

  ```
- new_string:
  ```
  ### Optional plugins

  If installed, integrate `agentlint` (automated code-quality scan, 33 checks) and `security-guidance` (OWASP scan) into your code-quality review. See SKILL.md § Optional Plugins for install details and the canonical integration guidance.

  ---

  ```

- [ ] **Step 2: Verify**

Grep: `grep -n "agentlint@claude-plugins-official\|security-guidance@claude-plugins-official" plugins/harness/agents/evaluator.md`
Expected: zero hits (install command now lives only in SKILL.md).

---

# PHASE 4 — SKILL.md Overhaul

Phase 3 prepared the @-references. Phase 4 restructures the main skill.

---

## Task 22: Delete duplicated sections from SKILL.md

**Files:**
- Modify: `plugins/harness/skills/harness/SKILL.md`

Prerequisites: Tasks 3, 4 done (steer + assumption-test rows already removed from commands table).

- [ ] **Step 1: Delete the Evaluator Criteria 4-row table**

Read `plugins/harness/skills/harness/SKILL.md` lines 199-208. Apply:

- old_string:
  ```
  ## Evaluator Criteria (4 gradable dimensions)

  | Criterion | Threshold | How tested |
  |-----------|-----------|-----------|
  | Functionality | 6/10 | Playwright: exercise all flows + edge cases |
  | Code Quality | 6/10 | Source review against constitution |
  | Test Coverage | 6/10 | Run suite + check TDD evidence in git log |
  | Product Depth | 5/10 | Use app as real user, try to break it |

  ANY criterion below threshold = FAIL → Generator retries with feedback.

  ```
- new_string:
  ```
  ## Evaluator Criteria

  See `@templates/evaluator/criteria.md.txt` for the authoritative criteria skeleton, thresholds, and calibration guidance. The Planner copies and customises this template into `.harness/evaluator/criteria.md` during PLAN mode Pass 2.

  ```

- [ ] **Step 2: Delete the Manifest schema section**

Read SKILL.md lines ~212-228. Apply:

- old_string:
  ```
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

  ```
- new_string:
  ```
  ## Manifest schema

  See `@templates/manifest.yaml` for the authoritative schema with all fields, defaults, and inline comments. The Planner (during init) writes the first manifest from this template; subsequent agents read and update specific fields per the File Ownership Contract above.

  ```

- [ ] **Step 3: Delete the FR-2 enforcement paragraph from File Ownership Contract**

Read SKILL.md lines 101-108. Apply:

- old_string:
  ```
  **Enforcement (FR-2, v1.5+).** As of v1.5 this rule is no longer prose-only. `hooks/pre-tool-use.sh` inspects every `Edit` and `Write` tool call. Writes to `.harness/spec/*`, `.harness/features/*/contract.md`, and `.harness/evaluator/criteria.md` are blocked when:

  - `CLAUDE_SUBAGENT≠1` (i.e., the orchestrator is invoking, not a dispatched subagent), AND
  - `state.phase` in `manifest.yaml` is NOT in the authorized set: `amending | clarifying | editing | tuning | retrospective | constitution-amending`

  The dedicated spec-edit commands (`/harness:amend`, `/clarify`, `/edit`, `/tune-evaluator`, `/retrospective`, `/constitution-amend`) each call `phase_set <name>` from `scripts/phase-guard.sh` at command entry and `phase_restore` at command exit. This makes the rule mechanically unsabotagable: even if a future Claude tries to "just Edit the file," the hook blocks the call and prints the list of correct commands.

  The bypass for subagents (`CLAUDE_SUBAGENT=1`) is intentional — fresh subagents with clean context ARE the canonical writers. The hook only stops orchestrator-side edits.

  ```
- new_string:
  ```
  **Enforcement note (v2.0.0+).** This rule is prose-only. There is no mechanical hook enforcement; Opus 4.7 follows the constraint when stated explicitly. If the orchestrator ever drifts (edits a spec file directly), the Evaluator's retrospective will surface the drift as a finding during post-merge reconciliation.

  ```

- [ ] **Step 4: Verify deletions**

Grep: `grep -n "FR-2\|phase-guard\.sh\|model_tuning_revision" plugins/harness/skills/harness/SKILL.md`
Expected: zero hits.

Bash: `wc -l plugins/harness/skills/harness/SKILL.md`
Expected: fewer lines than before (target ~210; rises back to ~260 after Task 23 adds new sections).

---

## Task 23: Add seven new sections to SKILL.md

**Files:**
- Modify: `plugins/harness/skills/harness/SKILL.md`

Prerequisites: Task 22 done.

The additions go after the existing `## Rules` section (currently the last section in SKILL.md). They add: Pipeline Timing, Orchestrator Behavior, State Persistence, State Awareness, Recovery, Optional Plugins, Template Index.

- [ ] **Step 1: Append the new sections**

Read the end of `plugins/harness/skills/harness/SKILL.md`. Find the last line of the file (should end with the last item of `## Rules`).

- old_string (the final Rules entry — used as the anchor; adjust to match the file's actual final line):
  ```
  6. Planner does NOT specify files, components, data models, or API paths — those are negotiated between Generator and Evaluator before building.
  ```
- new_string:
  ```
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

  ## Orchestrator Behavior (outside /harness:sprint)

  When the user interacts with the orchestrator while a harness is active but outside a dispatched subagent, the orchestrator:

  1. **Reads state first.** `.harness/manifest.yaml` + `.harness/progress/changelog.md` + `git log --oneline | grep 'harness:' | head -5`. Don't rely on conversational memory of prior messages — state files are authoritative.

  2. **Does not edit spec files directly.** If the user asks for a spec change, route through `/harness:amend`, `/harness:clarify`, `/harness:edit`, or `/harness:constitution-amend`. Even a "just one word" edit leaks the orchestrator's fat chat context into the spec.

  3. **Answers technical questions about the project by reading the spec.** Don't invent details from conversational memory. If the spec doesn't answer the question, say so and offer `/harness:clarify` or propose the answer be captured via `/harness:amend`.

  4. **Refuses to start coding when a harness is active.** The Generator in BUILD mode is the authorized writer of source. If the user asks for code mid-sprint, remind them the Generator is (or will be) doing that work and offer to dispatch it.

  5. **Handles scope-change requests as amendments.** "Actually, let's also support X" is an amendment of the PRD; route through `/harness:amend`.

  6. **Escalates ambiguity.** If the user's request is genuinely ambiguous, ask ONE focused question. Do not guess silently (this is the calibrated-uncertainty principle from Anthropic's Trustworthy Agents research).

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

  1. `cat .harness/manifest.yaml` — read `state.phase`, `state.current_feature`, `state.current_task`, `state.retry_count`.
  2. `tail -20 .harness/progress/changelog.md` — see recent activity.
  3. `git log --oneline | grep 'harness:' | head -5` — cross-check commits against what the changelog claims.
  4. If any of these disagree (e.g., git shows FR-005 committed but changelog says FR-003 was last), **do not silently proceed**. Print the conflict clearly and ask the user which to trust.

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
     - **`building`**: mid-build recovery. Read `state.current_task` and changelog to find last completed FR. Re-dispatch Generator BUILD with instruction: "Resume from FR-NNN. Previous commits: [list]. Skipping completed FRs."
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
  ```

- [ ] **Step 2: Verify all new section headings present**

Grep: `grep -c "^## Pipeline Timing\|^## Orchestrator Behavior\|^## State Persistence\|^## State Awareness\|^## Recovery\|^## Optional Plugins\|^## Template Index" plugins/harness/skills/harness/SKILL.md`

Expected: `7`.

- [ ] **Step 3: Verify SKILL.md still under target length**

Bash: `wc -l plugins/harness/skills/harness/SKILL.md`
Expected: 230–290 lines (post-Task-22 baseline + Task-23 additions).

---

# PHASE 5 — Command File Rewrites

Phase 4 complete. SKILL.md is now the canonical source. Phase 5 rewrites command files so they reference SKILL.md rather than duplicating procedure, and converts inline bash recipes to natural-language steps.

---

## Task 24: Rewrite commands/resume.md to minimal stub

**Files:**
- Rewrite: `plugins/harness/commands/resume.md`

Prerequisites: Task 23 done (SKILL.md § Recovery exists).

- [ ] **Step 1: Overwrite file**

Write `plugins/harness/commands/resume.md` with:

```markdown
---
description: Continue an interrupted harness pipeline from the last checkpoint. Reads manifest.yaml + changelog + git log, then dispatches the appropriate subagent for the current phase.
---

# `/harness:resume`

Run the Recovery procedure documented in the harness skill: see SKILL.md § Recovery.

The procedure:
1. Reads `.harness/manifest.yaml`, `.harness/progress/changelog.md`, and `git log --oneline | grep 'harness:'`.
2. Runs `bash .harness/init.sh` (creating it from `@templates/init.sh.txt` if missing).
3. Prints a status report (project, feature, phase, current_task, retries, recent commits).
4. Dispatches the correct subagent based on current phase.

If state files disagree (git says FR-005 committed but changelog says FR-003 was last), the orchestrator prints the conflict and asks the user which source to trust. Never silently proceeds with conflicting state.
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/commands/resume.md`
Expected: ≤25 lines.

---

## Task 25: Rewrite commands/sprint.md (bash-to-prose + restructure)

**Files:**
- Rewrite: `plugins/harness/commands/sprint.md`

Prerequisites: Task 13 done (poller stripped), Task 14 done (model-flag stripped).

This is the largest rewrite. Target ~250 lines. Preserves all phases but converts file-moves, manifest sed, and phase transitions to natural-language orchestrator instructions; keeps only `claude -p` dispatch + `git worktree` bash.

- [ ] **Step 1: Overwrite the entire file**

Write `plugins/harness/commands/sprint.md` with:

```markdown
---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1-4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → Planner → analyze → human gate → Generator ↔ Evaluator negotiate → Generator BUILD → Evaluator EVALUATE → retry-or-retrospective → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

---

## 0a. Brainstorm check — ambiguity gate (optional)

Before touching the environment, scan the prompt for vagueness signals:

- Prompt ≤2 sentences AND no concrete verbs (build, implement, create, fix, migrate, refactor).
- Uncertainty words: `maybe`, `not sure`, `I think`, `figure out`, `help me decide`.
- Multiple plausible interpretations (e.g., "a dashboard").
- Unfamiliar domain with no prior features in `manifest.yaml`.

If ANY signal hits, offer the user: run `/harness:brainstorm` first (recommended), proceed anyway (Planner will use AskUserQuestions to clarify), or cancel.

If NO signal hits, skip this step silently.

If `.harness/brainstorm-current.md` exists from a prior brainstorm session, treat its content as additional context for the Planner dispatch in Step 1. After Planner creates the feature folder in Step 1, the orchestrator moves `brainstorm-current.md` into the feature folder as `brainstorm.md`.

---

## 0. Doctor — environment preflight (mandatory, blocking)

Before dispatching any subagent, run the doctor:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

- `DOCTOR_EXIT = 0`: environment ready, proceed.
- `DOCTOR_EXIT = 1`: CRITICAL failure. Show the doctor's report (with fix suggestions) and STOP. Tell the user: "Fix the items above, then re-run `/harness:sprint \"$ARGUMENTS\"`."
- `DOCTOR_EXIT = 2`: doctor itself errored. Hard stop. Show stderr. Tell the user to run the doctor manually and investigate.

See [doctor.md](doctor.md) for what it checks.

---

## 1. Plan — dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD + constitution (the WHAT and WHY).
- Pass 2: Architecture + criteria + contract (the HOW — informed by Pass 1).

Dispatch pattern (v1.5.0+): agent role goes in the system prompt via `--append-system-prompt-file`, NOT inlined into the user message. The user message starts with prose (never `---` — Claude CLI parses leading `-` as an option).

If a brainstorm file exists, the orchestrator includes its content in the Planner dispatch as additional context.

```bash
# The only bash required: the dispatch itself.
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in PLAN mode (see your system prompt for the full role and 2-pass procedure).

Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, per-FR story files under features/NNN-name/stories/, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the Generator. Run your 16-point self-validation before exiting and report the pass count.

User request:
$ARGUMENTS

[If brainstorm-current.md exists, append its full content here under a --- BRAINSTORM CONTEXT --- marker.]" \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

**After Planner returns, the orchestrator (not a subagent) performs these housekeeping steps using the Bash/Edit tools. These are natural-language instructions — not a shell script:**

1. Verify the Planner actually wrote the expected files (spec/, evaluator/criteria.md, features/NNN-name/contract.md, stories/, init.sh, manifest.yaml, ROADMAP.md). If any is missing, halt and ask the user.
2. If `.harness/brainstorm-current.md` still exists and the feature folder now exists, move the brainstorm file into the feature folder as `brainstorm.md`.
3. Make `.harness/init.sh` executable. The Planner has no Bash tool, so it cannot chmod its own output.

Then wait for the human gate in Step 2.

---

## 2. Human gate — present summary, wait for approval

Summarize what was planned:

```
═══════════════════════════════
  Harness — Planning Complete
═══════════════════════════════
Project: [name]
Complexity: [small/medium/large] ([N] FRs)
Stack: [framework + db]

PRD: [N] personas, [N] journeys, [N] FRs, [N] NFRs, [N] risks.
Architecture: [N] components, Context7 verified.
Contract: [strategy], [N] deliverables, [N] ACs.
Files: ✓ spec/prd.md, ✓ spec/constitution.md, ✓ spec/architecture.md,
       ✓ evaluator/criteria.md, ✓ features/NNN/contract.md, ✓ init.sh.
Planner self-validation: [N/16 passed].

Next:
  • approved               → negotiate + build
  • /harness:clarify       → surface ambiguities, answer, auto-patch
  • /harness:amend "<X>"   → targeted tweak
  • /harness:edit "<X>"    → multi-file spec edit
  • /harness:rewind planning → fundamental re-plan
═══════════════════════════════
```

**Do NOT proceed until the user explicitly approves.** This is the only mandatory human gate.

If the user wants changes, route through a command — never edit spec files from this orchestrator's context (see SKILL.md § File Ownership Contract).

**Auto-suggest `/harness:clarify`** if: Planner self-validation mentioned ≥3 silent defaults, OR user's approval text contains uncertainty words ("maybe", "not sure", "probably").

---

## 2b. Analyze — cross-artifact consistency (automatic)

Run the [`/harness:analyze`](analyze.md) procedure. CRITICAL findings halt; warnings pass through.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "negotiating"` (Edit tool).

---

## 2c. Negotiate — Generator ↔ Evaluator agree on sprint contract (automatic)

Three dispatches in sequence:

**Round 1: Generator writes proposal.md**

```bash
FEATURE="[read from manifest.yaml state.current_feature]"
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in NEGOTIATE mode (see your system prompt's MODE ROUTING table).

Do NOT write code in this mode. Read the draft contract, architecture direction, constitution, and criteria via Read tool. Write your implementation proposal to .harness/features/${FEATURE}/proposal.md per the template at @templates/features/proposal.md.txt." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/generator.md" \
  --allowedTools "Read,Write,mcp__context7"
```

**Round 2: Evaluator reviews the proposal**

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in REVIEW-PROPOSAL mode (see your system prompt's MODE ROUTING table).

Do NOT run Playwright — there is no app yet. Read .harness/evaluator/criteria.md, the draft contract, and the Generator's proposal. Write your review to .harness/features/${FEATURE}/review.md per the template at @templates/features/review.md.txt with a VERDICT line (agreed | needs-revision)." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/evaluator.md" \
  --allowedTools "Read,Write"
```

**Iterate**: if verdict is `needs-revision`, re-dispatch Generator to revise proposal.md; then Evaluator reviews again. Max 3 rounds (per `config.max_negotiation_rounds` in manifest). If no agreement at round 3, escalate to human.

**Final: Generator writes the negotiated contract**

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in FINALIZE-CONTRACT mode. Merge proposal.md + review.md into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (MUST include **Negotiated**: marker). Do NOT update manifest.yaml — the orchestrator handles phase transitions." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/generator.md" \
  --allowedTools "Read,Write"
```

**After FINALIZE returns**: orchestrator updates `.harness/manifest.yaml` → `state.phase = "building"` using the Edit tool.

See [negotiate.md](negotiate.md) for the standalone variant.

---

## 3. Build — dispatch Generator subagent

Create the worktree:

```bash
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true
```

Assemble the dispatch context. The Generator reads most files via its own Read tool — the inline `$CONTEXT` in the user message is a hint, not authoritative. Prefer per-FR story reads per TDD cycle over the full aggregate contract.

```bash
# Optional: include eval-report.md as retry context if this is a retry
RETRY_CONTEXT=""
[ -f ".harness/features/${FEATURE}/eval-report.md" ] && RETRY_CONTEXT="
--- EVALUATOR FEEDBACK (fix these) ---
$(cat .harness/features/${FEATURE}/eval-report.md)"

CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in BUILD mode (see your system prompt's MODE ROUTING table).

Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). Read per-FR stories at .harness/features/${FEATURE}/stories/FR-NNN.md per cycle — that's your canonical per-cycle context.

Key files (read via Read tool as needed):
- .harness/spec/constitution.md
- .harness/spec/architecture.md
- .harness/features/${FEATURE}/contract.md (final, negotiated)
- .harness/features/${FEATURE}/stories/*.md
- .harness/evaluator/criteria.md
${RETRY_CONTEXT}" \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/generator.md" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

---

## 3a. Pause check — Generator may have requested user input mid-build

If `.harness/features/${FEATURE}/pause-questions.md` exists after the Generator dispatch returns, the Generator paused and needs answers.

Loop (up to `MAX_PAUSES = 3`):
1. Read pause-questions.md; present each question to the user with its "default if unanswered" fallback.
2. Collect answers. Each answer is either a user response, "accept default", or "skip" (marks FR partial).
3. Archive the pause file: move to `.harness/features/${FEATURE}/paused-history/pause-N-TIMESTAMP.md`.
4. Orchestrator increments `manifest.yaml → config.calibration_metrics.agent_checkins` by 1 using the Edit tool.
5. Re-dispatch Generator BUILD with the answers appended to the user message under a `--- PAUSE ANSWERS ---` marker.
6. If a new `pause-questions.md` appears after the re-dispatch, loop again.

After `MAX_PAUSES`, escalate: "Generator has paused N times on this sprint — the contract is likely under-determined. Recommend `/harness:rewind negotiating` to re-spec the affected FR(s) before continuing." Halt the sprint.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "evaluating"` after the Generator dispatch completes successfully.

---

## 4. Evaluate — dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in EVALUATE mode (see your system prompt's MODE ROUTING table).

Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan (Step 4.5), and write your verdict to .harness/features/${FEATURE}/eval-report.md per the template at @templates/features/eval-report.md.txt.

Calibration-mandatory reads BEFORE scoring:
- .harness/evaluator/examples.md (few-shot anchors)
- .harness/spec/evaluator-notes.md (if exists)
- .harness/evaluator/criteria.md

Then: read implementation-report.md, contract.md, proposal.md, review.md, constitution.md, prd.md (via Read tool). Start the app with bash .harness/init.sh. Exercise via Playwright." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/evaluator.md" \
  --allowedTools "Read,Write,Bash,mcp__playwright"
```

---

## 5. Result — read evaluator report and decide

Orchestrator reads `.harness/features/${FEATURE}/eval-report.md`, extracts the `**Result: PASS / FAIL**` line, and reads `state.retry_count` vs `config.max_retries` from manifest.yaml.

### If PASS

**5a-pre. Tuning check — capture human-Evaluator divergence (automatic)**

This implements the Anthropic-documented tuning loop. Present the Evaluator's judgment to the user:

```
═══════════════════════════════
  Harness — Evaluator Judgment Check
═══════════════════════════════
Verdict: PASS
Scores: F:X/10  Q:X/10  T:X/10  P:X/10
Critical findings: [N]  (titles)
Major findings: [N]   (titles)

Do you agree with this evaluation?
  1. Agree — proceed
  2. Disagree — flag specific divergences
  3. Partial — some findings right, some wrong
═══════════════════════════════
```

- **Agree** → skip to retrospective.
- **Disagree/Partial** → enter divergence capture: for each divergence, record what Evaluator said, what the user thinks, and why. Append to `.harness/evaluator/tuning-log.md`. Ask if this should become a calibration example → if yes, append to `.harness/evaluator/examples.md`; if project-specific, append to `.harness/spec/evaluator-notes.md`.
- Check for pattern emergence: if any divergence category has ≥3 entries in tuning-log.md, tell the user: "Pattern detected: [category] has diverged [N] times. Consider `/harness:tune-evaluator`."
- Proceed to retrospective regardless.

**5a. Retrospective — drift analysis (MANDATORY)**

Run `/harness:retrospective` (see retrospective.md). Writes `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update spec files + ADR.

If the retrospective itself fails (subagent errors, malformed output), do NOT silently skip. Block merge, write a stub retrospective.md noting the failure, ask the user to retry / run manually / merge-without-retro with explicit confirmation.

**5b. Merge**

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [one-line summary]"
git worktree remove .worktrees/current 2>/dev/null
```

Then the orchestrator (via Edit tool) updates:
- `ROADMAP.md` — move feature to "✅ Shipped".
- `.harness/manifest.yaml` — `features.completed` append, `features.in_progress = ""`, `state.phase = "complete"`, `state.retry_count = 0`.

Print scores + completion message.

### If FAIL and retries < max

Orchestrator updates `manifest.yaml` → `state.retry_count += 1`, `state.phase = "building"`. Prints failing scores + critical findings. Auto-loops back to Step 3 (BUILD dispatch).

Before retry: run the same tuning check from 5a-pre, but with the reversed framing: "Do you agree the Evaluator should have failed this?" Log divergences. Proceed to retry regardless.

### If FAIL and retries ≥ max

Present the user with options:
1. Force merge with known issues.
2. Manually fix and re-run `/harness:resume` (picks up from evaluating phase).
3. Increase `config.max_retries` and continue.
4. Abandon.

---

## Constraints

- Evaluator MUST be a separate subagent from Generator (GAN isolation).
- All artifacts go in `.harness/features/NNN-name/`.
- Atomic commits on the build branch: `[harness:<phase>] <description>`.
- Subagents are workers, not managers — they NEVER re-invoke the harness pipeline.
- Orchestrator does NOT edit spec files directly (see SKILL.md § File Ownership Contract). Use `/harness:amend`, `/harness:edit`, `/harness:clarify`, or `/harness:constitution-amend`.
```

- [ ] **Step 2: Verify line count**

Bash: `wc -l plugins/harness/commands/sprint.md`
Expected: 240–280 lines.

- [ ] **Step 3: Verify bash-to-prose conversion succeeded**

Grep: `grep -n 'gsed\|sed -i\.bak\|mv .*brainstorm-current\|mv "\$PLANNER_PROGRESS"\|awk.*manifest\.yaml.*manifest\.yaml\.new' plugins/harness/commands/sprint.md`
Expected: zero hits (these were inline file-manipulation recipes).

Grep: `grep -n 'claude -p\|git worktree\|git merge' plugins/harness/commands/sprint.md`
Expected: multiple hits (these are the legitimate bash use cases that should remain).

---

## Task 26: Rewrite commands/quick.md (bash-to-prose)

**Files:**
- Rewrite: `plugins/harness/commands/quick.md`

Prerequisites: Task 25 done (sprint.md already rewritten to the same pattern).

- [ ] **Step 1: Read current quick.md for any features sprint.md doesn't have**

Read `plugins/harness/commands/quick.md`.

- [ ] **Step 2: Overwrite with rewritten version**

Write `plugins/harness/commands/quick.md` with:

```markdown
---
description: Fast harness path for small tasks. Skips Planner, writes a minimal contract inline, single Generator → Evaluator pass. Use when scope is obvious and under 30 minutes.
argument-hint: "<what to build, 1 sentence>"
---

# `/harness:quick` — Fast path

For small tasks where planning overhead is more than the work itself. The prompt is `$ARGUMENTS`. If empty, ask what to build.

## When to use

- Task is obvious and under ~30 minutes.
- Stack + approach is already clear (no novel architectural decisions).
- Single feature, not a cross-cutting change.
- You've done a similar task before in this codebase.

**Anti-cases** (use `/harness:sprint` instead):
- Greenfield project.
- Anything with UX decisions.
- Anything touching architecture (new service, new data model).
- "Quick" that has taken >30 minutes multiple times in your past — the heuristic is lying.

## Procedure

### 0. Doctor preflight

Same as sprint.md. Blocks on CRITICAL.

### 1. Write a minimal contract (orchestrator-authored, not Planner)

Because quick.md skips the Planner, the orchestrator composes a 1-section contract directly. This is the ONLY place the orchestrator authors spec content — and it's intentionally narrow, never for substantial work.

The orchestrator creates `.harness/features/NNN-name/contract.md` (orchestrator chooses NNN = next available number, name = kebab-case of the user prompt) with:

```markdown
# Quick Build Contract

**Quick mode**: single-pass, no negotiation, no retrospective.

## Scope
[One-paragraph restatement of $ARGUMENTS]

## Acceptance Criteria
- AC-1: [observable behavior 1]
- AC-2: [observable behavior 2]
(2-4 ACs max; if you need more, escalate to /harness:sprint)

## Definition of Done
- All ACs verified via Playwright or unit tests.
- Lint clean.
- Atomic commit with message `[harness:quick] <one-line summary>`.
```

Orchestrator also initialises `.harness/manifest.yaml` if missing (copy from `@templates/manifest.yaml`, fill `project.name` + `state.current_feature` + `state.phase = "building"`).

### 2. Build — dispatch Generator BUILD

```bash
FEATURE="[current_feature]"
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in BUILD mode for a /harness:quick sprint. The contract at .harness/features/${FEATURE}/contract.md is minimal — 2-4 ACs. Implement via TDD (use superpowers:test-driven-development). This is NOT the full sprint path: there is no proposal/review, no per-FR stories. Keep scope tight. If the work grows beyond the contract, stop and tell the user to escalate to /harness:sprint." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/generator.md" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

### 3. Evaluate — dispatch Evaluator EVALUATE (single pass)

Same dispatch as sprint.md Step 4. Single pass; no retries on quick.

### 4. Result

- **PASS**: merge directly (no retrospective on quick). Update manifest + ROADMAP.
- **FAIL**: present the eval report to the user with two options: (a) manually fix and re-run `/harness:quick` with the same prompt, or (b) escalate to `/harness:sprint` for a full pipeline treatment.

## Notes

- No tuning check on quick (single-pass, no calibration signal to capture).
- No retrospective on quick (no spec to reconcile against).
- No per-FR stories, no negotiation, no multi-round.
- If the task turned out larger than you thought, running `/harness:sprint` next time for similar work is the correct move.
```

- [ ] **Step 3: Verify**

Bash: `wc -l plugins/harness/commands/quick.md`
Expected: 55–90 lines.

Grep: `grep -n 'source .*progress-poller\|resolve_model_flag\|phase_set\|phase_restore' plugins/harness/commands/quick.md`
Expected: zero hits.

---

## Task 27: Rewrite commands/amend.md (bash-to-prose)

**Files:**
- Rewrite: `plugins/harness/commands/amend.md`

Prerequisites: Task 12 done (phase-guard calls removed).

- [ ] **Step 1: Overwrite**

Write `plugins/harness/commands/amend.md` with:

```markdown
---
description: Targeted spec amendment via a fresh Planner subagent. User gives a one-line change request; Planner produces before→after patches; orchestrator shows diffs; user confirms per-patch; orchestrator mechanically applies approved patches.
argument-hint: "<the change, 1-2 sentences>"
---

# `/harness:amend` — Safe spec amendment

For changing something in the spec after the Planner has finished but before the feature ships. The request is `$ARGUMENTS`. If empty, ask what to change.

## Why fresh-subagent patching?

Before this command, adjusting a plan meant typing the change into chat, where the orchestrator would `Edit` spec files directly. At that moment the orchestrator's context contained every prior message — noise bled into spec files, subsequent agents inherited the noise. The rule: the orchestrator never authors spec content. Every character of every spec edit is produced by a fresh Planner subagent with clean context. The orchestrator only shows diffs and mechanically applies approved ones.

See SKILL.md § File Ownership Contract.

## When to use

- At the human approval gate (before negotiate).
- During negotiate (if issues surface).
- During building (rare — usually `/harness:rewind negotiating` is cleaner).
- Between features (to evolve the spec).

## When NOT to use

- Ambiguity resolution → `/harness:clarify`.
- Fundamental direction change → `/harness:rewind planning`.
- Post-merge drift → `/harness:retrospective`.
- Multi-file coordinated change → `/harness:edit`.
- Constitution change → `/harness:constitution-amend`.

## Procedure

### Step 1: Precondition check

Orchestrator reads `.harness/manifest.yaml` → `state.current_feature`. Verify `.harness/features/${FEATURE}/contract.md` exists. If not, tell the user "No draft contract for ${FEATURE}. Run /harness:sprint first." and exit.

If the contract has the `**Negotiated**:` marker (negotiation already complete), warn the user: "This contract was finalized through negotiation. Applying an amendment will require re-running `/harness:negotiate` to propagate changes. Continue?" On no → exit. On yes → continue; flag in changelog later.

### Step 2: Dispatch fresh Planner in AMEND mode

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in AMEND mode (see your system prompt's MODE ROUTING table).

The user wants this specific change applied to the spec:
$ARGUMENTS

Read the current spec via Read tool (paths: .harness/spec/prd.md, architecture.md, constitution.md, .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md). Produce structured before→after patches to .harness/features/${FEATURE}/amend-patches.md per your AMEND mode procedure. Do NOT apply patches — the orchestrator applies after user confirmation." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT}/agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

### Step 3: Read patches, present to user

Orchestrator reads `.harness/features/${FEATURE}/amend-patches.md` and presents:

```
═══════════════════════════════
  Harness — Amendment Preview
═══════════════════════════════
Request: ${ARGUMENTS}

Planner's interpretation: [1-3 sentences from the patches file]

Impact:
  - Modifies: [list of files]
  - Unclear: [UNCLEAR items, if any]
  - Out of scope: [OOS items, if any]

Patches:
  [1] spec/prd.md § FR-003 — [short title]
  [2] spec/architecture.md § ... — [short title]
  [3] features/${FEATURE}/contract.md § ... — [short title]

For each patch, show the before/after diff.

Apply all / Apply some / Apply none / Show diff N / Cancel?
═══════════════════════════════
```

### Step 4: Apply approved patches

For each patch the user approves, the orchestrator uses the Edit tool with the patch's `old_string` and `new_string`. The patch content was authored by the fresh Planner subagent; the orchestrator is performing a mechanical apply.

### Step 5: Run analyze

Invoke `/harness:analyze`. CRITICAL findings → report + offer rollback or follow-up amendment.

### Step 6: Re-negotiation warning (if contract was FINAL)

If Step 1 detected a finalized contract and the amendment modified it, tell the user: "Amendment applied to a previously-negotiated contract. The Generator's proposal and Evaluator's review may no longer match. Run `/harness:negotiate` to re-negotiate before building." Do NOT auto-run negotiate.

### Step 7: Log ADR

Append to `.harness/progress/decisions.md` using the template at `@templates/progress/decisions.md`:

```markdown
## ADR-NNN — Amendment: [short title]
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE}
**Status**: Accepted

### Context
User requested: "${ARGUMENTS}"

### Decision
Amended: [list of files modified]
Patches applied: [N] of [proposed M]

### Consequences
- [What changed in the spec]
- [Downstream: re-negotiate required / none / etc.]
```

### Step 8: Update changelog

Append to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Amendment applied
- Request: "${ARGUMENTS}"
- Patches applied: [N]
- Files modified: [list]
- Post-analyze: [PASS/WARN/CRITICAL]
- Re-negotiate required: [yes/no]
```

## Anti-patterns

- **Chat-then-amend**: typing the change into chat first, then running `/harness:amend`. Run `/harness:amend` as the FIRST response to user feedback — don't discuss first, or the discussion pollutes subsequent context.
- **Batch amendments**: "change X, and also Y, and while we're at it Z" → run three separate amendments.
- **Skipping analyze**: Step 5 isn't optional.
- **Amending post-build**: use `/harness:retrospective` instead.
- **Treating UNCLEAR flags as minor**: resolve them (perhaps via `/harness:clarify`) before applying.

## Files written

| File | Writer |
|---|---|
| `.harness/features/NNN/amend-patches.md` | Planner AMEND mode |
| `spec/*.md` (or contract.md) | Orchestrator applies Planner patches via Edit |
| `progress/decisions.md` | Orchestrator appends ADR |
| `progress/changelog.md` | Orchestrator appends |
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/commands/amend.md`
Expected: 100–140 lines.

Grep: `grep -n 'phase_set\|phase_restore\|phase-guard' plugins/harness/commands/amend.md`
Expected: zero hits.

---

## Task 28: Rewrite commands/clarify.md, edit.md, retrospective.md, tune-evaluator.md, constitution-amend.md (bash-to-prose)

**Files:**
- Rewrite: `plugins/harness/commands/clarify.md`
- Rewrite: `plugins/harness/commands/edit.md`
- Rewrite: `plugins/harness/commands/retrospective.md`
- Rewrite: `plugins/harness/commands/tune-evaluator.md`
- Rewrite: `plugins/harness/commands/constitution-amend.md`

Prerequisites: Tasks 12, 27 done.

NOTE: All five commands follow the same pattern as amend.md (dispatch fresh subagent, read patches, present to user, apply, log ADR, update changelog). This task is mechanical: apply the amend.md template to each, preserving each command's specific subagent mode and inputs.

- [ ] **Step 1: Rewrite clarify.md**

Read current `plugins/harness/commands/clarify.md` to identify its specific logic (CLARIFY-QUESTIONS then CLARIFY-APPLY two-phase). Write a new version that:
- Follows the same structure as amend.md Steps 1-8.
- Uses CLARIFY-QUESTIONS mode for question generation (writes `clarifications.md`), then CLARIFY-APPLY mode for patch generation (writes `clarify-patches.md`).
- Between the two dispatches: orchestrator presents questions to user, collects answers, appends them to `clarifications.md`.
- No `phase_set`/`phase_restore`.
- No inline bash for manifest reads (describe in prose).

Target ~120 lines.

- [ ] **Step 2: Rewrite edit.md**

Same pattern as amend.md but uses Planner EDIT mode. EDIT is cascade-aware (multi-file), so the patches file is `edit-patches.md` containing patches for multiple files.

Target ~110 lines.

- [ ] **Step 3: Rewrite retrospective.md**

Retrospective is orchestrator-driven (no subagent dispatch — orchestrator scans source + reads reports). Steps:
1. Read `contract.md`, `implementation-report.md`, `eval-report.md`, source code (via Read tool), `git log`.
2. Identify drift: positive (extra done), negative (missing), neutral (different path, same outcome).
3. Write `retrospective.md` per template.
4. Present drift findings to user.
5. On approval, apply spec updates via Edit tool.
6. Update ROADMAP (move to Shipped) + manifest (features.completed).
7. Append ADR + changelog.

Target ~100 lines.

- [ ] **Step 4: Rewrite tune-evaluator.md**

Orchestrator-driven (no subagent). Steps:
1. Read `tuning-log.md`, group by divergence category.
2. For categories with ≥3 entries, propose either (a) new calibration example to `examples.md` or (b) prompt tweak to `evaluator.md`.
3. Present proposals to user.
4. On approval, apply via Edit tool; append ADR if prompt tweaked; bump `manifest.yaml → harness.model_tuning_revision`.
5. Update changelog.

Target ~90 lines.

- [ ] **Step 5: Rewrite constitution-amend.md**

High-ceremony 5-gate flow. Steps:
1. Validate `$ARGUMENTS` reason ≥50 chars (typed confirmation).
2. Check in-progress state — if a sprint is active, warn + require explicit "proceed anyway" confirmation.
3. Dispatch Planner CONSTITUTION-AMEND mode → writes `.harness/constitution-amend-patches.md`.
4. Present patches + conflict-check to user.
5. If user approves: dispatch Evaluator REVALIDATE mode per completed feature (sample up to 10); write per-feature compliance reports.
6. Summarise: total features / compliant / backport-recommended / grandfather-acceptable.
7. On user approval of revalidation outcomes: apply constitution patches via Edit tool; handle backport/grandfather decisions per feature (log as ADRs).
8. Update `manifest.yaml → constitution.amendments` with the entry.
9. Mandatory ADR + changelog.

Target ~150 lines (legitimately long due to the 5 gates).

- [ ] **Step 6: Verify all five files**

Bash:
```bash
for f in clarify edit retrospective tune-evaluator constitution-amend; do
  echo -n "commands/${f}.md: "
  wc -l "plugins/harness/commands/${f}.md" | awk '{print $1}'
done
```
Expected: all ≤160 lines (see targets above).

Grep: `grep -rn 'phase_set\|phase_restore\|phase-guard\|progress-poller\|resolve_model_flag' plugins/harness/commands/clarify.md plugins/harness/commands/edit.md plugins/harness/commands/retrospective.md plugins/harness/commands/tune-evaluator.md plugins/harness/commands/constitution-amend.md`
Expected: zero hits.

---

## Task 29: Simplify commands/rewind.md (267 → ~80 lines)

**Files:**
- Rewrite: `plugins/harness/commands/rewind.md`

Prerequisites: Task 12 done.

- [ ] **Step 1: Overwrite**

Write `plugins/harness/commands/rewind.md` with:

```markdown
---
description: Archive-based phase reset for the current feature. Moves the whole feature folder (or specific artifacts) to .archive/, resets manifest state, optionally resets the build git branch. Requires typed confirmation.
argument-hint: "<target phase: planning | analyzing | negotiating | building | evaluating>"
---

# `/harness:rewind`

Reset a feature to an earlier phase when something went fundamentally wrong and patching forward is more expensive than restarting from a clean checkpoint. Target phase is `$ARGUMENTS`. If empty, ask.

**Archive-based, not delete-based.** Every file removed from the active state is moved to `.harness/features/NNN/.archive/TIMESTAMP/`, never deleted. You can inspect and restore manually if needed.

## Valid targets

| Target | What gets archived | What survives |
|---|---|---|
| `planning` | whole feature folder | `.harness/spec/*` (from prior features), evaluator artifacts |
| `analyzing` | `analysis-report.md` | spec, draft contract |
| `negotiating` | `proposal.md`, `review.md`, final contract (draft is kept) | spec, draft contract |
| `building` | `implementation-report.md`, `eval-report.md`, `retrospective.md` | spec, final contract, proposal, review |
| `evaluating` | `eval-report.md`, `retrospective.md` | all build artifacts + source |

`complete` is not a valid rewind target (feature is shipped; start a new one).

## Procedure

### Step 1: Validate target + feature exists

Orchestrator reads `$ARGUMENTS` and `.harness/manifest.yaml → state.current_feature`. Validate target is one of the five valid phases; validate a current feature exists.

### Step 2: Preview

Show the user what will be archived, what will survive, the manifest delta (phase, current_task, retry_count), and — if rewinding to building or earlier and the `harness/build/${FEATURE}` branch has commits — a git warning.

### Step 3: Require typed confirmation

The user must type exactly `rewind to <target>` (not a fuzzy match — rewind is the most destructive command). On any other input, cancel with "rewind cancelled, nothing changed."

### Step 4: Archive

Orchestrator creates `.harness/features/${FEATURE}/.archive/TIMESTAMP/` (via Bash tool using `mkdir -p`). For each file being archived, move it with `mv`. Write a `REWIND-MANIFEST.md` in the archive directory recording what was moved, from which phase, and the git state at time of rewind.

The specific file set depends on target phase (see table above). For `planning` target: archive the whole feature folder and set `state.current_feature = ""` so the next `/harness:sprint` creates a fresh one.

### Step 5: Reset manifest state

Using the Edit tool on `.harness/manifest.yaml`:
- `state.phase` = target.
- `state.current_task` = "" (if rewinding past building).
- `state.retry_count` = 0.
- `state.negotiation_round` = 0 (if rewinding past negotiating).
- `state.last_session` = current ISO timestamp.

### Step 6: Handle git (optional, separate confirmation)

If rewinding to `building` or earlier AND branch `harness/build/${FEATURE}` has commits, present:

```
Options:
  (a) Keep commits — branch survives, manual cherry-pick/discard later [SAFE DEFAULT]
  (b) Reset branch to base — destroys [N] commits. Type "reset build branch" to confirm.
      Commands: git checkout harness/build/${FEATURE}
                git reset --hard $(git merge-base main harness/build/${FEATURE})
                git checkout -
  Skip — don't touch the branch.
```

Default to (a) if the user hesitates.

### Step 7: Log

Append to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Rewind
- From: [previous phase]
- To: ${TARGET}
- Archived: [N] files to .archive/TIMESTAMP/
- Git action: [kept / reset branch / no branch]
```

Append ADR to `.harness/progress/decisions.md`.

### Step 8: Tell the user what's next

```
═══════════════════════════════
  Harness — Rewind Complete
═══════════════════════════════
Feature ${FEATURE} reset to phase: ${TARGET}
Archive: .harness/features/${FEATURE}/.archive/TIMESTAMP/
ADR logged: progress/decisions.md

Next:
  • /harness:resume — continue from ${TARGET}
  • Or make adjustments first (e.g., /harness:edit), then /harness:resume
  • To abandon: delete features/${FEATURE}/ and reset manifest manually
═══════════════════════════════
```

## Anti-patterns

- Rewinding repeatedly without addressing root cause — three rewinds of one feature = spec is wrong. Use `/harness:rewind planning` once OR abandon.
- Resetting git branches without backup — option (b) is destructive.
- Using rewind as undo for a single file — `git checkout -- <file>` is better.
- Rewinding after merge — use `/harness:retrospective` instead.
```

- [ ] **Step 2: Verify**

Bash: `wc -l plugins/harness/commands/rewind.md`
Expected: 75–100 lines (target was ~80).

---

# PHASE 6 — Doctor, Docs, and Canary Verification

Final cleanup.

---

## Task 30: Update doctor.sh for v2 (remove legacy global-CLAUDE.md check)

**Files:**
- Modify: `plugins/harness/scripts/doctor.sh`

Prerequisites: Task 17 done (setup.sh handles project-local install now).

- [ ] **Step 1: Remove the global CLAUDE.md sync check**

Read `plugins/harness/scripts/doctor.sh` lines 225-263 (the `# CLAUDE.md rules` block). Apply:

- old_string:
  ```
  # CLAUDE.md rules (required for session-start behavior + 1% rule)
  if [ -f "$CLAUDE_HOME/CLAUDE.md" ] && grep -q "BELCORT-HARNESS BEGIN" "$CLAUDE_HOME/CLAUDE.md" 2>/dev/null; then
    ... [~40 lines of global-install sync check — apply old_string for the full block to end of the else branch (`add_result "CRITICAL" "FAIL" "Global harness rules" ...`)] ...
  fi
  ```
- new_string:
  ```
  # Project-local CLAUDE.md check (v2+): verify ./CLAUDE.md has a BELCORT-HARNESS block
  # if a .harness/ is present. Global ~/.claude/CLAUDE.md check was removed in v2 —
  # harness rules install project-local now. If a legacy global block still exists,
  # setup.sh warns the user about cleanup; doctor doesn't flag it as a failure.
  if [ -d ".harness" ]; then
    if [ -f "./CLAUDE.md" ] && grep -q "BELCORT-HARNESS BEGIN" "./CLAUDE.md" 2>/dev/null; then
      add_result "CRITICAL" "PASS" "Project CLAUDE.md" "harness activation block present in ./CLAUDE.md"
    else
      add_result "CRITICAL" "FAIL" "Project CLAUDE.md" \
        ".harness/ exists but ./CLAUDE.md has no BELCORT-HARNESS activation block" \
        "Run: /harness:setup  (creates or patches ./CLAUDE.md)"
    fi
  fi

  ```

- [ ] **Step 2: Add agent-file readability check (new)**

Locate a reasonable spot in doctor.sh (after the harness plugin presence check, around line 220). Add:

```bash
# Agent file integrity — if plugin is corrupt, catch it before sprint
if [ -n "$PLUGIN_FOUND" ]; then
  PLUGIN_DIR="$(dirname "$PLUGIN_FOUND")/../.."  # back out of skills/harness/SKILL.md
  for agent in planner generator evaluator; do
    if [ -f "$PLUGIN_DIR/agents/${agent}.md" ] && [ -r "$PLUGIN_DIR/agents/${agent}.md" ]; then
      add_result "CRITICAL" "PASS" "Agent file: ${agent}.md" "readable"
    else
      add_result "CRITICAL" "FAIL" "Agent file: ${agent}.md" \
        "not found or not readable at $PLUGIN_DIR/agents/${agent}.md — plugin may be corrupt" \
        "Reinstall plugin: /plugin uninstall harness && /plugin install harness@belcort-harness"
    fi
  done
fi
```

- [ ] **Step 3: Verify**

Grep: `grep -n 'add_result.*Agent file' plugins/harness/scripts/doctor.sh`
Expected: 3 hits (one per agent).

Grep: `grep -n 'BELCORT-HARNESS.*CLAUDE_HOME' plugins/harness/scripts/doctor.sh`
Expected: zero hits (old global check is gone).

Bash: `wc -l plugins/harness/scripts/doctor.sh`
Expected: 300–340 lines.

- [ ] **Step 4: Smoke-test doctor.sh**

Bash: `bash plugins/harness/scripts/doctor.sh; echo "Exit: $?"`

Expected: runs to completion without syntax errors. Exit code depends on the local environment — that's fine; we only need the script itself to not throw.

---

## Task 31: Update docs/anthropic-alignment.md with v2 delta

**Files:**
- Modify: `docs/anthropic-alignment.md`

Prerequisites: all prior tasks done.

- [ ] **Step 1: Add v2 section**

Read `docs/anthropic-alignment.md`. Find the "Version provenance" section (around line 54-61). Apply:

- old_string (the last existing version bullet):
  ```
  - v1.5 — trustworthy-agents deep alignment pass: subagent observability streaming (heartbeat + poller), hook-enforced spec-file ownership (behavioral → mechanical), mid-build pause-and-ask (Generator gains calibrated-uncertainty path), per-FR story files (BMAD V6 hyper-detailed pattern), component-as-assumption stress test (operationalises Rajasekaran 2026 quote), constitution amendment governance (SpecKit pattern with high ceremony)
  ```
- new_string:
  ```
  - v1.5 — trustworthy-agents deep alignment pass: subagent observability streaming (heartbeat + poller), hook-enforced spec-file ownership (behavioral → mechanical), mid-build pause-and-ask (Generator gains calibrated-uncertainty path), per-FR story files (BMAD V6 hyper-detailed pattern), component-as-assumption stress test (operationalises Rajasekaran 2026 quote), constitution amendment governance (SpecKit pattern with high ceremony)
  - v2.0 — minimalist refactor, directly motivated by Rajasekaran 2026's quote: *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."* Removed components whose underlying assumption went stale on Opus 4.7: progress-poller + heartbeat (stdout streaming is native), phase-guard + FR-2 hook (instruction-following on prose constraints is reliable), assumption-test command (meta-tool never run in practice), /harness:steer (retry loop + amend cover its cases), per-agent model pinning (undocumented, unused), global CLAUDE.md install (scoping violation). Preserved: every Anthropic-aligned core capability (GAN isolation, file-based comm, negotiation, Playwright evaluation, few-shot calibration, two-stage grading, tuning loop, pause protocol). ~45% LoC reduction. Full plan: `docs/superpowers/plans/2026-04-21-belcort-v2-minimalist-refactor.md`.
  ```

- [ ] **Step 2: Verify**

Grep: `grep -n "^- v2\.0" docs/anthropic-alignment.md`
Expected: exactly one hit.

---

## Task 32: Canary sprint verification

Prerequisites: all tasks 1-31 complete.

**Note**: This task verifies the refactored harness actually works. It requires a writable project directory with Claude Code installed + the harness plugin + context7 + playwright MCPs.

- [ ] **Step 1: Pick a small canary prompt**

Suggested canary: `"build a 2-FR todo app: user can add a todo with title; user can mark a todo complete"`. 2 FRs, obvious stack, should complete in one pass.

- [ ] **Step 2: Initialize a clean test project**

Bash:
```bash
mkdir -p /tmp/belcort-v2-canary
cd /tmp/belcort-v2-canary
git init
/harness:setup   # uses the new v2 setup
```

Verify:
- `.harness/` created with manifest, ROADMAP, progress/*, evaluator/*.
- `./CLAUDE.md` has BELCORT-HARNESS v2 block.
- No writes to `~/.claude/CLAUDE.md`.

- [ ] **Step 3: Run doctor**

`/harness:doctor`

Expected: exit 0 with `Environment ready` message (assuming MCPs + Claude Code + Superpowers plugin installed). If any CRITICAL fails, fix before proceeding.

- [ ] **Step 4: Run canary sprint**

`/harness:sprint "build a 2-FR todo app: user can add a todo with title; user can mark a todo complete"`

Observe:
- Planner dispatches, writes spec + contract + stories.
- Analyze auto-runs.
- Human gate appears — approve.
- Negotiate auto-runs (proposal → review → FINALIZE).
- Generator BUILD runs TDD cycles; atomic commits per FR.
- Evaluator EVALUATE runs Playwright against running app.
- Tuning check appears — choose Agree.
- Retrospective runs; merge happens.
- Manifest updated; ROADMAP updated.

- [ ] **Step 5: Verify post-canary state**

Bash (in /tmp/belcort-v2-canary):
```bash
cat .harness/manifest.yaml | grep -E "phase:|current_feature:|completed:"
ls .harness/features/*/eval-report.md
ls .harness/features/*/retrospective.md
git log --oneline | head -10
```

Expected:
- phase = "complete".
- At least one completed feature.
- eval-report + retrospective exist.
- Multiple `[harness:build] FR-NNN: ...` commits + one `[harness:merge]` commit.

- [ ] **Step 6: Clean up canary**

Bash: `rm -rf /tmp/belcort-v2-canary`

- [ ] **Step 7: If canary fails**

Do NOT attempt to ship. File the failure against the refactor spec's success criteria in `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md § 9` and stop. A failed canary means one of the cuts removed something that WAS load-bearing. Restore from the backup made in pre-work, identify which cut broke the pipeline, and update the spec before retrying.

---

## Post-plan checklist (self-review)

After completing all 32 tasks, verify the design spec's Success Criteria (§9):

- [ ] LoC reduction ≥40%. Measure: `find plugins/harness -type f \( -name "*.md" -o -name "*.sh" -o -name "*.yaml" -o -name "*.json" \) ! -path "*/templates/*" -exec wc -l {} + | tail -1`. Compare to pre-refactor baseline.
- [ ] No duplicate content across md files. Spot-check: `grep -c "fresh subagent" plugins/harness/skills/harness/SKILL.md plugins/harness/agents/*.md` — should only be SKILL.md + subagent-context blocks.
- [ ] Canary sprint passes (Task 32).
- [ ] All `/harness:*` commands still functional except `steer` and `assumption-test` (which were intentionally removed).
- [ ] Doctor passes on a fresh machine.
- [ ] SessionStart hook ≤20 lines: `wc -l plugins/harness/hooks/session-start.sh`.
- [ ] No write to `~/.claude/CLAUDE.md` during `/harness:setup`. Verified via Task 32 Step 2.
- [ ] Root `templates/` does not exist: `[ ! -d templates ]`.
- [ ] No `phase_set`/`phase_restore` calls anywhere: `grep -rn "phase_set\|phase_restore" plugins/harness/`.
- [ ] Generator BUILD references `superpowers:test-driven-development`: `grep -n "superpowers:test-driven-development" plugins/harness/agents/generator.md`.
- [ ] SKILL.md has all 7 new sections: `grep -c "^## Pipeline Timing\|^## Orchestrator Behavior\|^## State Persistence\|^## State Awareness\|^## Recovery\|^## Optional Plugins\|^## Template Index" plugins/harness/skills/harness/SKILL.md` → `7`.
- [ ] No inlined criteria/manifest templates in agents: `grep -n "^## Weighting Decision\|^## Functionality (threshold" plugins/harness/agents/*.md` → zero hits.
- [ ] Bash in commands is limited to `claude -p` + `git` + doctor/setup calls: spot-check by grepping for `sed`, `awk`, `mv`, `cp` inside code fences of `commands/*.md`.
- [ ] Plugin version is 2.0.0: `grep '"version"' plugins/harness/.claude-plugin/plugin.json`.

If ANY criterion fails, fix in place before declaring the refactor done.

---

*End of plan. Next: user chooses execution mode (subagent-driven or inline).*
