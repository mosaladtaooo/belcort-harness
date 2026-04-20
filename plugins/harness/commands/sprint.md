---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1–4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → Planner → human gate → Generator → Evaluator → retry loop → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

## Procedure

### 0a. BRAINSTORM CHECK — Ambiguity gate (opt-in)

Before touching the environment, scan the prompt for vagueness signals:

- Prompt length ≤ 2 sentences AND no concrete verbs (build, implement, create, fix, migrate, refactor)
- Uncertainty words present: `maybe`, `not sure`, `I think`, `figure out`, `help me decide`
- Multiple plausible interpretations (e.g., "a dashboard" — for what, for whom, with what data?)
- Unfamiliar domain with no prior features in `manifest.yaml`

If ANY signal hits, suggest:

> "Your prompt looks like it could benefit from `/harness:brainstorm` first — it surfaces silent assumptions before the Planner locks in a direction. Options:
>   1. Run /harness:brainstorm \"$ARGUMENTS\" first (recommended)
>   2. Proceed to /harness:sprint anyway — Planner will use AskUserQuestions to clarify
>   3. Cancel
>
> Choose 1, 2, or 3:"

On (1): run `/harness:brainstorm` (see [brainstorm.md](brainstorm.md)) and stop this sprint invocation. The user re-runs `/harness:sprint` after brainstorming.
On (2): continue to step 0 (doctor).
On (3): exit silently.

If NO signal hits, skip this step silently and continue to doctor.

**If `.harness/brainstorm-current.md` already exists** (user ran brainstorm previously), include its contents as additional Planner context in step 1, then move the file to the feature folder after it's created.

### 0. DOCTOR — Environment preflight (mandatory, blocking)

Before dispatching any subagent, run the doctor. This catches missing MCPs (playwright, context7), wrong Node versions, missing plugins — everything that would silently break the pipeline mid-sprint.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

- If `DOCTOR_EXIT = 0`: environment ready, proceed to step 1.
- If `DOCTOR_EXIT = 1`: CRITICAL failure. Show the doctor's report (including the suggested fixes) to the user and **STOP**. Do not dispatch the Planner. Tell the user: "Fix the items above, then re-run `/harness:sprint \"$ARGUMENTS\"`." This is a hard gate — do not try to work around it.
- If `DOCTOR_EXIT = 2`: doctor itself errored (malformed manifest or unreadable config). Treat as a hard stop. Show the doctor's stderr output and tell the user: "The doctor could not complete its own checks (exit 2). Run `bash \"${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh\"` manually, investigate the error, and re-run the sprint once the doctor itself can run clean." Do NOT attempt to interpret partial doctor output — exit 2 means we can't trust it.

See [doctor.md](doctor.md) for what it checks and why.

### 1. PLAN — Dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD (product requirements) + constitution (what & why)
- Pass 2: Architecture + criteria + contract (how — informed by Pass 1)

This ordering matters: architecture decisions shape how work decomposes, so PRD comes first.

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

```bash
# If a brainstorm file exists, append it as additional context
BRAINSTORM_CONTEXT=""
if [ -f ".harness/brainstorm-current.md" ]; then
  BRAINSTORM_CONTEXT="
--- BRAINSTORM CONTEXT (from earlier /harness:brainstorm session) ---
$(cat .harness/brainstorm-current.md)"
fi

# shellcheck disable=SC2086  # MODEL_FLAG is intentionally unquoted to allow empty expansion
MODEL_FLAG=$(resolve_model_flag planner)

# Subagent observability — Trustworthy Agents §opacity-at-scale (FR-1).
# The Planner runs before the feature folder exists, so it emits to a top-level
# path; we move it into the feature folder after Planner finishes.
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
PLANNER_PROGRESS=".harness/_progress-planner.jsonl"
start_progress_poller "$PLANNER_PROGRESS"
trap "stop_progress_poller '$PLANNER_PROGRESS'" EXIT

# Dispatch pattern (v1.5.0+): the agent role goes in the system prompt via
# --append-system-prompt-file, NOT inlined into the user message. The inline
# pattern used in v1.4 and earlier produced empty output on Claude Code 2.1+.
# The user message carries the phase framing + user request; it MUST NOT start
# with `---` (Claude CLI parses leading `-` as an option), so we prefix with
# prose even when the phase marker follows.
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in PLAN mode (see your system prompt for the full role and 2-pass procedure).

Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, per-FR story files under features/NNN-name/stories/, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the Generator. Run your 16-point self-validation before exiting and report the pass count.

User request:
$ARGUMENTS${BRAINSTORM_CONTEXT}" \
  ${MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"

stop_progress_poller "$PLANNER_PROGRESS"
trap - EXIT

# After Planner creates the feature folder, move brainstorm + planner progress into it
if [ -f ".harness/brainstorm-current.md" ]; then
  FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
  if [ -n "$FEATURE" ] && [ -d ".harness/features/${FEATURE}" ]; then
    mv ".harness/brainstorm-current.md" ".harness/features/${FEATURE}/brainstorm.md"
  fi
fi
FEATURE=${FEATURE:-$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')}
if [ -f "$PLANNER_PROGRESS" ] && [ -n "$FEATURE" ] && [ -d ".harness/features/${FEATURE}" ]; then
  mv "$PLANNER_PROGRESS" ".harness/features/${FEATURE}/_progress-planner.jsonl"
fi
```

Wait for Planner to finish. Verify all files exist in `.harness/`. The Planner runs its own 16-point self-validation before completing.

### 2. HUMAN GATE — Present summary, wait for approval

```
═══════════════════════════════
  Harness — Planning Complete
═══════════════════════════════
Project: [name]
Complexity: [small/medium/large] ([N] FRs)
Stack: [framework + db]

PRD:
  Personas: [N] | Journeys: [N] | FRs: [N] | NFRs: [N]
  Elicitation: [technique used]
  Risks: [N] identified

Architecture:
  Components: [N] | All FRs traced: ✓
  Context7 verified: ✓

Contract:
  Strategy: [single pass / epic decomposition]
  Deliverables: [N] | Test criteria: [N] ACs

Files:
  ✓ spec/prd.md
  ✓ spec/constitution.md
  ✓ spec/architecture.md
  ✓ evaluator/criteria.md
  ✓ features/NNN-name/contract.md
  ✓ init.sh

Planner self-validation: [16/16 passed]

Review the spec files and:
  • say "approved"           → proceed to negotiate + build
  • run /harness:clarify     → surface ambiguities, answer, auto-patch
  • run /harness:amend "<X>" → make a specific tweak (coming in separate PR)
  • run /harness:edit "<X>"  → targeted spec edit
  • run /harness:rewind planning → fundamentally re-plan
═══════════════════════════════
```

**DO NOT proceed until the user explicitly approves.** This is the only mandatory human gate.

If the user wants to make changes, route them through a command — do NOT edit spec files from this orchestrator's own context. See [SKILL.md § File Ownership Contract](../skills/harness/SKILL.md) for why.

**Auto-suggest `/harness:clarify` if:** the Planner's self-validation report mentions 3+ silent defaults, or the user's approval text contains uncertainty words ("maybe", "not sure", "I guess", "probably"). Surfacing ambiguities now is cheaper than correcting a misaligned build later.

### 2b. ANALYZE — Cross-artifact consistency check (automatic)

Run the `/harness:analyze` procedure (see [analyze.md](analyze.md)). CRITICAL findings halt the pipeline until resolved. Warnings pass through.

Update `manifest.yaml`: phase → "negotiating"

### 2c. NEGOTIATE — Generator and Evaluator agree on sprint contract (automatic)

Anthropic's original harness inserts a negotiation step here because the product spec is intentionally high-level. This step bridges the gap between user stories and testable implementation — the Generator proposes HOW to build, the Evaluator reviews whether it's the right approach, they iterate until agreement.

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

# Subagent observability (FR-1) — shared across all three negotiate dispatches
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
PROGRESS_FILE=".harness/features/${FEATURE}/_progress.jsonl"

# Round 1: Generator writes implementation proposal
GEN_MODEL_FLAG=$(resolve_model_flag generator)
start_progress_poller "$PROGRESS_FILE"
trap "stop_progress_poller '$PROGRESS_FILE'" EXIT
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in NEGOTIATE mode (see your system prompt's MODE ROUTING table).

Do NOT write code in this mode. Read the draft contract, architecture direction, constitution, and criteria (all present in .harness/ — use the Read tool). Then write your implementation proposal to .harness/features/${FEATURE}/proposal.md covering:
- Component/module breakdown
- File and directory structure
- Data model shapes
- API endpoint design (if applicable)
- Test strategy for each AC

Exit when proposal.md is written. Do not start the negotiation loop yourself — the orchestrator dispatches the Evaluator review separately." \
  ${GEN_MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/generator.md" \
  --allowedTools "Read,Write,mcp__context7"
stop_progress_poller "$PROGRESS_FILE"

# Round 2: Evaluator reviews the proposal
EVAL_MODEL_FLAG=$(resolve_model_flag evaluator)
start_progress_poller "$PROGRESS_FILE"
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in REVIEW-PROPOSAL mode (see your system prompt's MODE ROUTING table).

You are reviewing a Generator's implementation proposal BEFORE any code is written. Do NOT run Playwright — there is no app yet.

Read these via the Read tool:
- .harness/evaluator/criteria.md — grading rubric you'll apply later
- .harness/features/${FEATURE}/contract.md — draft contract
- .harness/features/${FEATURE}/proposal.md — Generator's proposal

Check:
- Does each deliverable have a clear HOW?
- Are the test strategies adequate for each AC?
- Will the Generator be able to verify completion against the criteria?
- Any gaps, ambiguities, or risky shortcuts?

Write your review to .harness/features/${FEATURE}/review.md with a VERDICT line (agreed | needs-revision), specific items requiring revision, and any new ACs the proposal revealed." \
  ${EVAL_MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/evaluator.md" \
  --allowedTools "Read,Write"
stop_progress_poller "$PROGRESS_FILE"

# Loop: if review says needs-revision, Generator revises proposal (append round to same files)
# Max 3 negotiation rounds. If no agreement, escalate to human.

# Round N (final): Generator writes the negotiated contract
start_progress_poller "$PROGRESS_FILE"
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in FINALIZE-CONTRACT mode (see your system prompt's MODE ROUTING table).

The proposal and review have converged. Read via Read tool:
- .harness/features/${FEATURE}/contract.md — draft
- .harness/features/${FEATURE}/proposal.md — your proposal
- .harness/features/${FEATURE}/review.md — Evaluator review (must say 'agreed')

Merge them into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (include the **Negotiated**: marker per your mode spec). This is the source of truth for the Build phase." \
  ${GEN_MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/generator.md" \
  --allowedTools "Read,Write"
stop_progress_poller "$PROGRESS_FILE"
trap - EXIT
```

See [negotiate.md](negotiate.md) for the standalone variant and anti-patterns to watch for.

Update `manifest.yaml`: phase → "building"

### 3. BUILD — Dispatch Generator subagent

```bash
# Create worktree
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true

# Assemble context — FR-4: prefer per-FR stories over the full aggregate contract
# when the Generator has stories/ available. The aggregate contract is still
# included for cross-FR concerns (build order, definition of done) but the
# Generator BUILD reads the current story per cycle for focused per-FR context.
STORIES_DIR=".harness/features/${FEATURE}/stories"
STORY_INDEX=""
if [ -d "$STORIES_DIR" ]; then
  STORY_INDEX="
--- STORY INDEX (FR-4 per-FR build artifacts; Generator reads each per cycle) ---
$(ls -1 ${STORIES_DIR}/FR-*.md 2>/dev/null | sed 's|^|- |')
"
fi

CONTEXT="$(cat .harness/spec/constitution.md)
$(cat .harness/spec/architecture.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/evaluator/criteria.md)${STORY_INDEX}"

# Add evaluator feedback if retry
[ -f ".harness/features/${FEATURE}/eval-report.md" ] && \
  CONTEXT="$CONTEXT
--- EVALUATOR FEEDBACK (FIX THESE) ---
$(cat .harness/features/${FEATURE}/eval-report.md)"

BUILD_MODEL_FLAG=$(resolve_model_flag generator)

# Subagent observability (FR-1) — BUILD is the longest dispatch; heartbeat matters most here
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
PROGRESS_FILE=".harness/features/${FEATURE}/_progress.jsonl"
start_progress_poller "$PROGRESS_FILE"
trap "stop_progress_poller '$PROGRESS_FILE'" EXIT

CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in BUILD mode (see your system prompt's MODE ROUTING table).

Implement the negotiated contract via TDD (RED → GREEN → REFACTOR → COMMIT). Read per-FR stories at .harness/features/${FEATURE}/stories/FR-NNN.md via Read tool as you work — that's your canonical per-cycle context.

Project-specific context follows. If any section references files you also want to read via the Read tool, do that — don't rely solely on the inline snapshot:
$CONTEXT" \
  ${BUILD_MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/generator.md" \
  --allowedTools "Read,Write,Bash,mcp__context7"

stop_progress_poller "$PROGRESS_FILE"
trap - EXIT
```

### 3a. PAUSE CHECK (FR-3) — Generator may have requested user input mid-build

Trustworthy Agents §calibrated uncertainty: agents should pause when faced with ambiguity rather than guess silently. The Generator's BUILD §Pause Protocol writes `pause-questions.md` when it hits a genuine ambiguity it cannot reasonably guess past. Detect, surface, accept answers, re-dispatch.

```bash
PAUSE_FILE=".harness/features/${FEATURE}/pause-questions.md"
PAUSE_COUNT=0
MAX_PAUSES=3   # per-sprint limit; escalate to /harness:rewind negotiating after this

while [ -f "$PAUSE_FILE" ]; do
  PAUSE_COUNT=$((PAUSE_COUNT + 1))
  if [ "$PAUSE_COUNT" -gt "$MAX_PAUSES" ]; then
    echo "❌ Generator has paused $PAUSE_COUNT times on this sprint."
    echo "   Likely the contract is under-determined. Recommend:"
    echo "     /harness:rewind negotiating   # re-spec the affected FR(s)"
    echo "   Then re-run /harness:sprint."
    exit 1
  fi

  # Surface the questions to the user
  echo ""
  echo "═══════════════════════════════"
  echo "  Harness — Generator requested clarification (pause #$PAUSE_COUNT)"
  echo "═══════════════════════════════"
  cat "$PAUSE_FILE"
  echo ""
  echo "Answer each question by appending under '## User answers' in $PAUSE_FILE,"
  echo "OR type your answers here and the orchestrator will append them."
  echo "For each Q: provide your answer, OR 'accept default' (uses Generator's"
  echo "fallback), OR 'skip' (Generator marks the FR partial)."
  echo ""

  # Wait for the user to provide answers (orchestrator-side: prompt for each Q,
  # write into the file under '## User answers'). Implementation detail of how
  # the orchestrator collects input is left to the chat UI — file format is the
  # contract. Once answers are written, increment calibration metric.

  # Increment agent_checkins in manifest (calibration_metrics tracking).
  # Earlier version tried to scope to the calibration_metrics block via in_cm
  # tracking — but the "exit-block" condition triggered on user_interrupts
  # (inside the block, but matched the indented-line regex), so the increment
  # never fired. Simpler portable awk: match the unique field name directly.
  # $2 is the second whitespace-separated token (the current count); +1 promotes it.
  if [ -f ".harness/manifest.yaml" ]; then
    awk '/^[[:space:]]*agent_checkins:/ {sub(/[0-9]+/, $2+1)} {print}' \
      .harness/manifest.yaml > .harness/manifest.yaml.new \
      && mv .harness/manifest.yaml.new .harness/manifest.yaml
  fi

  # Archive this pause for history (in case of re-pause on the same FR)
  mkdir -p ".harness/features/${FEATURE}/paused-history"
  cp "$PAUSE_FILE" ".harness/features/${FEATURE}/paused-history/pause-${PAUSE_COUNT}-$(date +%Y%m%d%H%M%S).md"

  # Re-dispatch Generator with pause file as additional BUILD context
  RESUMED_CONTEXT="$CONTEXT
--- PAUSE ANSWERS (resume from state.current_task with these resolutions) ---
$(cat $PAUSE_FILE)"

  source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
  start_progress_poller "$PROGRESS_FILE"
  trap "stop_progress_poller '$PROGRESS_FILE'" EXIT

  CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in BUILD mode — RESUMING a paused build.

Read the PAUSE ANSWERS section in the context below (and the file at .harness/features/${FEATURE}/pause-questions.md for full history). Those resolve the questions you wrote earlier. Pick up from state.current_task in manifest.yaml. Do NOT re-pause on the same questions — if a DIFFERENT ambiguity arises later, that's a new pause.

Project-specific context follows:
$RESUMED_CONTEXT" \
    ${BUILD_MODEL_FLAG} \
    --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/generator.md" \
    --allowedTools "Read,Write,Bash,mcp__context7"

  stop_progress_poller "$PROGRESS_FILE"
  trap - EXIT

  # Remove the now-resolved pause file. If Generator paused again, it wrote
  # a fresh pause-questions.md and this loop catches it on the next iteration.
  rm -f "$PAUSE_FILE"
done

if [ "$PAUSE_COUNT" -gt 0 ]; then
  echo "✓ Resumed after $PAUSE_COUNT pause(s). Pause history archived to features/${FEATURE}/paused-history/."
fi
```

Update `manifest.yaml`: phase → "evaluating"

### 4. EVALUATE — Dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

```bash
EVAL_MODEL_FLAG=$(resolve_model_flag evaluator)

# Subagent observability (FR-1) — EVALUATE often runs many minutes (Playwright + edge cases)
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/progress-poller.sh"
PROGRESS_FILE=".harness/features/${FEATURE}/_progress.jsonl"
start_progress_poller "$PROGRESS_FILE"
trap "stop_progress_poller '$PROGRESS_FILE'" EXIT

CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in EVALUATE mode (see your system prompt's MODE ROUTING table).

Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan, and write your verdict to .harness/features/${FEATURE}/eval-report.md.

Read these via Read tool BEFORE scoring (calibration is mandatory):
- .harness/evaluator/examples.md — few-shot scoring anchors
- .harness/spec/evaluator-notes.md (if exists) — project-specific notes
- .harness/evaluator/criteria.md
- .harness/features/${FEATURE}/implementation-report.md (Generator's handoff)
- .harness/features/${FEATURE}/contract.md (final negotiated)
- .harness/features/${FEATURE}/proposal.md + review.md (WHY behind ACs)
- .harness/spec/constitution.md
- .harness/spec/prd.md

Then exercise the running app via Playwright MCP. The app is expected at whatever URL its init.sh starts on." \
  ${EVAL_MODEL_FLAG} \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/evaluator.md" \
  --allowedTools "Read,Write,Bash,mcp__playwright"

stop_progress_poller "$PROGRESS_FILE"
trap - EXIT
```

The Evaluator receives the Generator's implementation report as a starting point — but verifies every claim independently.

### 5. RESULT — Read evaluator report and decide

```bash
REPORT=".harness/features/${FEATURE}/eval-report.md"
RESULT=$(head -5 "$REPORT" | grep -oE "PASS|FAIL")
RETRIES=$(grep "retry_count" .harness/manifest.yaml | grep -oE "[0-9]+")
MAX=$(grep "max_retries" .harness/manifest.yaml | grep -oE "[0-9]+")
```

**If PASS:**

#### 5a-pre. TUNING CHECK — Capture human-Evaluator divergence (automatic)

Anthropic's harness research documented that "the tuning loop was to read the evaluator's logs, find examples where its judgment diverged from mine, and update the QAs prompt to solve for those issues. It took several rounds of this development loop before the evaluator was grading in a way that I found reasonable."

This step implements that loop. After every evaluation (PASS or FAIL), the orchestrator surfaces the Evaluator's judgment to the human and asks whether they agree.

**Procedure:**

1. Read the full `eval-report.md` and summarize the Evaluator's key judgments:

```
═══════════════════════════════
  Harness — Evaluator Judgment Check
═══════════════════════════════
Verdict: PASS (or FAIL)
Scores: F:X/10  Q:X/10  T:X/10  P:X/10

Critical findings: [N]
  C1: [title — one line]
  C2: [title — one line]

Major findings: [N]
  M1: [title — one line]

Do you agree with this evaluation?
  1. Agree — proceed
  2. Disagree — flag specific divergences
  3. Partial — some findings right, some wrong
═══════════════════════════════
```

2. If user says **Agree**: skip to RETROSPECTIVE. No tuning log entry.

3. If user says **Disagree** or **Partial**: enter the divergence capture flow:

```
Which judgments diverged from yours?
  - Score too high / too low? (which criterion?)
  - Finding missed entirely?
  - Finding severity wrong? (e.g., called Major but should be Critical)
  - Finding fabricated / overclaimed?
  - Scope confusion (Evaluator graded something out of contract)?
  - Other (describe)
```

4. For each divergence, capture:
   - **What Evaluator said** (quote from eval-report.md)
   - **What you think it should have been**
   - **Why** (your reasoning in one sentence)

5. Append the structured entry to `.harness/evaluator/tuning-log.md` using the template in that file's header.

6. Ask the user: "Should this become a calibration example for future Evaluators?"
   - If yes → append a properly structured example to `.harness/evaluator/examples.md` under the relevant criterion section
   - If no → log stays in tuning-log.md as raw record, no example created
   - If "project-specific" (applies only to this product, not a generic pattern) → append to `.harness/spec/evaluator-notes.md`

7. Check for pattern emergence: run `grep -c "Divergence category: Leniency" .harness/evaluator/tuning-log.md` (and similar for other categories). If any category has ≥3 entries, tell the user:
   > "Pattern detected: [category] divergence has happened [N] times. Consider running `/harness:tune-evaluator` to review and possibly update the Evaluator prompt."

8. Proceed to RETROSPECTIVE regardless of outcome (tuning never blocks the pipeline — it accumulates in the background).

**If FAIL and retries < max (before going to retry):**

Also run this tuning check, but with reversed framing: "Do you agree the Evaluator should have failed this?" Same divergence capture flow. Because false FAILs (Evaluator too strict) are also divergences worth logging.

#### 5a. RETROSPECTIVE — Drift analysis (MANDATORY automatic)

Before merging, run the `/harness:retrospective` procedure (see [retrospective.md](retrospective.md)). This step is **MANDATORY** — not opt-in, not skippable, runs every PASS. Reconcile what was built vs what was spec'd. Write `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update `spec/prd.md`, `spec/architecture.md`, log ADRs in `progress/decisions.md`.

**Failure handling:** if the retrospective itself fails (Evaluator subagent errors, malformed output, etc.), do NOT silently skip. Block the merge, write a stub `retrospective.md` noting the failure, and ask the user how to proceed (retry, manual retrospective, or merge-without-retro with explicit `--no-retro` confirmation). Skipping retrospective silently is how spec drift becomes invisible — which is exactly what `/harness:retrospective` exists to prevent.

#### 5b. MERGE

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [contract summary]"
git worktree remove .worktrees/current 2>/dev/null
# Update ROADMAP.md: move feature to "✅ Shipped"
# Update manifest: features.completed += [${FEATURE}], features.in_progress = "", state.phase → "complete", retry_count → 0

# Record calibration snapshot (Trustworthy Agents Art.2 §calibration).
# Count this sprint's interrupts (course corrections from user) vs check-ins
# (agents that asked clarifying questions). The audit command surfaces the
# running ratio. Anomaly signals:
#   - interrupts >> check-ins → agents are too silent, missing ambiguities
#   - check-ins >> interrupts on trivial tasks → agents are over-cautious
# Intended increment points:
#   - agent_checkins: +1 each time any subagent invoked AskUserQuestions or
#     ran /harness:clarify mid-sprint
#   - user_interrupts: +1 each time the user ran /harness:amend, /harness:steer,
#     /harness:edit, or typed a course-correction in a human gate
# If you track these during the sprint (or can reconstruct from changelog.md),
# update them here before writing last_sprint_ratio.
#   last_sprint_ratio: "<user_interrupts>:<agent_checkins>" (e.g., "2:5")
```

Print scores and completion message.

**If FAIL and retries < max:**
```bash
# Increment retry_count in manifest
# Update manifest: phase → "building"
```
Print failing scores + critical findings. Auto-loop back to step 3 (BUILD).

**If FAIL and retries ≥ max:**
Present to human with options:
1. Force merge with known issues
2. Manually fix and re-run `/harness:resume` (picks up from evaluating phase)
3. Increase max_retries
4. Abandon

## Constraints

- Evaluator MUST be a separate subagent from Generator (GAN-inspired isolation)
- All artifacts go in `.harness/features/NNN-name/`
- Atomic commits: `[harness:<phase>] <description>`
- Subagents are workers, not managers — they never re-invoke the harness pipeline
