---
description: Reset the harness to an earlier phase for the current feature. Archives everything produced after that phase (never deletes), resets manifest state, and leaves the project ready to resume. Requires explicit confirmation — destructive by default. Use when a phase went off-track and a clean restart from an earlier checkpoint is cheaper than surgical edits.
argument-hint: "<target phase: planning | analyzing | negotiating | building | evaluating>"
---

# `/harness:rewind` — Reset to an earlier phase

For when a phase went fundamentally wrong and you'd rather restart from an earlier checkpoint than patch forward. Target phase is `$ARGUMENTS`. If empty, ask which phase.

**Rewind is archive-based, not delete-based.** Every file removed from the active state gets moved to `.harness/features/NNN/.archive/YYYYMMDD-HHMMSS/`. You can inspect the archive at any time, and copy files back if you decide the rewind was a mistake. Nothing is truly destroyed except (optionally) git commits during a build rewind, which the user must explicitly confirm.

## When to use rewind

- **Planner output is fundamentally wrong** → `/harness:rewind planning`. The PRD misunderstood the user's intent, or the architecture picked the wrong stack. Cheaper to re-plan than to patch with `/harness:amend`.
- **Negotiation stuck in a loop and the contract draft is the problem** → `/harness:rewind planning` (to re-plan) or stay at `negotiating` and restart negotiation after editing the draft.
- **Build went off-rails and multiple retries didn't help** → `/harness:rewind negotiating`. The contract probably needs refinement before another build.
- **Evaluator disagreement is systemic** → NOT a rewind problem. Use `/harness:tune-evaluator` instead.
- **You want to redo evaluation** → `/harness:rewind evaluating`. Keeps build artifacts, forces a fresh Evaluator dispatch.

## When NOT to use rewind

- Minor tweaks → use `/harness:amend`
- Ambiguity resolution → use `/harness:clarify`
- Implementation nudges → use `/harness:steer`
- Post-merge spec sync → use `/harness:retrospective`
- Fully shipped features → rewind won't help; start a new feature

## Valid target phases

| Target | What gets archived | What survives | Git impact |
|---|---|---|---|
| `planning` | whole feature folder | spec/ files you built up over prior features | none (no commits yet) |
| `analyzing` | `analysis-report.md` | spec/, draft contract | none |
| `negotiating` | `proposal.md`, `review.md`, final contract (keeps draft) | spec/, draft contract | none |
| `building` | `implementation-report.md`, `eval-report.md` | spec/, final contract, proposal, review | WARN — commits on `harness/build/${FEATURE}` branch survive by default; orchestrator offers to reset |
| `evaluating` | `eval-report.md`, `retrospective.md` | all build artifacts + source | none |

`complete` is not a valid rewind target — that feature is done and merged. Start a new feature.

## Procedure

### Step 1: Validate the target phase

```bash
TARGET="$ARGUMENTS"
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

[ -n "$FEATURE" ] || {
  echo "No active feature. Nothing to rewind."
  exit 1
}

case "$TARGET" in
  planning|analyzing|negotiating|building|evaluating) ;;
  "") echo "Usage: /harness:rewind <phase>. Valid phases: planning, analyzing, negotiating, building, evaluating."; exit 1 ;;
  complete|retrospective)
    echo "Cannot rewind to '$TARGET'. Rewind moves backward, not forward or sideways."
    exit 1 ;;
  *) echo "Unknown phase: $TARGET"; exit 1 ;;
esac
```

### Step 2: Identify what will be archived

Based on the target phase, determine which files get moved to archive. Build a manifest of the planned archive:

```
═══════════════════════════════
  Harness — Rewind Preview
═══════════════════════════════
Feature: ${FEATURE}
Current phase: [read from manifest]
Target phase:  ${TARGET}

Files that will be archived to .harness/features/${FEATURE}/.archive/YYYYMMDD-HHMMSS/:
  • features/${FEATURE}/proposal.md
  • features/${FEATURE}/review.md
  • features/${FEATURE}/implementation-report.md
  • features/${FEATURE}/eval-report.md

Files that survive:
  • spec/prd.md           (kept)
  • spec/architecture.md  (kept)
  • spec/constitution.md  (kept)
  • features/${FEATURE}/contract.md (draft kept; final archived)

Manifest changes:
  state.phase:         building → ${TARGET}
  state.current_task:  "FR-005" → ""
  state.retry_count:   2 → 0
  state.negotiation_round: N → 0 (if rewinding past negotiation)

[If rewinding to 'building' or earlier and commits exist on harness/build/${FEATURE}]
Git warning:
  You have [N] commits on branch harness/build/${FEATURE}.
  Rewinding to ${TARGET} does NOT automatically revert these commits.
  After confirmation, you'll be asked separately whether to:
    (a) keep commits on the branch (default — safe)
    (b) reset the branch to the last 'pre-build' commit (destructive)
═══════════════════════════════

Type "rewind to ${TARGET}" to confirm, or anything else to cancel.
```

### Step 3: Require explicit confirmation

The user must type the full phrase `rewind to <target>` to proceed. Fuzzy matching is dangerous here — rewind is the most destructive command in the harness.

On cancel: exit with "rewind cancelled, nothing changed".

### Step 4: Archive the files

```bash
TS=$(date +%Y%m%d-%H%M%S)
ARCHIVE=".harness/features/${FEATURE}/.archive/${TS}"
mkdir -p "$ARCHIVE"

# Move files (mv preserves content, removes from active state)
# Example for rewinding to 'negotiating':
mv ".harness/features/${FEATURE}/implementation-report.md" "$ARCHIVE/" 2>/dev/null || true
mv ".harness/features/${FEATURE}/eval-report.md" "$ARCHIVE/" 2>/dev/null || true
mv ".harness/features/${FEATURE}/retrospective.md" "$ARCHIVE/" 2>/dev/null || true

# Write a manifest of what was archived
cat > "$ARCHIVE/REWIND-MANIFEST.md" <<EOF
# Rewind — $(date +%Y-%m-%dT%H:%M:%S%z)

**Feature**: ${FEATURE}
**Rewound from**: [previous phase]
**Rewound to**: ${TARGET}
**Reason**: [user-provided or "not specified"]

## Files archived
[list]

## Manifest delta
[before/after snapshot of state.*]

## Git state at time of rewind
[output of 'git log --oneline -5']

## How to revert this rewind
Copy the archived files back to features/${FEATURE}/ and reset manifest.phase
manually. No automatic revert — rewinds are recorded for forensics, not undo.
EOF
```

### Step 5: Reset manifest state

Update `.harness/manifest.yaml`:

```yaml
state:
  phase: "<target>"          # reset
  current_task: ""           # if rewinding past building
  retry_count: 0             # reset
  negotiation_round: 0       # if rewinding past negotiating
  last_session: "[now]"
```

Leave `current_feature` alone UNLESS rewinding to `planning` — in that case, archive the whole feature folder and set `current_feature: ""` so the next `/harness:sprint` creates a fresh one.

### Step 6: Handle git (if applicable)

If the rewind target is `building` or earlier AND the branch `harness/build/${FEATURE}` exists with commits:

```
═══════════════════════════════
  Git — Build commits detected
═══════════════════════════════
Branch: harness/build/${FEATURE}
Commits on this branch: [N]

Last 5 commits:
  [git log --oneline | head -5]

Options:
  (a) Keep commits — branch survives, you can cherry-pick or discard manually later
      Safe default.
  (b) Reset branch to base — destroys [N] commits on harness/build/${FEATURE}
      This is destructive. Type "reset build branch" to confirm.

Enter (a), (b), or "skip" to leave the branch alone:
```

Default to (a) if the user hesitates. Git resets are destructive and rarely necessary — in most cases, leaving the branch around is fine (the user can `git branch -D` it later).

### Step 7: Log the rewind

Append to `.harness/progress/changelog.md`:

```
## YYYY-MM-DD — features/NNN — Rewind
- From: [previous phase]
- To: ${TARGET}
- Archived: [N] files to features/NNN/.archive/YYYYMMDD-HHMMSS/
- Git action: [kept / reset branch / no branch]
- Reason: [if provided]
```

Append ADR to `.harness/progress/decisions.md`:

```
## ADR-NNN — Rewind from [previous phase] to ${TARGET}
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE}
**Status**: Accepted

### Context
[Why the rewind was necessary — user's reason, or "not specified"]

### Decision
Rewound feature ${FEATURE} from [previous phase] to ${TARGET}. Archived
[N] files to .archive/YYYYMMDD-HHMMSS/.

### Consequences
- [What phase will restart from, what work is lost, what survived]
- [Downstream: next dispatch is [Planner/Generator/Evaluator/whatever]]
```

### Step 8: Tell the user what's next

```
═══════════════════════════════
  Harness — Rewind Complete
═══════════════════════════════
Feature ${FEATURE} has been reset to phase: ${TARGET}

Archived to: .harness/features/${FEATURE}/.archive/YYYYMMDD-HHMMSS/
ADR logged:  progress/decisions.md (ADR-NNN)

Next steps:
  • Run /harness:resume to continue from ${TARGET}
  • Or make adjustments first (e.g., /harness:edit for spec tweaks) then /harness:resume
  • To abandon this feature entirely: delete .harness/features/${FEATURE}/ and update manifest
═══════════════════════════════
```

## Anti-patterns

- **Rewinding repeatedly without addressing root cause**: three rewinds of the same feature means the spec is wrong. Use `/harness:rewind planning` once and start fresh, or give up on the feature.
- **Resetting git branches without backup**: the `(b)` option is destructive. Make sure the user understands.
- **Using rewind as undo for a single file change**: rewind is big-hammer. For single-file changes, `git checkout -- <file>` is better.
- **Rewinding after merge**: post-merge, the feature is shipped. Use `/harness:retrospective` instead.

## Files written / moved

| File | Action |
|---|---|
| Affected feature files | Moved to `.harness/features/NNN/.archive/YYYYMMDD-HHMMSS/` |
| `.harness/manifest.yaml` | Phase + related state fields reset |
| `progress/changelog.md` | Rewind entry appended |
| `progress/decisions.md` | ADR appended |
| `harness/build/${FEATURE}` git branch | Optionally reset on explicit user confirmation |
