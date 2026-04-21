---
description: Archive-based phase reset for the current feature. Moves files to .archive/, resets manifest state, optionally resets the build git branch. Requires typed confirmation.
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
| `negotiating` | `proposal.md`, `review.md`, final contract (draft kept) | spec, draft contract |
| `building` | `implementation-report.md`, `eval-report.md`, `retrospective.md` | spec, final contract, proposal, review |
| `evaluating` | `eval-report.md`, `retrospective.md` | all build artifacts + source |

`complete` is not a valid rewind target (feature is shipped; start a new one).

## Procedure

### Step 1: Validate target + feature exists

Orchestrator reads `$ARGUMENTS` and `.harness/manifest.yaml → state.current_feature`. Validate target is one of the five valid phases; validate a current feature exists. If either fails, print a concise error and exit.

### Step 2: Preview

Show the user what will be archived, what will survive, the manifest delta (phase, current_task, retry_count, negotiation_round), and — if rewinding to `building` or earlier and the `harness/build/${FEATURE}` branch has commits — a separate git warning (see Step 6).

### Step 3: Require typed confirmation

The user must type exactly `rewind to <target>` (e.g., `rewind to negotiating`). No fuzzy match — rewind is the most destructive command in the harness. On any other input, cancel with "rewind cancelled, nothing changed."

### Step 4: Archive

Orchestrator creates `.harness/features/${FEATURE}/.archive/TIMESTAMP/` (via Bash tool using `mkdir -p`). For each file in the archive set (per the table above), the orchestrator uses `mv` to move it into the archive directory.

For `planning` target: archive the WHOLE feature folder (move `.harness/features/${FEATURE}/*` except `.archive/`), and set `state.current_feature = ""` so the next `/harness:sprint` creates a fresh numbered folder.

Orchestrator writes a `REWIND-MANIFEST.md` inside the archive directory recording: which files moved, from which phase, git state at time of rewind, the user's reason (if provided).

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
      Commands orchestrator will run:
        git checkout harness/build/${FEATURE}
        git reset --hard $(git merge-base main harness/build/${FEATURE})
        git checkout -
  Skip — don't touch the branch.
```

Default to (a) if the user hesitates. Never run (b) without the explicit `reset build branch` typed confirmation.

**Why not offer `git branch -D`?** Too destructive to chain into the same prompt. Forcing the user to run it as a separate manual step catches typos and accidental invocations.

### Step 7: Log

Orchestrator appends to `.harness/progress/changelog.md` (via Edit):

```markdown
## YYYY-MM-DD — features/NNN — Rewind
- From: [previous phase]
- To: ${TARGET}
- Archived: [N] files to .archive/TIMESTAMP/
- Git action: [kept / reset branch / no branch]
- Reason: [if user provided]
```

Orchestrator appends ADR to `.harness/progress/decisions.md` (ADR template at `@templates/progress/decisions.md`).

### Step 8: Tell the user what's next

```
═══════════════════════════════
  Harness — Rewind Complete
═══════════════════════════════
Feature ${FEATURE} reset to phase: ${TARGET}
Archive: .harness/features/${FEATURE}/.archive/TIMESTAMP/
ADR logged:  progress/decisions.md

Next:
  • /harness:resume — continue from ${TARGET}
  • Or make adjustments first (e.g., /harness:edit), then /harness:resume
  • To abandon: delete features/${FEATURE}/ and reset manifest manually
═══════════════════════════════
```

## Anti-patterns

- **Repeated rewinds without addressing root cause** — three rewinds of one feature means the spec is wrong. Use `/harness:rewind planning` once and restart OR abandon.
- **Resetting git branches without backup** — option (b) is destructive. Make sure the user understands before confirming.
- **Using rewind as undo for a single file** — `git checkout -- <file>` is better.
- **Rewinding after merge** — use `/harness:retrospective` instead.
