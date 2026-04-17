# BELCORT Harness Engine

## Activation

This skill activates when:
- The SessionStart hook detects `.harness/manifest.yaml` in the current directory (automatic)
- User runs `/harness:sprint "<prompt>"`, `/harness:quick "<prompt>"`, or `/harness:resume`
- User describes building something and you assess ≥1% chance the harness would help (the 1% rule from CLAUDE.md)

**If you were dispatched as a subagent** (your prompt contains `<SUBAGENT-CONTEXT>`), **SKIP this skill entirely.** Subagents do their specific job — they don't orchestrate.

## Commands

### `/harness:sprint "<prompt>"` — Full Pipeline

Runs: Planner → human gate → Generator → Evaluator → retry loop → merge.

**Procedure:**

**1. PLAN** — Dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD (product requirements) + constitution (what & why)
- Pass 2: Architecture + criteria + contract (how — informed by Pass 1)

This ordering matters: architecture decisions shape how work decomposes, so PRD comes first.

```bash
claude -p "$(cat ~/.claude/agents/planner.md)

--- USER REQUEST ---
[user's prompt]" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

Wait for Planner to finish. Verify all files exist in `.harness/`. The Planner runs its own 13-point self-validation before completing.

**2. HUMAN GATE** — Present summary, wait for approval

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

**2b. ANALYZE** — Cross-artifact consistency check (automatic)

[...保留原有 analyze 描述不变...]

Update `manifest.yaml`: phase → "negotiating"

**2c. NEGOTIATE** — Generator and Evaluator agree on sprint contract (automatic)

Anthropic's original harness inserts a negotiation step here because the product 
spec is intentionally high-level. This step bridges the gap between user stories 
and testable implementation — the Generator proposes HOW to build, the Evaluator 
reviews whether it's the right approach, they iterate until agreement.

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

# Round 1: Generator writes implementation proposal
claude -p "$(cat ~/.claude/agents/generator.md)
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
claude -p "$(cat ~/.claude/agents/evaluator.md)
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
claude -p "$(cat ~/.claude/agents/generator.md)
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

Update `manifest.yaml`: phase → "building"

**3. BUILD** — Dispatch Generator subagent
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

claude -p "$(cat ~/.claude/agents/generator.md)
--- PROJECT CONTEXT ---
$CONTEXT" \
  --allowedTools "Read,Write,Bash,mcp__context7"
```

Update `manifest.yaml`: phase → "evaluating"

**4. EVALUATE** — Dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

```bash
claude -p "$(cat ~/.claude/agents/evaluator.md)
--- EVALUATION CONTEXT ---
$(cat .harness/evaluator/criteria.md)
$(cat .harness/features/${FEATURE}/implementation-report.md)
$(cat .harness/features/${FEATURE}/contract.md)
$(cat .harness/spec/constitution.md)" \
  --allowedTools "Read,Write,Bash,mcp__playwright"
```

The Evaluator receives the Generator's implementation report as a starting point — but verifies every claim independently.

**5. RESULT** — Read evaluator report and decide

```bash
REPORT=".harness/features/${FEATURE}/eval-report.md"
RESULT=$(head -5 "$REPORT" | grep -oE "PASS|FAIL")
RETRIES=$(grep "retry_count" .harness/manifest.yaml | grep -oE "[0-9]+")
MAX=$(grep "max_retries" .harness/manifest.yaml | grep -oE "[0-9]+")
```

**If PASS:**

**5a-pre. TUNING CHECK** — Capture human-Evaluator divergence (automatic)

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

**5a. RETROSPECTIVE** — Drift analysis (automatic)

Before merging, run `/harness:retrospective` logic. Reconcile what was built vs what was spec'd. Write `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update `spec/prd.md`, `spec/architecture.md`, log ADRs in `progress/decisions.md`.

**5b. MERGE**

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

---

### `/harness:quick "<prompt>"` — Fast Mode

For small changes where planning overhead > implementation time.

**Procedure:**
1. Write a minimal contract directly (no Planner subagent):
   ```markdown
   # Quick Build Contract
   ## Task: [user's prompt]
   ## Test Criteria:
   - [ ] [inferred from the prompt]
   ## Done when: tests pass, lint clean, feature works
   ```
2. Dispatch Generator immediately
3. Single Evaluator pass (no retry loop)
4. Merge on pass, report on fail

---

### `/harness:resume` — Continue from checkpoint

The most important recovery command. Handles all session-interruption scenarios.

**Procedure:**

**Step 1: Read state**
```bash
cat .harness/manifest.yaml
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
PHASE=$(grep 'phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')
CURRENT_TASK=$(grep 'current_task:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
RETRIES=$(grep 'retry_count:' .harness/manifest.yaml | awk '{print $2}')
```

**Step 2: Print status report to user**
```
═══════════════════════════════
  Harness — Resume Status
═══════════════════════════════
Project: [name]
Current feature: ${FEATURE}
Phase: ${PHASE}
Current task: ${CURRENT_TASK}  (if building)
Retry count: ${RETRIES}

Last session: [timestamp from manifest]
Recent commits: [git log --oneline | head -5]

Recent changelog entries:
[last 3 entries from progress/changelog.md]
═══════════════════════════════
```

**Step 3: Run `bash .harness/init.sh`** for health check

**Step 4: Phase-specific recovery:**

**If `phase: planning`:**
- Check which spec files exist in `.harness/spec/`
- If PRD exists but architecture doesn't → Planner was in Pass 2. Re-dispatch to finish.
- If nothing exists → full Planner re-dispatch.

**If `phase: analyzing`:**
- Check if `features/${FEATURE}/analysis-report.md` exists.
- If yes: present findings, proceed to human gate.
- If no: re-run /harness:analyze logic.

**If `phase: negotiating`:**
- Check which files exist in `features/${FEATURE}/`:
  - If only `contract.md` (draft) exists: negotiation not started → dispatch 
    Generator in NEGOTIATE mode
  - If `proposal.md` exists but no `review.md`: proposal written, awaiting review 
    → dispatch Evaluator in REVIEW-PROPOSAL mode
  - If both exist and `review.md` verdict is `needs-revision`: dispatch Generator 
    to revise proposal
  - If `review.md` verdict is `agreed`: dispatch Generator in FINALIZE-CONTRACT mode
  - If negotiation round count ≥ 3 and no agreement: escalate to human


**If `phase: building`:**
- **Mid-build recovery:** This is the critical case.
- Read `changelog.md` to see which FRs were completed.
- Read `current_task` from manifest — the FR that was in progress when session ended.
- Run `git log --oneline | grep "harness:build"` to verify commit state.
- Dispatch FRESH Generator with instruction: "Resume from ${CURRENT_TASK}. FRs [list] already completed. Continue with remaining FRs in dependency order."

**If `phase: evaluating`:**
- Check if `features/${FEATURE}/eval-report.md` exists.
- If no: dispatch Evaluator.
- If yes: check if tuning check already happened for this eval (look for a log entry in `tuning-log.md` referencing this feature and today's eval, OR a note saying "Agreed — no entry").
  - If tuning check not done → run it now (step 5a-pre from `/harness:sprint`).
  - If tuning check done → proceed to PASS/FAIL handling.

**If `phase: retrospective`:**
- Check if `features/${FEATURE}/retrospective.md` exists.
- If yes: present drift findings to user, await approval.
- If no: re-run retrospective.

**If `phase: complete`:**
- Report: "Last feature (${FEATURE}) shipped on [date]."
- Show ROADMAP planned features.
- Offer: `/harness:sprint "<next feature>"`.

**Step 5: If ambiguity detected** (e.g., git log disagrees with changelog):
- Print the conflict clearly.
- Ask user: "Git shows FR-005 committed but changelog says FR-003 was last. Should I trust git?"
- Never silently proceed with conflicting state.

---

### `/harness:audit` — Verification debt check (GSD-inspired)

Runs independently of sprints. Scans all completed features for deferred verification items, stale known-issues, and silent skips.

**Procedure:**
1. Read `.harness/manifest.yaml` → `verification_debt` section
2. Scan every `features/*/eval-report.md` for Major/Minor findings marked "deferred"
3. Scan `.harness/progress/known-issues.md` for items older than 30 days
4. Scan every `features/*/retrospective.md` for unresolved drift
5. Cross-reference against current codebase (has anything been silently fixed?)
6. Report:
   ```
   ═══════════════════════════════
     Harness — Verification Audit
   ═══════════════════════════════
   Deferred findings: [N]
     - features/001/M1: "Empty state UI missing" (deferred 45 days ago)
     - features/003/m2: "Rate limit not implemented" (deferred 12 days ago)
   
   Stale known-issues: [N]
   Pending human questions: [N]
   Silently resolved (can be closed): [N]
   
   Recommendations:
     - Address M1 (old, may block shipping)
     - Close 3 items that are silently resolved
   ═══════════════════════════════
   ```
7. Offer to promote high-priority items to new sprints via `/harness:sprint`

---

### `/harness:validate` — Validate existing spec (BMAD tri-modal)

For when you want to audit an existing PRD without regenerating it.

**Procedure:**
1. Read all `.harness/spec/` files
2. Run the Planner's 13-point validation checklist against them
3. Report findings:
   ```
   ═══════════════════════════════
     Harness — Spec Validation
   ═══════════════════════════════
   V1  Completeness:    PASS/FAIL  [details]
   V2  SMART NFRs:      PASS/FAIL  [details]
   V3  Traceability:    PASS/FAIL  [details]
   ...
   V13 Right-sized:     PASS/FAIL  [details]
   
   Result: [N]/13 passed
   Fix: [list of specific issues to address]
   ═══════════════════════════════
   ```
4. If issues found, offer to fix them in-place

### `/harness:edit "<what to change>"` — Targeted spec edit (BMAD tri-modal)

For when you want to modify a specific part of the spec without regenerating everything.

**Procedure:**
1. Read the user's requested change
2. Identify which files are affected (prd.md? architecture.md? contract?)
3. Apply the change surgically — only modify the affected sections
4. Update downstream references:
   - If a FR changed → update the architecture traceability table
   - If architecture changed → update the contract build order
   - If an AC changed → update the evaluator criteria
5. Re-run validation on modified files only
6. Report what changed and what downstream updates were made

**Example:** `/harness:edit "Change the database from SQLite to PostgreSQL"`
→ Updates architecture.md stack table + component details
→ Updates init.sh for PostgreSQL setup
→ Updates NFRs if performance targets change
→ Contract stays the same (FRs didn't change)
→ Logs the change in decisions.md as an ADR

---

### `/harness:analyze` — Cross-artifact consistency check (SpecKit-inspired)

Runs AFTER the Planner completes and BEFORE the human approval gate. Catches misalignments between PRD, architecture, and contract before we waste the Generator's time building from a flawed spec.

**When it runs automatically:**
In the full `/harness:sprint` flow, `/harness:analyze` runs automatically between Planner completion and the human gate. It's transparent — findings are presented alongside the approval prompt.

**When to invoke manually:**
- After `/harness:edit` modified a spec file (check nothing drifted)
- Before starting a complex sprint where confidence matters
- After importing a spec from elsewhere

**Procedure:**
1. Read `.harness/spec/prd.md`, `.harness/spec/architecture.md`, `.harness/spec/constitution.md`, `.harness/features/{current-feature}/contract.md`
2. Run these checks:
   - **Requirement coverage**: Every FR in the PRD appears in the architecture traceability table AND in the contract deliverables
   - **AC coverage**: Every AC in the PRD appears in the contract's test criteria
   - **NFR alignment**: Stack choices in architecture can realistically meet NFR metrics
   - **Constitution compliance**: Nothing in the plan violates a constitution principle
   - **Dependency ordering**: Contract's build order respects architectural dependencies
   - **Scope consistency**: Contract scope matches PRD priorities (no P2 features in a P0 contract)
   - **Tech stack conflicts**: No contradicting framework mentions across files
3. Write findings to `.harness/features/{current-feature}/analysis-report.md`:
   ```
   ═══════════════════════════════
     Harness — Cross-Artifact Analysis
   ═══════════════════════════════
   Requirement coverage:   [N]/[N] FRs mapped    ✓/✗
   AC coverage:            [N]/[N] ACs tested    ✓/✗
   NFR alignment:          [assessment]          ✓/✗/?
   Constitution:           [violations count]    ✓/✗
   Dependency ordering:    [issues count]        ✓/✗
   Scope consistency:      [issues]              ✓/✗
   
   CRITICAL findings: [list]
   WARNINGS: [list]
   
   Remediation (optional):
     - [specific fix for finding 1]
     - [specific fix for finding 2]
   ═══════════════════════════════
   ```
4. **CRITICAL findings block progress** — the sprint cannot proceed until they're resolved (user can use `/harness:edit` to fix, or manually edit)
5. **Warnings are informational** — sprint can proceed but user should know

**Constitutional violations are always CRITICAL** — from SpecKit: "The correct action is always to modify the plan or tasks to comply with the constitution, never to weaken or remove constitutional principles."

---
### `/harness:negotiate` — Generator↔Evaluator contract negotiation

Runs AFTER `/harness:analyze` clears and BEFORE Generator builds. Translates the 
Planner's high-level contract into a testable implementation plan that both 
Generator and Evaluator commit to.

**When it runs automatically:**
In the full `/harness:sprint` flow, `/harness:negotiate` runs automatically between 
ANALYZE and BUILD. You don't invoke it manually in the happy path.

**When to invoke manually:**
- `/harness:resume` landed on phase "negotiating" after session interruption
- You edited the draft contract and want to re-negotiate before rebuilding
- Previous negotiation was escalated to human and you now want to restart it

**Why this exists:**
The Planner stays at the "what & why" level on purpose. File paths, component 
boundaries, data schemas, and API shapes are NOT in the architecture doc. This 
negotiation is where those details get pinned down — but by the agents that will 
actually build and test, not by the Planner upfront. This prevents the Planner 
from cascading wrong technical details into the entire downstream pipeline.

**Procedure:**

1. **Generator proposes** (writes `proposal.md`)
   - Reads: draft contract, architecture direction, constitution, criteria
   - Writes: implementation plan with components, files, schemas, test strategy
   - Does NOT write code

2. **Evaluator reviews** (writes `review.md`)
   - Reads: contract, proposal, criteria
   - Checks: HOW clarity, AC testability, risk flags
   - Writes: verdict (`agreed` / `needs-revision`) + specific asks
   - Does NOT run Playwright — there's no app yet

3. **If `needs-revision`:** Generator revises proposal (append new round to 
   `proposal.md`), Evaluator re-reviews. Max 3 rounds.

4. **If no agreement after 3 rounds:** Escalate to human with:
   - Diff of what Generator wants vs what Evaluator wants
   - The core disagreement summarized
   - Options: force one side, rewrite the draft contract, abandon feature

5. **On agreement:** Generator writes final `contract.md` (overwrites Planner's 
   draft) merging the original deliverables + negotiated implementation details + 
   any Evaluator-added ACs.

**Anti-patterns to watch for:**
- Generator proposing every detail (over-specifying) → Evaluator should push back 
  on anything not needed to test the AC
- Evaluator rubber-stamping without reading → check `review.md` — if it's 3 lines, 
  the Evaluator didn't actually engage
- Negotiation loop going 3+ rounds → the draft contract itself is probably unclear; 
  escalate to human rather than letting agents thrash

---

### `/harness:retrospective` — Post-merge drift analysis & spec sync

Runs AFTER the Evaluator returns PASS and BEFORE the final merge+archive. Reconciles what was actually built against what the spec said would be built. Keeps the PRD and architecture in sync with reality over multiple sprints.

**When it runs automatically:**
In the full `/harness:sprint` flow, `/harness:retrospective` runs automatically after Evaluator PASS, before the ROADMAP update.

**Why it matters:**
Over many features, specs drift. The Generator might add a helper not mentioned in architecture. An AC might be satisfied differently than specified. The PRD might describe an out-of-scope flow that got built anyway. Without periodic reconciliation, the spec becomes fiction and future features build on lies.

**Procedure:**
1. Read the completed feature's artifacts:
   - `.harness/features/{current-feature}/contract.md` (what was planned)
   - `.harness/features/{current-feature}/implementation-report.md` (what Generator says was built)
   - `.harness/features/{current-feature}/eval-report.md` (PASS — what was verified)
2. Scan the source code to identify what actually exists
3. Identify drift in three categories:
   - **Positive drift**: implementation is better than spec'd (new helpers, better structure). Propose adding to spec.
   - **Negative drift**: implementation is worse than spec'd (shortcuts, stubs that passed eval anyway). Propose tightening spec or adding to known-issues.
   - **Neutral drift**: different path to same outcome. Propose updating architecture to reflect reality.
4. Write findings to `.harness/features/{current-feature}/retrospective.md`:
   ```
   ═══════════════════════════════
     Harness — Retrospective
   ═══════════════════════════════
   Feature: {current-feature}
   Spec adherence: [score]/10
   
   Positive drift (consider adding to spec):
     - [new component in src/lib/validator.ts — not in architecture]
     - [additional AC satisfied beyond contract: fuzzy search for tags]
   
   Negative drift (consider tightening spec):
     - [FR-003 technically passed but edge case EC-003-2 is handled by a stub]
   
   Neutral drift (update architecture to reflect reality):
     - [Planner said "Redis for caching" but implementation uses in-memory Map]
   
   Proposed spec updates:
     - [specific change 1 with file + section]
     - [specific change 2 with file + section]
   ═══════════════════════════════
   ```
5. **Present to human** — drift proposals require human approval before applying
6. On approval: apply the updates to `spec/prd.md`, `spec/architecture.md`, log each change as an ADR in `progress/decisions.md`
7. Update `ROADMAP.md`:
   - Move the feature from "🚧 In Progress" to "✅ Shipped"
   - Add scores, retry count, merge date
   - If retrospective revealed new feature ideas, add them to "💭 Considered"
8. Update `manifest.yaml`:
   - `features.completed`: append the feature folder name
   - `features.in_progress`: empty
   - `state.phase`: "complete"

**On decline:** retrospective findings stay in `retrospective.md` as a record but specs aren't modified. User can revisit later.

---
### `/harness:tune-evaluator` — Review divergence patterns and propose prompt improvements

Runs independently of sprints. Analyzes accumulated `tuning-log.md` entries to surface patterns and propose concrete changes to Evaluator calibration.

**When to invoke:**
- The sprint pipeline suggests it after detecting ≥3 entries of the same divergence category
- After a string of feels-wrong evaluations, to check if it's a pattern
- Periodically (every 5-10 features) as a health check

**Why it exists:**
Anthropic's documented tuning loop: "read the evaluator's logs, find examples where its judgment diverged from mine, and update the QAs prompt to solve for those issues." This command formalizes that loop.

The default posture is CONSERVATIVE. Most divergences should result in adding an example to `examples.md`, not changing the Evaluator prompt. Prompt changes are only justified when a behavioral pattern is systematic and example calibration hasn't fixed it.

**Procedure:**

1. Read `.harness/evaluator/tuning-log.md` entirely.

2. Group entries by divergence category:
   - Leniency (Evaluator too soft)
   - Strictness (Evaluator too harsh — false FAILs)
   - Missed issue (Evaluator didn't test edge case)
   - Overclaim (Evaluator flagged something that wasn't actually broken)
   - Scope confusion (Evaluator graded outside contract)
   - Other

3. For each category with ≥3 entries, run pattern analysis:
   - Read the specific divergences
   - Check `examples.md` for calibration examples already covering this pattern
   - Determine: is this a calibration gap, or a systematic behavioral issue?

4. Report:

```
═══════════════════════════════
  Harness — Evaluator Tuning Review
═══════════════════════════════
Log entries analyzed: [N]
Patterns detected: [N]

Pattern 1: Leniency on edge case testing
  Entries: [list of log entries]
  Root cause assessment: [calibration gap / behavioral / unclear]
  Existing examples covering this: [N]
  
  Proposed action:
    [ ] Add calibration example to examples.md (preferred — low risk)
    [ ] Update evaluator.md prompt (higher risk — only if examples insufficient)
    [ ] Defer — not enough signal yet, revisit after more entries

Pattern 2: [...]

Recommendations:
  - Low-risk: [add N examples to examples.md]
  - Higher-risk: [specific prompt tweaks, if any]
═══════════════════════════════
```

5. Present recommendations to the user. For each:
   - If user approves "add example" → draft the example, show it, append to `examples.md` on confirmation
   - If user approves "update prompt" → draft the specific prompt diff (show before/after), apply to `evaluator.md` on confirmation, and log the change as an ADR in `progress/decisions.md` for traceability
   - If user defers → mark entries in tuning-log.md as "reviewed, deferred" so they don't resurface immediately

6. On any prompt change to `evaluator.md`:
   - Update `manifest.yaml` → `harness.model_tuning_revision` field (new, integer counter)
   - Note in the ADR: which feature's tuning log triggered this, what was changed, why

**Anti-patterns:**
- **Over-eager prompt editing**: Every divergence becoming a prompt change. This leads to prompt bloat and overfitting. Default to examples; touch the prompt only for systematic issues.
- **Single-case prompt changes**: Changing `evaluator.md` based on one divergence. Not enough signal. Wait for pattern.
- **Silent prompt edits**: Changing the prompt without logging why. Impossible to audit later. Every prompt change must produce an ADR.
- **Ignoring strictness divergences**: Only attending to leniency. False FAILs waste retry cycles just as badly as false PASSes ship bugs.
---


## Session Start Behavior

When starting a new Claude Code session in any project:

```
IF .harness/manifest.yaml exists:
  Read it silently
  IF phase ≠ "complete":
    Mention: "This project has harness state (phase: [X]). 
              Run /harness:resume to continue."
```

Don't auto-resume — just notify. The user may want to do something else first.

## File Communication Protocol

Agents NEVER share conversation context. They communicate exclusively via `.harness/` files. Each feature has its own folder under `.harness/features/NNN-name/` for scoped artifacts.

```
GLOBAL files (persist across features):
  .harness/spec/          — prd.md, architecture.md, constitution.md
  .harness/evaluator/     — criteria.md (grading rubric)
  .harness/ROADMAP.md     — shipped/in-progress/planned features
  .harness/manifest.yaml  — current state + feature tracking
  .harness/progress/      — changelog.md, decisions.md (append-only)

PER-FEATURE files (isolated in .harness/features/NNN-name/):
  contract.md              — what this feature builds (Planner writes)
  implementation-report.md — what was built (Generator writes)
  eval-report.md           — PASS/FAIL verdict (Evaluator writes)
  analysis-report.md       — cross-artifact check (optional, /analyze)
  retrospective.md         — drift analysis (optional, /retrospective)

FLOW:
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
  Evaluator    → reads  → evaluator/criteria.md, features/NNN/implementation-report.md,
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
  Orchestrator  → writes → .harness/evaluator/tuning-log.md (append)
                → writes → .harness/evaluator/examples.md (if calibration example agreed)
                → writes → .harness/spec/evaluator-notes.md (if project-specific)
  
  Periodic / on pattern detection:
  [/harness:tune-evaluator]
  Orchestrator  → reads  → .harness/evaluator/tuning-log.md
                → writes → .harness/evaluator/examples.md (new examples)
                         → ~/.claude/agents/evaluator.md (prompt changes, rare)
                         → .harness/progress/decisions.md (ADR for any prompt change)
  
  Evaluator in EVALUATE mode reads (addition to earlier list):
  Evaluator    → reads  → .harness/evaluator/examples.md (global calibration)
                        → .harness/spec/evaluator-notes.md (project-specific, if exists)
```
