# BELCORT Harness — Audit & Refine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the v2.0 minimalist ruler to four post-v2.0 stale-assumption targets plus two operational hardening items, in a single PR. ~300 LoC net reduction, no user-facing command surface change beyond removing one redundant front door.

**Architecture:** Six changes, sequenced by leverage and risk. Change #1 (1M-context confirmation) is the foundation that justifies Change #6 (soft-only Planner gate). Change #2 (drop story files) and Change #4 (Planner mode collapse) are the structural simplifications. Change #3 (pause snapshot) and Change #5 (drop `/negotiate`) are surgical tightenings.

**Tech Stack:** Bash (doctor.sh, hooks), Markdown (agent prompts, command files, SKILL.md, README, templates), no compiled code, no language tests beyond shell-script smoke tests.

**Spec:** `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md`

---

## File Structure (what gets touched)

| File | Disposition |
|---|---|
| `plugins/harness/scripts/doctor.sh` | **Modify** — add 1M-context banner (Task 1) |
| `plugins/harness/commands/sprint.md` | **Modify** — add 1M confirmation step (Task 1), inline negotiate escalation (Task 21), drop story dispatch line (Task 9) |
| `plugins/harness/commands/quick.md` | **Modify** — add 1M confirmation step (Task 2) |
| `README.md` | **Modify** — Quick Start launch banner (Task 3), drop `/negotiate` row (Task 22), drop story refs (Task 13) |
| `plugins/harness/agents/planner.md` | **Modify** — drop story-files section (Task 4), File Placement Summary edit (Task 5), MODE ROUTING refactor (Task 14), unified MODE: EDIT (Task 15), soft-gate paragraph reword (Task 24) |
| `plugins/harness/agents/generator.md` | **Modify** — Phase 2 rule 2 rewrite (Task 6), Phase 1.5 step 4 snapshot requirement (Task 11), Phase 1 rule 3 snapshot precedence (Task 12) |
| `plugins/harness/agents/evaluator.md` | **No change required** — confirmed in Task 7 |
| `plugins/harness/templates/features/story.md.txt` | **Delete** (Task 8) |
| `plugins/harness/templates/features/pause-questions.md.txt` | **Modify** — add State at pause section (Task 10) |
| `plugins/harness/skills/harness/SKILL.md` | **Modify** — drop story rows (Task 12+13), drop `/negotiate` row (Task 23), update mode references (Task 19) |
| `plugins/harness/commands/amend.md` | **Modify** — inline AMENDMENT constraints in dispatch (Task 16) |
| `plugins/harness/commands/edit.md` | **Modify** — inline EDIT constraints in dispatch (Task 17) |
| `plugins/harness/commands/clarify.md` | **Modify** — CLARIFY-APPLY half uses EDIT mode marker (Task 18) |
| `plugins/harness/commands/constitution-amend.md` | **Modify** — inline CONSTITUTION constraints in dispatch (Task 19) |
| `plugins/harness/commands/negotiate.md` | **Delete** (Task 20) |
| `CHANGELOG.md` | **Modify** — v2.2.0 entry (Task 25) |
| `ROADMAP.md` | **Modify** — v2.2 shipped + v3 watch (Task 26) |
| `docs/anthropic-alignment.md` | **Modify** — add v2.2 rows (Task 27) |

---

## Working-directory note

The current project is at `C:\Users\zhant\Desktop\belcort-harness-main` and is not currently a git repo per the harness session environment. Each task's "commit" step is therefore optional/conditional — if you're running this in a git-managed checkout, do the commit; if not, skip the git command and continue. The plan tasks are still atomic at the file level.

---

## Task 1: Add 1M-context confirmation banner to doctor.sh

**Files:**
- Modify: `plugins/harness/scripts/doctor.sh` (add a new check function before the OUTPUT section, ~line 335)

- [ ] **Step 1: Read the current end of doctor.sh**

Open `plugins/harness/scripts/doctor.sh`. Locate the section "RECOMMENDED: Bash permission pre-allows for npm-family commands" (around line 309). The new check is added immediately AFTER that section, BEFORE the "OUTPUT" section (around line 335).

- [ ] **Step 2: Add the 1M-context check block**

Insert this block between the npm-allow check and the OUTPUT section, right after the closing `fi` of the npm-allow block:

```bash
# ─────────────────────────────────────────────────────────────
# CRITICAL (advisory): 1M context window for Generator BUILD
# ─────────────────────────────────────────────────────────────
# Claude Code does not currently expose --model to plugin scripts, so this
# check cannot be mechanical. It prints an advisory banner reminding the user
# that BUILD dispatches on multi-stratum features need the [1m] variant. The
# check ALWAYS PASSES — it is a banner-with-status, not a blocker. Future
# Claude Code versions exposing model info could promote it to a real check.
add_result "RECOMMEND" "WARN" "1M context window (Opus 4.7[1m])" \
  "BELCORT cannot mechanically detect the active Claude Code model. For sprints touching multi-stratum work (foundation, ingestion, full-stack features), the Generator BUILD dispatch can exceed the default 200K Opus context. Confirm Claude Code was launched with the 1M variant." \
  "Relaunch Claude Code with: claude --model claude-opus-4-7[1m]"
```

- [ ] **Step 3: Verify the script still parses**

Run: `bash -n plugins/harness/scripts/doctor.sh`
Expected: no output (syntax OK).

- [ ] **Step 4: Run doctor.sh and confirm the banner appears**

Run: `bash plugins/harness/scripts/doctor.sh 2>&1 | grep -A 2 "1M context"`
Expected output includes: `[RECOMMEND] WARN  1M context window (Opus 4.7[1m])` and the relaunch command.

- [ ] **Step 5: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/scripts/doctor.sh
git commit -m "[harness:refine] doctor.sh: add 1M-context advisory banner"
```

---

## Task 2: Add 1M-context confirmation prompt to sprint.md Step 0

**Files:**
- Modify: `plugins/harness/commands/sprint.md` (insert before the existing `## 0. Doctor` section, around line 29)

- [ ] **Step 1: Locate the insertion point**

Open `plugins/harness/commands/sprint.md`. Find the line `## 0. Doctor — environment preflight (mandatory, blocking)` (around line 29).

- [ ] **Step 2: Insert a new pre-doctor section above it**

Replace the line `## 0. Doctor — environment preflight (mandatory, blocking)` with this block:

```markdown
## 0a. 1M-context confirmation (recommended — prevents Generator BUILD truncation)

Before dispatching any subagent, the orchestrator confirms the user's Claude Code session is on the 1M-context Opus variant. Multi-stratum sprints (foundation features, full-stack work) routinely exceed the default 200K Opus context during BUILD; truncation produces no `implementation-report.md` and forces a re-dispatch.

Print this prompt and wait for user input:

> This sprint can dispatch Generator BUILD for 30+ minutes on multi-stratum work. Confirm Claude Code was launched with `claude --model claude-opus-4-7[1m]` for the 1M-context variant. (Y to proceed / N to relaunch first.)

On `N`: print *"Relaunch Claude Code with: `claude --model claude-opus-4-7[1m]`, then re-run /harness:sprint"* and exit. On `Y`: continue to Step 0b. On any other input: re-prompt once, then proceed cautiously with a logged warning in `progress/changelog.md`.

Rationale: Claude Code does not currently expose `--model` to plugin scripts, so this is user-confirmation, not mechanical detection. See `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md` § 6.1 for why.

---

## 0b. Doctor — environment preflight (mandatory, blocking)
```

- [ ] **Step 3: Verify the rest of Step 0 (the bash invocation) is unchanged**

Read the lines immediately after your insertion. They should be:

```
Before dispatching any subagent, run the doctor:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```
```

If those lines are intact, the existing doctor procedure is preserved.

- [ ] **Step 4: Grep verify section structure**

Run: `grep -nE "^## 0" plugins/harness/commands/sprint.md`
Expected output (line numbers approximate):
```
N1:## 0a. 1M-context confirmation ...
N2:## 0b. Doctor — environment preflight ...
```

- [ ] **Step 5: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/sprint.md
git commit -m "[harness:refine] sprint.md: add 1M-context confirmation Step 0a"
```

---

## Task 3: Add 1M-context confirmation prompt to quick.md Step 0

**Files:**
- Modify: `plugins/harness/commands/quick.md` (insert before the existing `### 0. Doctor` section, around line 26)

- [ ] **Step 1: Locate the insertion point**

Open `plugins/harness/commands/quick.md`. Find the line `### 0. Doctor — environment preflight (mandatory, blocking)` (around line 26).

- [ ] **Step 2: Insert a softer pre-doctor section**

Replace the line `### 0. Doctor — environment preflight (mandatory, blocking)` with:

```markdown
### 0a. 1M-context confirmation (one-line check)

`/quick` is short by design, so the 1M-context need is softer than for `/sprint`. Print one line:

> Quick mode: confirm Claude Code is on `claude --model claude-opus-4-7[1m]` if this fix touches more than ~5 files. (Press Enter to proceed.)

Do not block. Continue to Step 0b on any input.

### 0b. Doctor — environment preflight (mandatory, blocking)
```

- [ ] **Step 3: Grep verify section structure**

Run: `grep -nE "^### 0" plugins/harness/commands/quick.md`
Expected:
```
N1:### 0a. 1M-context confirmation ...
N2:### 0b. Doctor — environment preflight ...
```

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/quick.md
git commit -m "[harness:refine] quick.md: add lightweight 1M-context note"
```

---

## Task 4: Promote 1M-context launch flag to README Quick Start

**Files:**
- Modify: `README.md` (insert a new "Recommended launch" subsection under Quick Start, around line 30)

- [ ] **Step 1: Locate the Quick Start section**

Open `README.md`. Find the line `## Quick start` (around line 26) and the subsection `### Install` (around line 28).

- [ ] **Step 2: Insert a new subsection BEFORE `### Install`**

Replace the line `### Install` with this block:

```markdown
### Recommended launch

For sprints touching multi-stratum work (foundation features, full-stack scaffolding, multi-adapter ingestion), launch Claude Code with the 1M-context Opus variant:

```
claude --model claude-opus-4-7[1m]
```

Without this flag, the agent frontmatter `model: inherit` resolves to the default 200K Opus context. A multi-stratum Generator BUILD dispatch can exceed 200K mid-work and truncate, producing no `implementation-report.md` and requiring re-dispatch. The 1M variant absorbs the same work without truncation.

`/harness:sprint` will print a confirmation prompt before dispatching subagents (see `commands/sprint.md` § 0a).

### Install
```

- [ ] **Step 3: Verify section ordering**

Run: `grep -nE "^### " README.md | head -20`
Expected (in order): `### Recommended launch`, `### Install`, `### Initialize a project`, `### Run your first sprint`.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add README.md
git commit -m "[harness:refine] README: promote 1M-context launch flag to Quick Start"
```

---

## Task 5: Remove story-files section from planner.md

**Files:**
- Modify: `plugins/harness/agents/planner.md` (remove the section at lines ~510-543)

- [ ] **Step 1: Locate the section to remove**

Open `plugins/harness/agents/planner.md`. Find the heading `## Story Files (FR-4) — per-FR build artifacts`. The section runs from that heading to (but not including) the next `## ` heading, which is `## Feature-size sanity check (Pass 2 gate)`.

- [ ] **Step 2: Remove the entire section**

Use the Edit tool. The `old_string` is the full section starting from `## Story Files (FR-4) — per-FR build artifacts` through the empty line just before `## Feature-size sanity check (Pass 2 gate)`. Set `new_string` to empty string (or a single newline to preserve heading separation).

The exact `old_string` to replace (verify by reading planner.md first):

```markdown
## Story Files (FR-4) — per-FR build artifacts

**After writing the aggregate `contract.md`, emit ONE story file per FR** to `.harness/features/NNN-name/stories/FR-NNN.md`. Use the template at `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/templates/features/story.md.txt`.

This is the BMAD V6 "Scrum Master" pattern adapted to BELCORT: the Generator's per-cycle reasoning quality improves when its context is scoped to a single FR rather than the full bundled contract. Stories are also the primary recovery anchor — `state.current_task: FR-005` resumes from `stories/FR-005.md`, not a full contract re-read.

**Authoring rules — INVARIANT: stories must NEVER drift from the aggregate contract:**

1. **Never paraphrase contract content.** ACs, ECs, FR text — quote verbatim. ID-reference everything.
2. **Persona section**: extract ONLY the personas referenced by this FR's parent UJ. Don't include all personas from the PRD — that's noise.
3. **Architectural slice**: ONLY the ADRs and stack rows that this FR depends on. The Generator reads the full architecture.md when needed; the story is the focused subset.
4. **Constitution principles**: list the SUBSET of the 17 that bind here, by §-number. The Generator reads constitution.md for the full text.
5. **Dev guidance**: leave the proposal/review-derived sections empty in the initial Pass 2 emission — they're populated during the negotiate phase. Mark them `{{populated by negotiate phase}}` placeholders.
6. **TDD anchor**: pick the most user-visible AC and write a single sentence of "first failing test asserts: ..." This is what drives the Generator's RED step.

The Evaluator (in EVALUATE mode) hash-checks each story's FR text against the aggregate contract. Drift = build fails. So treat stories as a strict assembly, not a rewrite.

**Folder layout for a feature with N FRs:**

```
.harness/features/NNN-name/
├── contract.md              # Aggregate (canonical for cross-FR concerns)
├── stories/
│   ├── FR-001.md            # Self-contained per-FR story
│   ├── FR-002.md
│   └── FR-NNN.md
├── proposal.md              # (created during negotiate)
├── review.md                # (created during negotiate)
└── ...
```

For epic-decomposed projects with multiple feature folders, each folder gets its own `stories/` populated by Pass 2.

**For now (Pass 2 initial emission)** — populate the FR / persona / architectural slice / constitution / TDD-anchor sections from your Pass 1 + Pass 2 outputs. Leave the "Dev guidance (from negotiation)" section as `{{populated by negotiate phase}}`. The negotiate phase backfills it.

```

(If the heading-trailing whitespace differs in your file, adjust the boundary; the goal is to delete the entire `## Story Files` section up to but not including the next `## ` heading.)

- [ ] **Step 3: Verify removal**

Run: `grep -n "## Story Files" plugins/harness/agents/planner.md`
Expected: no output (section removed).

Run: `grep -n "## Feature-size sanity check" plugins/harness/agents/planner.md`
Expected: one match (the next section is intact).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/planner.md
git commit -m "[harness:refine] planner: remove Story Files section"
```

---

## Task 6: Remove story rows from planner.md File Placement Summary

**Files:**
- Modify: `plugins/harness/agents/planner.md` (the File Placement Summary table around lines 579-589)

- [ ] **Step 1: Locate the File Placement Summary table**

Open `plugins/harness/agents/planner.md`. Find `## File Placement Summary`. The table that follows lists files including any story-related rows. (The current SKILL.md File Ownership Contract row for stories is at SKILL.md line 101; planner's File Placement Summary may not have a dedicated story row — verify on read.)

- [ ] **Step 2: Edit the table — remove any rows referencing `stories/`**

If a row exists like `| Per-FR stories | ... | ... | Planner Pass 2 ... |` or similar, remove that entire row. If no such row exists in planner.md (verify by `grep -n stories plugins/harness/agents/planner.md`), this task is no-op for planner.md and continues to Task 7.

- [ ] **Step 3: Verify**

Run: `grep -n "stories" plugins/harness/agents/planner.md`
Expected: no remaining matches (after Task 5 removed the main section, this confirms cleanup is complete).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/planner.md
git commit -m "[harness:refine] planner: drop residual story refs from File Placement Summary"
```

---

## Task 7: Update generator.md Phase 2 rule 2 (story → contract section)

**Files:**
- Modify: `plugins/harness/agents/generator.md` (Phase 2, rule 2 around line 392)

- [ ] **Step 1: Locate rule 2 in Phase 2**

Open `plugins/harness/agents/generator.md`. Find:

```
2. **Per-FR story read per cycle.** Before each FR's RED step, `cat .harness/features/${FEATURE}/stories/FR-NNN.md` — that's your canonical per-cycle context (FR text + ACs + ECs + personas + architectural slice + TDD anchor). If the story file doesn't exist (legacy feature pre-FR-4), fall back to the relevant section of the aggregate `contract.md`.
```

- [ ] **Step 2: Replace with contract-section-based wording**

Use the Edit tool. Replace the exact rule-2 block above with:

```
2. **Per-FR section read per cycle.** Before each FR's RED step, locate the FR's section in `.harness/features/${FEATURE}/contract.md` — grep on the FR ID (e.g., `grep -n "^### FR-003" contract.md`) and read that subsection. That's your canonical per-cycle context (FR text + ACs + ECs). The aggregate contract is the source of truth; per-FR scoping is your responsibility per cycle, not a separate file. (Per-FR story files were removed in v2.2 — the BMAD-V6 scoping assumption staled on Opus 4.7[1m]; the full contract is ~8k tokens, trivial to scope mentally.)
```

- [ ] **Step 3: Grep verify**

Run: `grep -n "stories/FR" plugins/harness/agents/generator.md`
Expected: no output.

Run: `grep -n "Per-FR section read per cycle" plugins/harness/agents/generator.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/generator.md
git commit -m "[harness:refine] generator: per-FR read targets contract section, not story file"
```

---

## Task 8: Confirm evaluator.md needs no change

**Files:**
- Read-only: `plugins/harness/agents/evaluator.md`

- [ ] **Step 1: Search for hash-check / story references**

Run: `grep -nEi "hash.?check|stories/|story\.md|drift = build fails" plugins/harness/agents/evaluator.md`
Expected: no matches (the hash-check is a Planner-asserted invariant with no enforcing Evaluator code, as documented in the spec § 4 Change #2).

- [ ] **Step 2: If matches appear, document them**

If any matches surface, the spec's premise is wrong — pause and update the spec before continuing. Otherwise this task is complete with no edits.

- [ ] **Step 3: Mark task done**

No commit needed (no file changes).

---

## Task 9: Drop story-line from sprint.md Generator BUILD dispatch

**Files:**
- Modify: `plugins/harness/commands/sprint.md` (the BUILD dispatch block around line 199-206)

- [ ] **Step 1: Locate the BUILD dispatch prompt**

Open `plugins/harness/commands/sprint.md`. Find the dispatch prompt block under `## 3. Build — dispatch Generator subagent`. The "Key files" list (around line 198-204) currently includes:

```
> - .harness/features/${FEATURE}/stories/*.md
```

- [ ] **Step 2: Remove that line and update the prose above**

Edit the dispatch prompt block. The current relevant prose is around line 196:

```
> Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). Read per-FR stories at .harness/features/${FEATURE}/stories/FR-NNN.md per cycle — that's your canonical per-cycle context.
```

Replace the above with:

```
> Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). For each FR's RED step, locate that FR's section in .harness/features/${FEATURE}/contract.md (grep by FR ID) — the contract is your per-cycle context.
```

Then in the "Key files" list immediately below, delete the line:
```
> - .harness/features/${FEATURE}/stories/*.md
```

- [ ] **Step 3: Verify**

Run: `grep -n "stories" plugins/harness/commands/sprint.md`
Expected: no output.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/sprint.md
git commit -m "[harness:refine] sprint.md: BUILD dispatch reads contract section, not stories"
```

---

## Task 10: Delete story.md.txt template

**Files:**
- Delete: `plugins/harness/templates/features/story.md.txt`

- [ ] **Step 1: Verify the file exists**

Run: `ls plugins/harness/templates/features/story.md.txt`
Expected: file listed.

- [ ] **Step 2: Delete the file**

Run: `rm plugins/harness/templates/features/story.md.txt`

- [ ] **Step 3: Verify deletion**

Run: `ls plugins/harness/templates/features/`
Expected: file no longer listed; remaining files include `contract.md.txt`, `proposal.md.txt`, `review.md.txt`, `eval-report.md.txt`, `implementation-report.md.txt`, `pause-questions.md.txt`.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add -u plugins/harness/templates/features/
git commit -m "[harness:refine] templates: delete story.md.txt (per-FR stories removed)"
```

---

## Task 11: Remove story rows from SKILL.md File Ownership Contract + Template Index

**Files:**
- Modify: `plugins/harness/skills/harness/SKILL.md` (File Ownership Contract row at line 101; Template Index row at line 436)

- [ ] **Step 1: Find the File Ownership Contract story row**

Open `plugins/harness/skills/harness/SKILL.md`. Find the table row beginning with:

```
| `features/NNN/stories/FR-NNN.md` (FR-4) | Planner Pass 2 (initial); Generator BUILD (refinements during build, e.g., implementation log entries) | Generator BUILD per TDD cycle (canonical per-cycle context); Evaluator EVALUATE (cross-checks story narrative against aggregate contract — drift = build fails) |
```

- [ ] **Step 2: Delete that table row**

Use the Edit tool. Delete the entire row (one line in the table). Preserve the surrounding rows.

- [ ] **Step 3: Find the Template Index story row**

Find the row in Template Index:

```
| Story | `features/story.md.txt` | Per-FR build story (BMAD V6 pattern) |
```

- [ ] **Step 4: Delete that row**

Edit-tool delete that single table row.

- [ ] **Step 5: Grep verify**

Run: `grep -n "story\|stories" plugins/harness/skills/harness/SKILL.md`
Expected: any remaining matches should be in unrelated prose (e.g., a passing reference like "user story" — manually inspect; if any reference to `stories/` filesystem path remains, remove it too).

- [ ] **Step 6: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/skills/harness/SKILL.md
git commit -m "[harness:refine] SKILL.md: drop story file rows from ownership + template tables"
```

---

## Task 12: Remove story refs from README.md Pipeline + Directory layout

**Files:**
- Modify: `README.md` (Pipeline section around line 100; Directory layout around line 290)

- [ ] **Step 1: Find Pipeline section reference**

Open `README.md`. Find the line in the canonical sprint flow describing per-FR reads or story files. Specifically check for any `stories/` reference around the `Generator (BUILD ...)` line (~line 98) and the implementation-report description (~line 100).

- [ ] **Step 2: Remove or rewrite story references**

Where the README mentions per-FR stories, replace with "per-FR section of contract.md". For example, if a line reads `Generator BUILD reads per-FR stories per TDD cycle`, change to `Generator BUILD reads the per-FR section of contract.md per TDD cycle`.

- [ ] **Step 3: Find Directory layout section**

Find `## Directory layout` (around line 271). Inside the tree diagram (line 287-301), look for:

```
│   ├── stories/FR-NNN.md      # Per-FR build context (Planner Pass 2)
```

- [ ] **Step 4: Delete that line from the tree**

Edit-tool delete that single line, preserving surrounding lines.

- [ ] **Step 5: Verify**

Run: `grep -n "stories" README.md`
Expected: no output.

- [ ] **Step 6: Commit (skip if not in a git repo)**

```bash
git add README.md
git commit -m "[harness:refine] README: drop story-file references"
```

---

## Task 13: Add State at pause section to pause-questions template

**Files:**
- Modify: `plugins/harness/templates/features/pause-questions.md.txt`

- [ ] **Step 1: Read the current template**

Run: `cat plugins/harness/templates/features/pause-questions.md.txt` (or read via Read tool).
Note its current structure (placeholders for question entries with default-if-unanswered).

- [ ] **Step 2: Insert the State at pause section**

At the top of the template (immediately after any frontmatter or first heading), insert:

```markdown
## State at pause (Generator-authored — authoritative for resume)

**Note for the resuming Generator:** if your dispatch prompt contains a `--- PAUSE STATE SNAPSHOT ---` block, prefer THESE values over `manifest.yaml → state.current_task`. The manifest may have been moved by interleaving commands between pause and re-dispatch; the snapshot reflects state at exact pause time.

- **Current FR (in flight):** FR-NNN
- **Last completed FR:** FR-MMM (or "none" if pause is pre-first-FR)
- **Last commit SHA:** <short hash, e.g., a1b2c3d>
- **Working tree status:** <clean | dirty: N staged, M unstaged, K untracked>
- **Pause timestamp (UTC):** <ISO 8601, e.g., 2026-04-28T14:23:11Z>
- **Pause reason category:** <product-intent ambiguity | constitution-vs-AC conflict | other>

---

```

- [ ] **Step 3: Verify**

Run: `grep -n "State at pause" plugins/harness/templates/features/pause-questions.md.txt`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/templates/features/pause-questions.md.txt
git commit -m "[harness:refine] pause-questions template: add State at pause snapshot section"
```

---

## Task 14: Update generator.md Phase 1.5 step 4 to require snapshot

**Files:**
- Modify: `plugins/harness/agents/generator.md` (Phase 1.5 step 4 around line 343)

- [ ] **Step 1: Locate Phase 1.5 step list**

Open `plugins/harness/agents/generator.md`. Find `**How to pause:**` (around line 339) and the numbered step list under it. Step 2 currently reads:

```
2. Write `.harness/features/${FEATURE}/pause-questions.md` using the template at `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/templates/features/pause-questions.md.txt`. Each Q MUST include a "default if unanswered" — committing to a fallback is what prevents pause-as-procrastination.
```

- [ ] **Step 2: Append snapshot requirement to step 2**

Edit step 2 to read:

```
2. Write `.harness/features/${FEATURE}/pause-questions.md` using the template at `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/templates/features/pause-questions.md.txt`. Each Q MUST include a "default if unanswered" — committing to a fallback is what prevents pause-as-procrastination. **MUST also fill the `## State at pause` section at the top** with current FR, last completed FR, last commit SHA (`git rev-parse --short HEAD`), working-tree status (`git status --porcelain | wc -l` summary), pause timestamp, and reason category. The snapshot is authoritative for the re-dispatched Generator's resume orientation — see Phase 1 rule 3.
```

- [ ] **Step 3: Verify**

Run: `grep -n "State at pause" plugins/harness/agents/generator.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/generator.md
git commit -m "[harness:refine] generator: pause writes State-at-pause snapshot"
```

---

## Task 15: Update sprint.md §3a to include snapshot in re-dispatch prompt

**Files:**
- Modify: `plugins/harness/commands/sprint.md` (Step 3a, around line 209-223)

- [ ] **Step 1: Locate the pause re-dispatch step**

Open `plugins/harness/commands/sprint.md`. Find Step 3a `## 3a. Pause check`. Step 5 in its loop reads:

```
5. Re-dispatch Generator BUILD via the Agent tool (same `subagent_type: harness:generator`, same BUILD-mode prompt from Step 3), with the collected answers appended to the end of the prompt under a `--- PAUSE ANSWERS ---` marker.
```

- [ ] **Step 2: Insert snapshot-passthrough requirement**

Replace step 5 with:

```
5. Re-dispatch Generator BUILD via the Agent tool (same `subagent_type: harness:generator`, same BUILD-mode prompt from Step 3), with TWO blocks appended to the end of the prompt: (a) the `## State at pause` section verbatim from `pause-questions.md` under a `--- PAUSE STATE SNAPSHOT (authoritative — prefer over manifest if they disagree) ---` marker, and (b) the collected answers under a `--- PAUSE ANSWERS ---` marker.
```

- [ ] **Step 3: Verify**

Run: `grep -n "PAUSE STATE SNAPSHOT" plugins/harness/commands/sprint.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/sprint.md
git commit -m "[harness:refine] sprint.md: re-dispatch pass-through of pause snapshot"
```

---

## Task 16: Update generator.md Phase 1 rule 3 — snapshot precedence

**Files:**
- Modify: `plugins/harness/agents/generator.md` (Phase 1, Step 3 around line 305-313)

- [ ] **Step 1: Locate the Orient phase rule 3**

Open `plugins/harness/agents/generator.md`. Find Phase 1 step 3 `**Check for mid-build recovery**`. The step lists rules including reading `state.current_task`, changelog, git log.

- [ ] **Step 2: Append snapshot precedence rule**

After the existing bullet `Run \`git log --oneline | grep "harness:build"\` — cross-check against actual commits` and BEFORE the next rule about Negotiated marker, insert this new bullet:

```
   - **If your dispatch prompt contains a `--- PAUSE STATE SNAPSHOT ---` block, prefer ITS values over `manifest.yaml → state.current_task`.** The snapshot reflects state at the exact pause moment; the manifest may have moved due to interleaving commands between pause and re-dispatch (e.g., `/harness:audit`, an unrelated `/harness:resume` from another worktree). If snapshot and manifest disagree, log the discrepancy in `.harness/progress/changelog.md` and proceed with the snapshot's `current_task`.
```

- [ ] **Step 3: Verify**

Run: `grep -n "PAUSE STATE SNAPSHOT" plugins/harness/agents/generator.md`
Expected: at least one match (this rule).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/generator.md
git commit -m "[harness:refine] generator: pause snapshot beats manifest on resume"
```

---

## Task 17: Refactor planner.md MODE ROUTING table (6 → 4 modes)

**Files:**
- Modify: `plugins/harness/agents/planner.md` (MODE ROUTING table around lines 47-54)

- [ ] **Step 1: Locate the MODE ROUTING table**

Open `plugins/harness/agents/planner.md`. Find the table:

```
| Mode | Purpose | Writes | Uses Context7? |
|------|---------|--------|----------------|
| **PLAN** (default, no marker) | ... |
| **CLARIFY-QUESTIONS** | ... |
| **CLARIFY-APPLY** | ... |
| **AMEND** | ... |
| **EDIT** | ... |
| **CONSTITUTION-AMEND** | ... |
```

- [ ] **Step 2: Replace with collapsed 4-mode table**

Use the Edit tool to replace the entire table with:

```markdown
| Mode | Purpose | Writes | Uses Context7? |
|------|---------|--------|----------------|
| **PLAN** (default, no marker) | Initial 2-pass planning: PRD+constitution → architecture+criteria+contract | spec/, evaluator/criteria.md, features/NNN-name/contract.md (draft), ROADMAP.md, manifest.yaml | Yes |
| **CLARIFY-QUESTIONS** | Identify ambiguities in the existing spec, produce structured questions for the user | features/NNN/clarifications.md (questions only) | No (spec already exists) |
| **EDIT** (covers `AMENDMENT` / `EDIT` / `CLARIFY ANSWERS` / `CONSTITUTION AMENDMENT` markers — read your dispatch prompt for the marker, the patches-file path, and any mode-specific constraints) | Translate user change-request into structured before→after spec patches | Path stated by orchestrator: `features/NNN/amend-patches.md`, `features/NNN/edit-patches.md`, `features/NNN/clarify-patches.md`, OR `.harness/constitution-amend-patches.md` per the dispatch marker | Yes (if change touches architecture or stack) |
| **REVALIDATE** | Static constitutional audit of a previously-shipped feature against an amended constitution | `.harness/.revalidation-<ts>/<FEATURE>.md` | No |
```

- [ ] **Step 3: Verify**

Run: `grep -nE "^\| \*\*(PLAN|CLARIFY-QUESTIONS|EDIT|REVALIDATE|AMEND|CLARIFY-APPLY|CONSTITUTION-AMEND)" plugins/harness/agents/planner.md`
Expected: 4 rows (PLAN, CLARIFY-QUESTIONS, EDIT, REVALIDATE). Old rows AMEND, CLARIFY-APPLY, CONSTITUTION-AMEND should be gone.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/planner.md
git commit -m "[harness:refine] planner: MODE ROUTING table 6 modes → 4 (EDIT collapses 4 markers)"
```

---

## Task 18: Replace 4 mode sections with unified MODE: EDIT in planner.md

**Files:**
- Modify: `plugins/harness/agents/planner.md` (replace `## MODE: AMEND` + `## MODE: EDIT` + `## MODE: CONSTITUTION-AMEND` + the CLARIFY-APPLY mode section with one unified MODE: EDIT)

- [ ] **Step 1: Identify the section boundaries**

Open `plugins/harness/agents/planner.md`. The post-PLAN modes start with `## MODE: CLARIFY-QUESTIONS` (around line 631, **stays unchanged**), then `## MODE: CLARIFY-APPLY` (replace), `## MODE: AMEND` (replace), `## MODE: EDIT` (replace), `## MODE: CONSTITUTION-AMEND` (replace). All four "replace" sections combine into one unified `## MODE: EDIT`.

- [ ] **Step 2: Delete the four sections**

Use the Edit tool four times (or one large replacement). Targets:
- Delete `## MODE: CLARIFY-APPLY` section through to (but not including) `## MODE: AMEND`.
- Delete `## MODE: AMEND` section through to `## MODE: EDIT`.
- Delete the OLD `## MODE: EDIT` section through to `## MODE: CONSTITUTION-AMEND`.
- Delete `## MODE: CONSTITUTION-AMEND` section through to end of file.

(Confirm there is no content after CONSTITUTION-AMEND that should be preserved — verify by reading planner.md to end. If the file ends with the CONSTITUTION-AMEND section, deletion is straightforward. If anything follows, preserve it.)

- [ ] **Step 3: Insert the unified MODE: EDIT section**

In place of the four deleted sections (i.e., immediately after `## MODE: CLARIFY-QUESTIONS` and its full content), insert:

````markdown
---

## MODE: EDIT (unified — covers AMENDMENT, EDIT, CLARIFY ANSWERS, CONSTITUTION AMENDMENT)

You produce structured before→after patches that the orchestrator applies mechanically. You NEVER apply patches yourself. The orchestrator chooses which user-facing command to invoke (`/harness:amend`, `/harness:edit`, `/harness:clarify`, `/harness:constitution-amend`); each authors a dispatch prompt with a marker and constraints. Your job is mode-agnostic: read the marker, read the constraints stated in the dispatch, produce surgical patches.

### Input

The dispatch prompt contains:
- A marker: `--- AMENDMENT REQUEST ---` | `--- EDIT REQUEST ---` | `--- CLARIFY ANSWERS ---` | `--- CONSTITUTION AMENDMENT ---`
- The user's change request (verbatim) immediately after the marker
- A `--- CONTEXT ---` block listing files to read via Read tool
- A `--- CONSTRAINTS ---` block stating mode-specific rules (which files you may patch, scope expectations, ID-preservation rules, etc.)
- A patches-file output path stated by the orchestrator

### Workflow (universal — applies to all four markers)

**Step 1: Interpret the request.** Parse what the user actually wants. If the request is genuinely vague, flag the relevant parts as `UNCLEAR` and continue with the parts you can patch. If the request is fundamentally a different shape than the marker (e.g., AMENDMENT marker but the change is multi-file cascade; or EDIT marker but the change is constitution-only), flag those parts as `OUT-OF-SCOPE` and recommend the correct command.

**Step 2: Check scope against marker constraints.** Read the `--- CONSTRAINTS ---` block in your dispatch. Common constraints by marker:

- `AMENDMENT REQUEST`: single-file scope expected; NEVER patch `spec/constitution.md` (route via OUT-OF-SCOPE → `/harness:constitution-amend`).
- `EDIT REQUEST`: multi-file cascade expected; NEVER patch `spec/constitution.md` (same routing); identify ALL affected files (resist under-scoping).
- `CLARIFY ANSWERS`: source is `clarifications.md` with user-filled answers; produce patches that translate answers to spec edits; touches only `spec/*` and `contract.md`.
- `CONSTITUTION AMENDMENT`: ONLY patches `spec/constitution.md`; preserve §-numbers (no renumbering on removals); reject non-testable principles (push back via UNCLEAR).

The exact constraints are authoritative as stated in your dispatch — if your dispatch differs from this summary, follow the dispatch.

**Step 3: Use Context7 if the change touches a framework, library, or API.** Verify the new choice supports the existing PRD's NFR metrics. Don't blindly apply a stack change that breaks NFR-NNN.

**Step 4: Draft surgical patches.** Each patch must:
- Target ONE file, ONE specific `old_string`
- Include enough surrounding context in `old_string` (≥3 lines) to be unique in the file
- Produce a `new_string` that is surgical — not a whole-section rewrite
- Preserve all IDs (FR-NNN, NFR-NNN, AC-NNN, EC-NNN, ADR-NNN, §-numbers — no renumbering)

**Step 5: Write the patches file.** The output path is stated in your dispatch. Common paths by marker: `AMENDMENT`→`.harness/features/${FEATURE}/amend-patches.md`; `EDIT`→`.harness/features/${FEATURE}/edit-patches.md` (or `.harness/edit-patches.md` if no current feature); `CLARIFY ANSWERS`→`.harness/features/${FEATURE}/clarify-patches.md`; `CONSTITUTION AMENDMENT`→`.harness/constitution-amend-patches.md` (top-level).

Universal patches-file structure (sections in order): `# [Title]` → `**Generated**`, `**Marker**`, `**Request**` frontmatter → `## Interpretation` (2-4 sentences) → `## Impact summary` (Modifies / Unclear / Out of scope) → `## Patches` (each as `### Patch N — title` with `**File**`, `**Location**`, fenced \`\`\`diff block of `-`/`+` lines (≥3 lines surrounding context, surgical), and `**Reasoning**` one-line) → `## Unclear items` (if any: title, original quote, why unclear, suggested resolution) → `## Out-of-scope items` (if any: title, original quote, why OOS, suggested command — `/clarify` / `/rewind planning` / `/constitution-amend` / `/retrospective`).

CONSTITUTION AMENDMENT marker also requires `## Conflict check` (None or "§X conflicts with proposed change because Y") and `## Impact assessment` (principles directly modified, principles indirectly affected, architecture sections potentially affected).

**Step 6: Stop.** Write the patches file. Do NOT apply, edit spec files, or run analysis. The orchestrator handles application + downstream commands.

### Anti-patterns (universal across all markers)

- **Silent ignoring of unclear parts**: every part of the user's request must produce a patch, an UNCLEAR entry, or an OUT-OF-SCOPE entry. No silent no-ops.
- **Whole-section rewrites**: surgical patches only. If you find yourself writing 50+ new lines, the request is bigger than the marker — flag as OUT-OF-SCOPE.
- **Touching constitution.md from non-CONSTITUTION markers**: NEVER. Route via OUT-OF-SCOPE → `/harness:constitution-amend`.
- **Renumbering IDs**: never. FR-001 stays FR-001, §1 stays §1, ADR-001 stays ADR-001.
- **Writing code**: not in any marker. Only patches files.
- **Touching files outside the marker's allowlist**: AMENDMENT touches spec/ + contract.md only; EDIT also touches init.sh + criteria.md; CLARIFY touches spec/ + contract.md; CONSTITUTION touches constitution.md only.

````

- [ ] **Step 4: Verify mode count and structure**

Run: `grep -nE "^## MODE:" plugins/harness/agents/planner.md`
Expected (in order): `## MODE: PLAN`, `## MODE: CLARIFY-QUESTIONS`, `## MODE: EDIT`, `## MODE: REVALIDATE`. If REVALIDATE was deleted by Step 2 mistakenly (it shouldn't be — REVALIDATE wasn't in the four-replace list), restore it from git history. If the original planner.md didn't have a separate REVALIDATE section (verify), the Evaluator handles REVALIDATE; planner.md just describes EDIT modes.

Actually re-check: in the original planner.md, only Planner modes exist (PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND — six). REVALIDATE is an EVALUATOR mode (evaluator.md), not a Planner mode. So after the collapse, Planner has THREE modes: PLAN, CLARIFY-QUESTIONS, EDIT. The MODE ROUTING table updated in Task 17 should reflect this — verify and adjust:

If Task 17's table includes REVALIDATE under Planner, that was an error. The correct Planner modes are PLAN, CLARIFY-QUESTIONS, EDIT. Re-edit Task 17's table to remove the REVALIDATE row (it belongs to evaluator.md, not planner.md).

- [ ] **Step 5: Re-verify Task 17 outcome**

Run: `grep -nE "^\| \*\*(PLAN|CLARIFY-QUESTIONS|EDIT|REVALIDATE)" plugins/harness/agents/planner.md`
Expected: 3 rows (PLAN, CLARIFY-QUESTIONS, EDIT). If REVALIDATE remains from Task 17, edit it out — REVALIDATE is an Evaluator mode.

- [ ] **Step 6: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/planner.md
git commit -m "[harness:refine] planner: 4 post-PLAN modes collapse to unified MODE: EDIT"
```

---

## Task 19: Update commands/amend.md dispatch prompt with inline AMENDMENT constraints

**Files:**
- Modify: `plugins/harness/commands/amend.md` (Step 2 dispatch prompt around lines 39-52)

- [ ] **Step 1: Locate the dispatch prompt block**

Open `plugins/harness/commands/amend.md`. Find Step 2 `### Step 2: Dispatch fresh Planner in AMEND mode` and the `> ` quoted prompt block.

- [ ] **Step 2: Replace dispatch prompt with constraint-inlined version**

Replace the existing dispatch `prompt` block (the lines starting with `> You are being dispatched in AMEND mode`) with:

```markdown
> You are being dispatched in EDIT mode (see your system prompt's MODE ROUTING table — EDIT is the unified post-PLAN spec-patches mode).
>
> --- AMENDMENT REQUEST ---
> $ARGUMENTS
>
> --- CONTEXT ---
> Read via Read tool: .harness/spec/prd.md, .harness/spec/architecture.md, .harness/spec/constitution.md (read-only — NEVER patch from this marker), .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md.
>
> --- CONSTRAINTS (AMENDMENT-specific) ---
> - Single file scope expected; if cascade needed (≥2 files), flag relevant parts as OUT-OF-SCOPE and recommend /harness:edit.
> - NEVER patch spec/constitution.md (route via OUT-OF-SCOPE → /harness:constitution-amend).
> - Preserve all IDs (FR-NNN, NFR-NNN, AC-NNN, EC-NNN, §-numbers).
> - Output: .harness/features/${FEATURE}/amend-patches.md per the universal MODE: EDIT patches template.
>
> Do NOT apply patches — the orchestrator applies after user confirmation.
```

- [ ] **Step 3: Verify**

Run: `grep -n "AMENDMENT REQUEST" plugins/harness/commands/amend.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/amend.md
git commit -m "[harness:refine] amend.md: dispatch via unified EDIT mode with AMENDMENT marker"
```

---

## Task 20: Update commands/edit.md dispatch prompt with inline EDIT constraints

**Files:**
- Modify: `plugins/harness/commands/edit.md` (Step 2 dispatch prompt around lines 36-54)

- [ ] **Step 1: Locate the dispatch prompt**

Open `plugins/harness/commands/edit.md`. Find Step 2 `### Step 2: Dispatch fresh Planner in EDIT mode`.

- [ ] **Step 2: Replace with marker-inlined version**

Replace the existing dispatch `prompt` block (lines starting with `> You are being dispatched in EDIT mode`) with:

```markdown
> You are being dispatched in EDIT mode (see your system prompt's MODE ROUTING table — EDIT is the unified post-PLAN spec-patches mode).
>
> --- EDIT REQUEST ---
> $ARGUMENTS
>
> --- CONTEXT ---
> Read via Read tool: .harness/spec/prd.md, .harness/spec/architecture.md, .harness/spec/constitution.md (read-only — NEVER patch from this marker), .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md, and .harness/init.sh if relevant.
>
> --- CONSTRAINTS (EDIT-specific) ---
> - Multi-file cascade expected; identify ALL affected files (resist under-scoping). Stack swap → architecture.md + init.sh + relevant NFR section + sometimes evaluator/criteria.md.
> - NEVER patch spec/constitution.md (route via OUT-OF-SCOPE → /harness:constitution-amend).
> - Preserve all IDs.
> - Use Context7 to verify any new framework/library API and that NFRs remain satisfiable.
> - Output: .harness/features/${FEATURE}/edit-patches.md, OR .harness/edit-patches.md (top-level) if state.current_feature is empty. Group patches by file.
>
> Do NOT apply patches.
```

- [ ] **Step 3: Verify**

Run: `grep -n "EDIT REQUEST" plugins/harness/commands/edit.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/edit.md
git commit -m "[harness:refine] edit.md: dispatch via unified EDIT mode with EDIT marker"
```

---

## Task 21: Update commands/clarify.md CLARIFY-APPLY half to use EDIT mode marker

**Files:**
- Modify: `plugins/harness/commands/clarify.md` (Step 4 dispatch around lines 66-74)

- [ ] **Step 1: Locate Step 4 dispatch**

Open `plugins/harness/commands/clarify.md`. Step 2's CLARIFY-QUESTIONS dispatch stays unchanged (CLARIFY-QUESTIONS is still its own Planner mode). Step 4's CLARIFY-APPLY dispatch needs updating.

- [ ] **Step 2: Replace Step 4 dispatch prompt**

Replace the existing dispatch block (lines starting with `> You are being dispatched in CLARIFY-APPLY mode`) with:

```markdown
> You are being dispatched in EDIT mode (see your system prompt's MODE ROUTING table — EDIT is the unified post-PLAN spec-patches mode).
>
> --- CLARIFY ANSWERS ---
> Source: .harness/features/${FEATURE}/clarifications.md (the user has filled in **User answer:** under each question)
>
> --- CONTEXT ---
> Read via Read tool: .harness/features/${FEATURE}/clarifications.md (with answers), .harness/spec/prd.md, .harness/spec/architecture.md, .harness/features/${FEATURE}/contract.md.
>
> --- CONSTRAINTS (CLARIFY ANSWERS-specific) ---
> - Source of truth is the user-answered clarifications file; translate each answered question into surgical patches.
> - Skip any question with a 'pending' / 'skipped' answer (no patch).
> - Touches only spec/* + features/${FEATURE}/contract.md (do not touch evaluator/, progress/, manifest, init.sh, constitution).
> - Preserve all IDs.
> - Output: .harness/features/${FEATURE}/clarify-patches.md per the universal MODE: EDIT patches template.
>
> Do NOT apply patches.
```

- [ ] **Step 3: Verify**

Run: `grep -n "CLARIFY ANSWERS" plugins/harness/commands/clarify.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/clarify.md
git commit -m "[harness:refine] clarify.md: CLARIFY-APPLY dispatched as unified EDIT mode (CLARIFY ANSWERS marker)"
```

---

## Task 22: Update commands/constitution-amend.md dispatch with inline CONSTITUTION constraints

**Files:**
- Modify: `plugins/harness/commands/constitution-amend.md` (Step 3 dispatch around lines 36-50)

- [ ] **Step 1: Locate Step 3 dispatch**

Open `plugins/harness/commands/constitution-amend.md`. Find Step 3 `### Step 3: Dispatch Planner in CONSTITUTION-AMEND mode`.

- [ ] **Step 2: Replace dispatch with marker-inlined version**

Replace the existing dispatch `prompt` block with:

```markdown
> You are being dispatched in EDIT mode (see your system prompt's MODE ROUTING table — EDIT is the unified post-PLAN spec-patches mode).
>
> --- CONSTITUTION AMENDMENT ---
> $ARGUMENTS
>
> --- CONTEXT ---
> Read via Read tool: .harness/spec/constitution.md, .harness/spec/prd.md, .harness/spec/architecture.md. Sample (orchestrator may include up to 10 most recent): completed features' contract.md files.
>
> --- CONSTRAINTS (CONSTITUTION AMENDMENT-specific) ---
> - ONLY patch spec/constitution.md. NEVER touch any other spec file from this marker (cascade implications go in OUT-OF-SCOPE → /harness:edit after this command lands).
> - Preserve §-numbers strictly. Adding: append at next §-number. Changing: in-place. Removing: delete the §-block but DO NOT renumber subsequent §-numbers (deleted § becomes a permanent gap; past contracts and ADRs reference §-numbers).
> - Reject non-testable principles. If the amendment translates to a vibe ("code should be clean" / "follow best practices"), flag as UNCLEAR and push back.
> - Use Context7 if the principle references a framework or library standard.
> - Include a `## Conflict check` section: enumerate any principle conflicts with the proposed change.
> - Include a `## Impact assessment` section: which §-numbers modified directly + indirectly + which architecture sections potentially affected.
> - Output: .harness/constitution-amend-patches.md (top-level, global) per the universal MODE: EDIT patches template + the CONSTITUTION-specific extras above.
>
> Do NOT apply patches.
```

- [ ] **Step 3: Verify**

Run: `grep -n "CONSTITUTION AMENDMENT" plugins/harness/commands/constitution-amend.md`
Expected: at least one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/constitution-amend.md
git commit -m "[harness:refine] constitution-amend.md: dispatch via unified EDIT mode with CONSTITUTION AMENDMENT marker"
```

---

## Task 23: Update SKILL.md mode references

**Files:**
- Modify: `plugins/harness/skills/harness/SKILL.md` (Subagent Isolation Protocol § Dispatch mechanism, around lines 52-58)

- [ ] **Step 1: Locate the mode list**

Open `plugins/harness/skills/harness/SKILL.md`. Find the "Dispatch mechanism" subsection (around line 52). It currently lists:

```
- `harness:planner` — Planner agent (PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND modes)
- `harness:generator` — Generator agent (NEGOTIATE, FINALIZE-CONTRACT, BUILD modes)
- `harness:evaluator` — Evaluator agent (REVIEW-PROPOSAL, EVALUATE, REVALIDATE modes)
```

- [ ] **Step 2: Update the planner line**

Replace the planner line with:

```
- `harness:planner` — Planner agent (PLAN, CLARIFY-QUESTIONS, EDIT modes — EDIT covers AMENDMENT / EDIT / CLARIFY ANSWERS / CONSTITUTION AMENDMENT markers, see agents/planner.md § MODE: EDIT)
```

(Generator and Evaluator lines unchanged.)

- [ ] **Step 3: Search for any other AMEND/CLARIFY-APPLY/CONSTITUTION-AMEND mode references**

Run: `grep -nE "(MODE: AMEND|MODE: CLARIFY-APPLY|MODE: CONSTITUTION-AMEND|CLARIFY-APPLY mode|AMEND mode|CONSTITUTION-AMEND mode)" plugins/harness/skills/harness/SKILL.md`

For each match, decide: is it referencing the new unified EDIT mode, or stale documentation? Replace stale references with "EDIT mode (with the appropriate marker)".

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/skills/harness/SKILL.md
git commit -m "[harness:refine] SKILL.md: update mode references for unified Planner EDIT"
```

---

## Task 24: Move /negotiate 3-round-cap rationale into sprint.md, then delete commands/negotiate.md

**Files:**
- Modify: `plugins/harness/commands/sprint.md` (insert escalation prose into §2c around line 156)
- Delete: `plugins/harness/commands/negotiate.md`

- [ ] **Step 1: Read commands/negotiate.md § Procedure step 4**

Open `plugins/harness/commands/negotiate.md`. Find step 4 ("If no agreement after 3 rounds: Escalate to human"). Note the exact prose for blocker / why-stuck / decision-asked-of-you.

- [ ] **Step 2: Locate the 3-round cap in sprint.md §2c**

Open `plugins/harness/commands/sprint.md`. Find the "Iterate" paragraph in §2c (around line 156): `Max 3 rounds (per \`config.max_negotiation_rounds\` in manifest). If no agreement at round 3, escalate to human.`

- [ ] **Step 3: Expand sprint.md §2c with the full escalation procedure**

Replace the "If no agreement at round 3, escalate to human." line with:

```markdown
Max 3 rounds (per `config.max_negotiation_rounds` in manifest). By round 3, continued disagreement signals an unclear upstream contract (the Planner's what/why is ambiguous), not a negotiation problem. More agent rounds won't resolve a values or clarity gap; human judgment will.

**If no agreement after 3 rounds, escalate to human with this structure:**

- **The blocker** (one sentence): what Generator wants vs what Evaluator wants, at the narrowest point of disagreement.
- **Why it's stuck** (one sentence): which upstream artifact is ambiguous — usually the draft contract, sometimes the architecture or constitution.
- **The decision being asked of you**: pick (a) force Generator's proposal as-is, (b) force Evaluator's asks as-is, (c) rewrite the draft contract to resolve the ambiguity (run `/harness:amend` or `/harness:edit`), (d) abandon the feature.
```

- [ ] **Step 4: Delete commands/negotiate.md**

Run: `rm plugins/harness/commands/negotiate.md`

- [ ] **Step 5: Verify**

Run: `ls plugins/harness/commands/negotiate.md 2>&1`
Expected: error / file not found.

Run: `grep -n "force Generator's proposal" plugins/harness/commands/sprint.md`
Expected: one match (the escalation prose moved into sprint.md).

- [ ] **Step 6: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/commands/sprint.md plugins/harness/commands/negotiate.md
git commit -m "[harness:refine] drop /harness:negotiate standalone; inline escalation in sprint.md §2c"
```

---

## Task 25: Remove /harness:negotiate from README.md commands table

**Files:**
- Modify: `README.md` (Phase management table around line 148)

- [ ] **Step 1: Locate the negotiate row**

Open `README.md`. Find the table row beginning with:

```
| `/harness:negotiate` | Standalone Generator↔Evaluator negotiation (normally auto-invoked by sprint). |
```

(Or similar wording. Located in the "Phase management + lifecycle" subsection.)

- [ ] **Step 2: Delete that row**

Edit-tool delete the entire row, preserving surrounding rows.

- [ ] **Step 3: Update the "17 commands" header**

Find: `## The 17 commands` (around line 108). Change to `## The 16 commands`.

- [ ] **Step 4: Verify**

Run: `grep -n "harness:negotiate" README.md`
Expected: no output.

Run: `grep -n "## The 16 commands" README.md`
Expected: one match.

- [ ] **Step 5: Commit (skip if not in a git repo)**

```bash
git add README.md
git commit -m "[harness:refine] README: drop /harness:negotiate row, 17→16 commands"
```

---

## Task 26: Remove /harness:negotiate from SKILL.md commands table

**Files:**
- Modify: `plugins/harness/skills/harness/SKILL.md` (Commands table around line 35)

- [ ] **Step 1: Locate the negotiate row in the Commands table**

Open `plugins/harness/skills/harness/SKILL.md`. Find:

```
| `/harness:negotiate` | [commands/negotiate.md](../../commands/negotiate.md) | Generator ↔ Evaluator contract negotiation (pre-build) |
```

- [ ] **Step 2: Delete that row**

Edit-tool delete that single row.

- [ ] **Step 3: Verify**

Run: `grep -n "harness:negotiate" plugins/harness/skills/harness/SKILL.md`
Expected: no output (or only references to the auto-invoked negotiate procedure inline in sprint.md, not as a standalone command).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/skills/harness/SKILL.md
git commit -m "[harness:refine] SKILL.md: drop /harness:negotiate row from Commands table"
```

---

## Task 27: Reword planner.md feature-size gate rationale (soft-only with 1M-context note)

**Files:**
- Modify: `plugins/harness/agents/planner.md` (the rationale paragraph at the END of `## Feature-size sanity check (Pass 2 gate)`, around line 567)

- [ ] **Step 1: Locate the rationale paragraph**

Open `plugins/harness/agents/planner.md`. Find the paragraph beginning `**Why this gate exists:**` at the end of the `## Feature-size sanity check` section.

- [ ] **Step 2: Replace with the v2.2 wording**

Replace the existing `**Why this gate exists:**` paragraph with:

```markdown
**Why this gate exists:** historically (Opus 4.5/4.6, default 200K context), a Generator dispatched to build a 20-FR foundation feature would exhaust its Claude Code budget mid-work and hard-stop with an uncommitted working tree. Recovery is possible (see generator.md pre-TDD scaffolding checkpoint rule + sprint.md § 3a pause snapshot), but preventing oversize at the Planner stage was the cheaper fix on those models.

**On Opus 4.7[1m] this gate is advisory only** — the larger context window largely absorbs multi-stratum work, and the framework owner has chosen to trust the model. The signals here remain useful as a "hey, this is huge, are you sure?" prompt for the human at the analyze gate, but the human is the decider. There is no orchestrator code path that hard-blocks on these signals; if there ever is, it's a regression — see ADR-NNN in `progress/decisions.md` (v2.2 entry).

**Operational dependency:** this soft-only stance assumes the user has launched Claude Code with `claude --model claude-opus-4-7[1m]`. Without the [1m] flag, the agent frontmatter `model: inherit` resolves to the default 200K Opus context, and the conditions that drove the historical hard-gate version return. The doctor and sprint.md Step 0a confirm this at session start.
```

- [ ] **Step 3: Verify**

Run: `grep -n "Why this gate exists" plugins/harness/agents/planner.md`
Expected: one match.

Run: `grep -n "On Opus 4.7\[1m\] this gate is advisory only" plugins/harness/agents/planner.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add plugins/harness/agents/planner.md
git commit -m "[harness:refine] planner: feature-size gate rationale reworded for v2.2 (advisory + 1M-context dep)"
```

---

## Task 28: Add v2.2.0 entry to CHANGELOG.md

**Files:**
- Modify: `CHANGELOG.md` (insert new top entry)

- [ ] **Step 1: Read the current top of CHANGELOG.md**

Run: `head -50 CHANGELOG.md` or read via Read tool.

- [ ] **Step 2: Insert the v2.2.0 entry at the top (below the title)**

Insert below the file title (and any existing top-of-file headers, before the v2.1.x entries):

```markdown
## v2.2.0 — 2026-04-28 — Stale-assumption pruning + operational hardening

Continues the v2.0 minimalist refactor logic, applied to four post-v2.0 stale-assumption targets plus two operational hardening items. Single-PR atomic merge. ~300 LoC net reduction. No user-facing command surface change beyond removing one redundant front door.

### Removed

- **Per-FR story files** (`features/NNN/stories/FR-NNN.md`) — the BMAD-V6 scoping assumption that drove inclusion in v2.0 has staled on Opus 4.7[1m]. The full contract is ~8k tokens out of 1M; per-cycle scoping is trivial without a separate file. The "drift = build fails" hash-check was Planner-asserted and Evaluator-unimplemented (v2.x inconsistency). Generator BUILD now reads the per-FR section of `contract.md` directly via grep on FR-IDs. Existing projects with `stories/` folders: ignored from v2.2 forward; safe to delete manually.
- **`/harness:negotiate` standalone command** — 16 commands → 15. Procedure (Generator NEGOTIATE → Evaluator REVIEW-PROPOSAL → Generator FINALIZE-CONTRACT, ≤3 rounds) is canonical in `commands/sprint.md` § 2c; recovery from `negotiating` phase uses `/harness:resume`; restart uses `/harness:rewind negotiating`. Standalone command was almost never user-invoked.
- **Planner mode duplication** — 6 modes → 3. CLARIFY-APPLY + AMEND + EDIT + CONSTITUTION-AMEND collapsed into one unified `MODE: EDIT` that reads a marker from the dispatch prompt (`AMENDMENT REQUEST` / `EDIT REQUEST` / `CLARIFY ANSWERS` / `CONSTITUTION AMENDMENT`). Mode-specific constraints (which files may be patched, scope expectations, etc.) now live in each command file's dispatch prompt — single source of truth per constraint. Net Planner LoC: -400. User-facing commands `/harness:amend`, `/harness:edit`, `/harness:clarify`, `/harness:constitution-amend` unchanged.

### Added

- **1M-context confirmation banner** in `doctor.sh` (advisory; mechanical detection deferred until Claude Code exposes `--model` to plugin scripts).
- **1M-context confirmation prompt** in `commands/sprint.md` Step 0a (blocking) and `commands/quick.md` Step 0a (non-blocking one-liner).
- **`### Recommended launch` section** in README.md Quick Start, promoting `claude --model claude-opus-4-7[1m]` from buried-in-Status to top-level.
- **`## State at pause` section** in `pause-questions.md` template — Generator authors a state snapshot (current FR, last completed FR, last commit SHA, working tree status, timestamp) at pause time. Snapshot is authoritative for the re-dispatched Generator's resume orientation, beating `manifest.yaml` if they disagree (manifest can move via interleaving commands).

### Changed

- **Planner feature-size sanity check** (planner.md § Feature-size sanity check) is reworded to be advisory-only with an explicit operational dependency note: trust-the-model stance assumes 1M-context launch.
- `commands/sprint.md` § 3a pause re-dispatch now passes the State-at-pause snapshot through to the resumed Generator under a `--- PAUSE STATE SNAPSHOT (authoritative — prefer over manifest if they disagree) ---` marker.
- `agents/generator.md` Phase 1 rule 3 prefers the snapshot over manifest for resume orientation.

### Migration

- **Existing projects with `.harness/features/NNN/stories/` folders**: harmless. Generator and Evaluator no longer read them. Safe to delete the folder; no migration script is provided. The hash-check that would have failed on drift was never enforced in code, so no spurious failures will occur from leaving them in place.
- **Muscle-memory `/harness:negotiate` users**: the command now returns "command not found". Use `/harness:resume` (when in `negotiating` phase) or `/harness:rewind negotiating` (to restart from finalized contract).

### Spec & ADR

- Design spec: `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md`
- Implementation plan: `docs/superpowers/plans/2026-04-28-belcort-audit-and-refine.md`
- ADR pending: append to `progress/decisions.md` after merge documenting the v2.0-spec contradiction (story files removed; v2.0 preserved them) and the trust-the-model stance.

```

- [ ] **Step 3: Verify**

Run: `grep -n "v2.2.0" CHANGELOG.md`
Expected: at least one match (the new entry).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add CHANGELOG.md
git commit -m "[harness:refine] CHANGELOG: v2.2.0 entry"
```

---

## Task 29: Update ROADMAP.md (v2.2 shipped + v3 watch list)

**Files:**
- Modify: `ROADMAP.md`

- [ ] **Step 1: Read the current ROADMAP**

Run: `cat ROADMAP.md` or read via Read tool.

- [ ] **Step 2: Add v2.2 to shipped + update v3 watch**

Append to the "Shipped" section (or top if shipped section doesn't exist):

```markdown
## v2.2.0 — Shipped 2026-04-28

- Per-FR story files removed (stale BMAD-V6 assumption on Opus 4.7[1m])
- `/harness:negotiate` standalone removed (procedure preserved in sprint.md § 2c)
- Planner internal mode collapse (6 → 3; user-facing commands unchanged)
- Generator pause `State at pause` snapshot for resume safety
- Doctor + sprint 1M-context confirmation banner
- Soft-only Planner feature-size gate (advisory; trust the model)
```

Update the "v3 watch list" section (or create one) to include:

```markdown
## v3 watch list

Items deferred from the v2.2 audit that may become load-bearing on future model regressions or revealed-by-use:

- **Stratum-splitting BUILD into N dispatches.** Premature on confirmed-1M sessions. Revisit only if truncation recurs after Change #1 (Task 1-4 of v2.2) lands.
- **Pause-mechanic full unification** (Planner AskUserQuestions vs Generator file-based). Asymmetry is correct on current models; revisit if Planner sessions ever grow long enough to need file-based pauses.
- **Mechanical 1M-context detection from doctor.sh.** Requires Claude Code to expose `--model` to plugin scripts. Track upstream and promote the v2.2 advisory banner to a real check when available.
- **Audit-family merge** (`/analyze`, `/validate`, `/audit`, `/retrospective`, `REVALIDATE`). Each answers a distinct question per `SKILL.md` § Audit Commands. Revisit only if telemetry shows users running them in fixed pairs.
- **Story-file deprecation grace period** (one-shot warning if existing project has `stories/` folder). Not worth the code; CHANGELOG migration note is sufficient.
```

- [ ] **Step 3: Verify**

Run: `grep -n "v2.2.0 — Shipped" ROADMAP.md`
Expected: one match.

Run: `grep -n "v3 watch list" ROADMAP.md`
Expected: one match.

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add ROADMAP.md
git commit -m "[harness:refine] ROADMAP: v2.2 shipped + v3 watch list"
```

---

## Task 30: Update docs/anthropic-alignment.md with v2.2 rows

**Files:**
- Modify: `docs/anthropic-alignment.md` (Decision map + Version provenance)

- [ ] **Step 1: Add v2.2 rows to the Decision map**

Open `docs/anthropic-alignment.md`. The Decision map table (around line 12) lists per-decision Anthropic citations. Append these rows at the end of the table:

```markdown
| Stale-assumption pruning of per-FR story files (v2.2) | Rajasekaran 2026 | *"Every component in a harness encodes an assumption… those assumptions are worth stress testing… can quickly go stale as models improve."* The BMAD-V6 per-FR scoping assumption staled on Opus 4.7[1m]; story files removed. |
| Soft-only Planner feature-size gate (v2.2) | Rajasekaran 2026 | *"With Opus 4.6 I dropped context resets from this harness entirely."* Same logic applied to the historical hard-gate intent: trust the more-capable model; signal-only at the Planner stage. |
| Planner mode collapse (v2.2) | Rajasekaran 2026 | *"Find the simplest solution possible, and only increase complexity when needed."* Single source of truth per mode constraint via dispatch-prompt markers. |
| Generator pause-time state snapshot (v2.2) | Rajasekaran 2026 | *"Use structured files to carry previous agent state and next steps across context boundaries."* File-based state at the boundary, not state inferred from a globally-mutable file. |
| `/harness:negotiate` standalone removed (v2.2) | Rajasekaran 2026 | *"Stripping away pieces that are no longer load-bearing."* Auto-invoked + recoverable via `/harness:resume`; standalone front door was unused. |
| 1M-context confirmation banner (v2.2) | Rajasekaran 2026 (operational reliability) | If the active model isn't the [1m] variant, the conditions for context-budget truncation re-emerge. Confirmation gate, not mechanical detection (Claude Code doesn't expose `--model` to plugins). |
```

- [ ] **Step 2: Add v2.2 entry to Version provenance**

Append to the Version provenance section at the end of the file:

```markdown
- v2.2 — stale-assumption pruning + operational hardening: per-FR story files removed (Anthropic *"every component encodes an assumption that may go stale"*), Planner mode collapse (4 post-PLAN modes → unified EDIT, single source of truth via dispatch markers), `/harness:negotiate` standalone removed, Generator pause snapshot (file-based state at boundaries), 1M-context confirmation banner (operational), soft-only Planner feature-size gate. Trust-the-model stance documented as conditional on 1M-context launch. ~300 LoC reduction. Full plan: `docs/superpowers/plans/2026-04-28-belcort-audit-and-refine.md`. Full spec: `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md`.
```

- [ ] **Step 3: Verify**

Run: `grep -n "v2.2" docs/anthropic-alignment.md`
Expected: at least 2 matches (decision map row + provenance entry).

- [ ] **Step 4: Commit (skip if not in a git repo)**

```bash
git add docs/anthropic-alignment.md
git commit -m "[harness:refine] anthropic-alignment: v2.2 rows + provenance entry"
```

---

## Task 31: End-to-end verification

**Files:** None modified — this is a verification pass.

- [ ] **Step 1: Run doctor.sh**

Run: `bash plugins/harness/scripts/doctor.sh`
Expected: full report including the new "1M context window (Opus 4.7[1m])" advisory banner.

- [ ] **Step 2: Verify all story-file references are gone**

Run: `grep -rEn "stories/FR|story\.md\.txt|\.harness/features/[^/]+/stories/" plugins/ README.md docs/ 2>/dev/null`
Expected: no output (story file references fully removed).

- [ ] **Step 3: Verify all /harness:negotiate references are gone**

Run: `grep -rEn "harness:negotiate" plugins/ README.md docs/ 2>/dev/null`
Expected: no output (or only inside this CHANGELOG/migration documentation referring to the removal — manually inspect any matches).

- [ ] **Step 4: Verify Planner mode count**

Run: `grep -nE "^## MODE: " plugins/harness/agents/planner.md`
Expected: exactly 3 lines: `## MODE: PLAN`, `## MODE: CLARIFY-QUESTIONS`, `## MODE: EDIT`.

- [ ] **Step 5: Verify command file dispatch markers**

Run: `grep -nE "(--- AMENDMENT REQUEST ---|--- EDIT REQUEST ---|--- CLARIFY ANSWERS ---|--- CONSTITUTION AMENDMENT ---)" plugins/harness/commands/`
Expected: 4 matches across `amend.md`, `edit.md`, `clarify.md`, `constitution-amend.md` (one marker per command file).

- [ ] **Step 6: Verify pause-questions template has snapshot section**

Run: `grep -n "State at pause" plugins/harness/templates/features/pause-questions.md.txt`
Expected: one match.

- [ ] **Step 7: Verify CHANGELOG + ROADMAP + alignment doc updates**

Run: `grep -n "v2.2.0" CHANGELOG.md ROADMAP.md docs/anthropic-alignment.md`
Expected: at least one match per file.

- [ ] **Step 8: Verify command count**

Run: `ls plugins/harness/commands/*.md | wc -l`
Expected: 16 (was 17 before; `negotiate.md` removed).

- [ ] **Step 9: If a Claude Code session is available, smoke-test the harness**

Manual test (run in a Claude Code session inside a fresh test project):
1. Run `/harness:setup` in a fresh dir.
2. Run `/harness:sprint "small CRUD: a single FR with 2 ACs"`.
3. Confirm 1M-context confirmation prompt appears (Step 0a).
4. Confirm Planner produces spec WITHOUT a `stories/` folder.
5. Confirm Generator BUILD dispatch prompt does NOT reference `stories/`.
6. Confirm overall pipeline still completes (PASS at evaluation).

Expected: all confirmations pass; no stories/ folder created; pipeline completes without errors.

- [ ] **Step 10: Final commit (skip if not in a git repo)**

If any minor doc tweaks surfaced during verification, commit them now:

```bash
git add -A
git commit -m "[harness:refine] v2.2 verification fixes"
```

---

## Self-review (per superpowers:writing-plans)

**Spec coverage check.** Each spec change has at least one task:

- Spec Change #1 (Doctor 1M-context + README banner) → Tasks 1, 2, 3, 4
- Spec Change #2 (Drop story files) → Tasks 5, 6, 7, 8, 9, 10, 11, 12
- Spec Change #3 (Generator pause snapshot) → Tasks 13, 14, 15, 16
- Spec Change #4 (Planner mode collapse) → Tasks 17, 18, 19, 20, 21, 22, 23
- Spec Change #5 (Drop /harness:negotiate) → Tasks 24, 25, 26
- Spec Change #6 (Soft-gate clarification) → Task 27
- Cross-cutting (CHANGELOG, ROADMAP, alignment doc, E2E) → Tasks 28, 29, 30, 31

No gaps.

**Placeholder scan.** Each step shows actual content (replacement strings, grep commands with expected output, exact file paths). One known soft spot: Task 18 inserts a large Markdown block; the executing engineer must confirm there is nothing after the deleted CONSTITUTION-AMEND section that should be preserved (the task explicitly notes this — re-read planner.md to end before proceeding).

**Type consistency.** Marker names used consistently across tasks: `AMENDMENT REQUEST`, `EDIT REQUEST`, `CLARIFY ANSWERS`, `CONSTITUTION AMENDMENT`. Patches-file paths consistent: `amend-patches.md`, `edit-patches.md`, `clarify-patches.md`, `constitution-amend-patches.md`. Mode names consistent: PLAN, CLARIFY-QUESTIONS, EDIT (Planner); REVIEW-PROPOSAL, EVALUATE, REVALIDATE (Evaluator); NEGOTIATE, FINALIZE-CONTRACT, BUILD (Generator).

**Sequencing safety.** Task 17 (table refactor) precedes Task 18 (full mode-section replacement) precedes Tasks 19-22 (per-command dispatch prompt updates). Task 17's table mistakenly listed REVALIDATE under Planner; Task 18 includes a corrective step (Step 4-5) that verifies and re-edits Task 17's output if needed. Task 24 must precede Tasks 25-26 (negotiate.md deletion before its references are removed).

Self-review passes.
