---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1–4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: Planner → human gate → Generator → Evaluator → retry loop → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

## Procedure

### 1. PLAN — Dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD (product requirements) + constitution (what & why)
- Pass 2: Architecture + criteria + contract (how — informed by Pass 1)

This ordering matters: architecture decisions shape how work decomposes, so PRD comes first.

```bash
claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/planner.md)

--- USER REQUEST ---
$ARGUMENTS" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

Wait for Planner to finish. Verify all files exist in `.harness/`. The Planner runs its own 13-point self-validation before completing.

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

Planner self-validation: [13/13 passed]

Review the spec files and say "approved"
to start building, or tell me what to change.
═══════════════════════════════
```

**DO NOT proceed until the user explicitly approves.** This is the only mandatory human gate.

### 2b. ANALYZE — Cross-artifact consistency check (automatic)

Run the `/harness:analyze` procedure (see [analyze.md](analyze.md)). CRITICAL findings halt the pipeline until resolved. Warnings pass through.

Update `manifest.yaml`: phase → "negotiating"

### 2c. NEGOTIATE — Generator and Evaluator agree on sprint contract (automatic)

Anthropic's original harness inserts a negotiation step here because the product spec is intentionally high-level. This step bridges the gap between user stories and testable implementation — the Generator proposes HOW to build, the Evaluator reviews whether it's the right approach, they iterate until agreement.

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

# Round 1: Generator writes implementation proposal
claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/generator.md)
--- MODE: NEGOTIATE ---
You are in NEGOTIATE mode, not BUILD mode. Do NOT write code yet.
Read the draft contract, architecture direction, and constitution.
Propose HOW you will implement each deliverable:
- Component/module breakdown
- File and directory structure
- Data model shapes
- API endpoint design (if applicable)
- Test strategy for each AC

Write your proposal to .harness/features/${FEATURE}/proposal.md and stop.
--- CONTEXT ---
$(cat .harness/spec/constitution.md)
$(cat .harness/spec/architecture.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/evaluator/criteria.md)" \
  --allowedTools "Read,Write,mcp__context7"

# Round 2: Evaluator reviews the proposal
claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/evaluator.md)
--- MODE: REVIEW-PROPOSAL ---
You are reviewing a Generator's implementation proposal BEFORE any code is written.
Do NOT run Playwright. There is no app yet.
Read the proposal and check:
- Does each deliverable have a clear HOW?
- Are the test strategies adequate for each AC?
- Will the Generator be able to verify completion against the criteria?
- Any gaps, ambiguities, or risky shortcuts?

Write your review to .harness/features/${FEATURE}/review.md with:
- VERDICT: agreed | needs-revision
- Specific items requiring revision (if any)
- New ACs you want added (if proposal revealed testing gaps)
--- CONTEXT ---
$(cat .harness/evaluator/criteria.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/features/${FEATURE}/proposal.md)" \
  --allowedTools "Read,Write"

# Loop: if review says needs-revision, Generator revises proposal (append round to same files)
# Max 3 negotiation rounds. If no agreement, escalate to human.

# Round N (final): Generator writes the negotiated contract
claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/generator.md)
--- MODE: FINALIZE-CONTRACT ---
The proposal and review have converged. Write the final negotiated contract.
Merge the original draft contract + your proposal + any ACs added by Evaluator review.
Overwrite .harness/features/${FEATURE}/contract.md with the final version.
This is the source of truth for the Build phase.
--- CONTEXT ---
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/features/${FEATURE}/proposal.md)
$(cat .harness/features/${FEATURE}/review.md)" \
  --allowedTools "Read,Write"
```

See [negotiate.md](negotiate.md) for the standalone variant and anti-patterns to watch for.

Update `manifest.yaml`: phase → "building"

### 3. BUILD — Dispatch Generator subagent

```bash
# Create worktree
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true

# Assemble context
CONTEXT="$(cat .harness/spec/constitution.md)
$(cat .harness/spec/architecture.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/evaluator/criteria.md)"

# Add evaluator feedback if retry
[ -f ".harness/features/${FEATURE}/eval-report.md" ] && \
  CONTEXT="$CONTEXT
--- EVALUATOR FEEDBACK (FIX THESE) ---
$(cat .harness/features/${FEATURE}/eval-report.md)"

claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/generator.md)
--- PROJECT CONTEXT ---
$CONTEXT" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

Update `manifest.yaml`: phase → "evaluating"

### 4. EVALUATE — Dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

```bash
claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/evaluator.md)
--- EVALUATION CONTEXT ---
$(cat .harness/evaluator/criteria.md)
$(cat .harness/features/${FEATURE}/implementation-report.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/spec/constitution.md)" \
  --allowedTools "Read,Write,Bash,mcp__playwright"
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

#### 5a. RETROSPECTIVE — Drift analysis (automatic)

Before merging, run the `/harness:retrospective` procedure (see [retrospective.md](retrospective.md)). Reconcile what was built vs what was spec'd. Write `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update `spec/prd.md`, `spec/architecture.md`, log ADRs in `progress/decisions.md`.

#### 5b. MERGE

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [contract summary]"
git worktree remove .worktrees/current 2>/dev/null
# Update ROADMAP.md: move feature to "✅ Shipped"
# Update manifest: features.completed += [${FEATURE}], features.in_progress = "", state.phase → "complete", retry_count → 0
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
