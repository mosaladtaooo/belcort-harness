---
description: Resume an interrupted harness pipeline from the last checkpoint. Reads .harness/manifest.yaml and changelog.md to recover state, then dispatches the correct subagent for the current phase.
---

# `/harness:resume` — Continue from checkpoint

The most important recovery command. Handles all session-interruption scenarios.

## Procedure

### Step 1: Read state

```bash
cat .harness/manifest.yaml
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
PHASE=$(grep 'phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')
CURRENT_TASK=$(grep 'current_task:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
RETRIES=$(grep 'retry_count:' .harness/manifest.yaml | awk '{print $2}')
```

If no `.harness/manifest.yaml` exists in this directory, tell the user there's no active harness here and suggest `/harness:sprint` to start one.

### Step 2: Print status report to user

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

### Step 3: Run `bash .harness/init.sh` for health check

### Step 4: Phase-specific recovery

**If `phase: planning`:**
- Check which spec files exist in `.harness/spec/`
- If PRD exists but architecture doesn't → Planner was in Pass 2. Re-dispatch to finish.
- If nothing exists → full Planner re-dispatch.

**If `phase: analyzing`:**
- Check if `features/${FEATURE}/analysis-report.md` exists.
- If yes: present findings, proceed to human gate.
- If no: re-run the [analyze.md](analyze.md) procedure.

**If `phase: negotiating`:**
- Check which files exist in `features/${FEATURE}/`:
  - If only `contract.md` (draft) exists: negotiation not started → dispatch Generator in NEGOTIATE mode
  - If `proposal.md` exists but no `review.md`: proposal written, awaiting review → dispatch Evaluator in REVIEW-PROPOSAL mode
  - If both exist and `review.md` verdict is `needs-revision`: dispatch Generator to revise proposal
  - If `review.md` verdict is `agreed`: dispatch Generator in FINALIZE-CONTRACT mode
  - If negotiation round count ≥ 3 and no agreement: escalate to human

See [negotiate.md](negotiate.md) for full dispatch blocks.

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
  - If tuning check not done → run it now (step 5a-pre from [sprint.md](sprint.md)).
  - If tuning check done → proceed to PASS/FAIL handling.

**If `phase: retrospective`:**
- Check if `features/${FEATURE}/retrospective.md` exists.
- If yes: present drift findings to user, await approval.
- If no: re-run the [retrospective.md](retrospective.md) procedure.

**If `phase: complete`:**
- Report: "Last feature (${FEATURE}) shipped on [date]."
- Show ROADMAP planned features.
- Offer: `/harness:sprint "<next feature>"`.

### Step 5: If ambiguity detected (e.g., git log disagrees with changelog)

- Print the conflict clearly.
- Ask user: "Git shows FR-005 committed but changelog says FR-003 was last. Should I trust git?"
- Never silently proceed with conflicting state.
