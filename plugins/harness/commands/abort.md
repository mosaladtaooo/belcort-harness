---
description: Mid-flight stop for a running harness sprint. Discards uncommitted worktree changes and resets to the last clean phase, OR pauses cleanly so /harness:resume can pick up later. Requires typed confirmation.
argument-hint: ""
---

# `/harness:abort`

Cmd+C used to be the only way to stop a sprint mid-flight. It worked, but it left half-state — a partially-written file, a manifest claiming `phase: building` while the worktree had no commits, an Evaluator that never wrote `eval-report.md`. The next `/harness:resume` then guessed wrong about where to pick up.

`/harness:abort` is the explicit stop. It surfaces what's preserved (commits on the build branch), what's discarded (uncommitted edits in the worktree), and asks for a typed confirmation so you can't bail out by accident.

## When to use

- The sprint is doing the wrong thing and patching forward is more expensive than restarting.
- You want to stop because of cost (see retry-counter messages and the `Sprint cost so far` line).
- The Evaluator is in an obvious infinite loop with the Generator and you want to break it.
- You realized mid-sprint you should have run `/harness:design explore` first and want to back out cleanly.

For a less-destructive option that just **saves state and exits**, type `pause` at the confirmation prompt instead of `abort`. `/harness:resume` picks up from the last clean checkpoint.

For a less-mid-flight option (you already let the sprint finish, you want to undo files), use [`/harness:rewind`](rewind.md).

## Procedure

### Step 1: Read state

Orchestrator reads `.harness/manifest.yaml` via the Read tool to get:
- `state.phase` — what phase the sprint is in (planning | analyzing | negotiating | building | evaluating | retrospective | complete)
- `state.current_feature` — the feature folder
- `state.retry_count`, `state.negotiation_round` — counters that will be reset
- `state.estimated_cost_usd` (if present, v2.2-staging UX-r1 / FIX A3) — the running cost estimate

If `state.phase = "complete"`, abort isn't applicable — print *"Sprint already complete; nothing to abort. Run /harness:retrospective if you want a drift analysis, or start a new sprint."* and exit.

If `state.current_feature` is empty, no sprint is in progress. Print *"No sprint in progress. Nothing to abort."* and exit.

### Step 2: Inventory what's preserved vs discarded

**Preserved (commits + spec)**:
- All commits on `harness/build/${FEATURE}` branch — the worktree's git history is never touched by abort.
- All spec files (`.harness/spec/*`) — these were authored by Planner subagents; the orchestrator doesn't touch them.
- The `.harness/features/${FEATURE}/` folder including any `contract.md`, `proposal.md`, `review.md`, `implementation-report.md`, `eval-report.md` already written by the time of the abort.
- `.harness/progress/changelog.md` and `.harness/progress/decisions.md` — append-only, never rewound.
- `.harness/design/*` if it exists.

**Discarded on `abort`**:
- Uncommitted changes in `.worktrees/current/` (Generator was mid-edit, Evaluator started writing a partial report, etc.). These are stashed via `git -C .worktrees/current stash push -u -m "harness-abort-TIMESTAMP"` so they're recoverable from the stash list if the user changes their mind, but they're removed from the working tree.
- Any half-written file at `.harness/features/${FEATURE}/pause-questions.md`, `audit-feedback.md`, or `.last-designer-stdout.txt` that didn't make it through to a final state. These are moved to `.harness/features/${FEATURE}/.aborted/TIMESTAMP/` for forensics.

**Discarded on `pause`**:
- Nothing. `pause` is a clean exit — it just sets `state.last_session` and the orchestrator stops dispatching.

### Step 3: Show the user what's about to happen

Print a preview block:

```
═══════════════════════════════════════════════════════════════
  Harness — Abort Preview
═══════════════════════════════════════════════════════════════
Feature:           ${FEATURE}
Current phase:     ${PHASE}
Retry count:       ${RETRY_COUNT} of ${MAX_RETRIES}
Negotiation round: ${NEGOTIATION_ROUND} of 3
Estimated cost:    ~$${ESTIMATED_COST_USD}  (so far in this sprint)

Preserved (kept regardless of choice):
  ✓ all commits on harness/build/${FEATURE}
  ✓ all spec files (.harness/spec/*)
  ✓ contract.md, proposal.md, review.md, implementation-report.md,
    eval-report.md (whichever already exist)
  ✓ progress/changelog.md, progress/decisions.md

Discarded on 'abort':
  ✗ uncommitted edits in .worktrees/current/  (stashed, recoverable
    via 'git -C .worktrees/current stash list')
  ✗ pause-questions.md, .last-designer-stdout.txt and other transient
    files (moved to .harness/features/${FEATURE}/.aborted/TIMESTAMP/
    for forensics — never deleted)

Discarded on 'pause':
  Nothing. Pause = clean exit; /harness:resume picks up from current
  phase.

═══════════════════════════════════════════════════════════════
  Type 'abort' to discard uncommitted work and reset to last clean
              phase.
  Type 'pause' to save state and exit (resume later with
              /harness:resume).
  Anything else cancels.
═══════════════════════════════════════════════════════════════
```

### Step 4: Wait for typed confirmation

Read user input. Match exactly (case-insensitive, leading/trailing whitespace trimmed):

- `abort` → proceed to Step 5 (abort path).
- `pause` → proceed to Step 6 (pause path).
- anything else → print `"abort cancelled, nothing changed"` and exit. Do NOT fuzzy-match — abort is the second-most-destructive command in the harness (after `/harness:rewind`), and an accidental "abort the build please" should not match.

### Step 5: Abort path

**5a. Stash uncommitted work in the worktree:**

```bash
if [ -d ".worktrees/current" ]; then
  cd .worktrees/current
  # -u includes untracked files; -m tags the stash so the user can find it
  git stash push -u -m "harness-abort-$(date +%Y%m%dT%H%M%S)" 2>/dev/null || true
  cd -
fi
```

The `|| true` covers the case where there's nothing to stash (clean worktree); we don't want a clean worktree to fail the abort.

**5b. Move transient files to `.aborted/TIMESTAMP/`:**

The orchestrator computes `TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)` (UTC), creates `.harness/features/${FEATURE}/.aborted/${TIMESTAMP}/` via `mkdir -p`, and moves these files in if they exist:

- `.harness/features/${FEATURE}/pause-questions.md`
- `.harness/design/audits/.last-designer-stdout.txt` (the audit-gate's stdout capture buffer; if mid-audit when aborted, the partial buffer is forensic)

The orchestrator writes `.harness/features/${FEATURE}/.aborted/${TIMESTAMP}/ABORT-MANIFEST.md` recording: phase at abort, retry_count at abort, estimated_cost_usd at abort, list of files moved, list of stash entries created, the user's reason if provided.

**5c. Reset manifest state to the last clean checkpoint:**

The "last clean checkpoint" is the most recent phase that fully completed. The orchestrator infers this from `.harness/progress/changelog.md` (each `## YYYY-MM-DD — features/NNN — <phase>` heading marks a phase completion event) plus the in-memory state:

| Current phase at abort | Last clean checkpoint phase |
|---|---|
| `planning` | n/a — no prior phase. Set `phase = "planning"`, leave files; effectively a no-op except for stash. |
| `analyzing` | `planning` (PRD/architecture/contract were written) |
| `negotiating` | `analyzing` (analysis-report.md was written) |
| `building` | `negotiating` (final contract has the `**Negotiated**:` marker) |
| `evaluating` | `building` (implementation-report.md was written) |
| `retrospective` | `evaluating` (eval-report.md exists with a verdict) |

Using the Edit tool on `.harness/manifest.yaml`:
- `state.phase` = the last clean checkpoint phase from the table above
- `state.retry_count` = 0 (abort resets the retry budget — if the user resumes, they get a fresh budget)
- `state.negotiation_round` = 0
- `state.last_session` = current ISO timestamp

`state.current_feature` is **NOT** cleared — the feature folder stays so the user can resume. (Use `/harness:rewind planning` to fully start over.)

`state.estimated_cost_usd` is **NOT** reset — the abort doesn't refund the tokens already spent. If the user resumes, the running total continues; if they abandon entirely, the field accurately reflects what this attempt cost.

**5d. Log:**

Append to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Abort
- From phase: [previous phase]
- To phase:   [last clean checkpoint phase]
- Retry count at abort: [N] of [max]
- Estimated cost at abort: ~$[X.XX]
- Stash: harness-abort-TIMESTAMP (in .worktrees/current/)
- Forensics: .harness/features/NNN/.aborted/TIMESTAMP/
- Reason: [if user provided]
```

**5e. Tell the user what's next:**

```
═══════════════════════════════════════════════════════════════
  Harness — Abort Complete
═══════════════════════════════════════════════════════════════
Feature ${FEATURE} reset to phase: ${LAST_CLEAN_PHASE}
Stashed work:    git -C .worktrees/current stash list
Forensics:       .harness/features/${FEATURE}/.aborted/${TIMESTAMP}/
Cost this run:   ~$${ESTIMATED_COST_USD}

Next options:
  • /harness:resume           — pick up from ${LAST_CLEAN_PHASE} with a
                                 fresh retry budget
  • /harness:rewind planning  — throw the whole feature out and replan
                                 (more destructive than abort)
  • Edit something first (e.g., /harness:edit "<change>") then resume
═══════════════════════════════════════════════════════════════
```

### Step 6: Pause path

**6a. Update manifest (touch only `last_session`):**

Using the Edit tool on `.harness/manifest.yaml`:
- `state.last_session` = current ISO timestamp.

Everything else is left as-is — this is the whole point of pause: state is intact, so `/harness:resume` picks up exactly where it left off.

**6b. Log (lighter than abort):**

Append to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Pause
- Phase at pause: [phase]
- Retry count at pause: [N] of [max]
- Estimated cost at pause: ~$[X.XX]
```

**6c. Tell the user what's next:**

```
═══════════════════════════════════════════════════════════════
  Harness — Paused
═══════════════════════════════════════════════════════════════
Feature ${FEATURE} paused at phase: ${PHASE}
Retry count: ${RETRY_COUNT}/${MAX_RETRIES}  (preserved)
Cost so far: ~$${ESTIMATED_COST_USD}

Resume with: /harness:resume
═══════════════════════════════════════════════════════════════
```

## Notes

- Abort and pause are user-invoked only. Neither is auto-fired by the harness — even on cap-exhaustion, the harness presents options and lets the user choose.
- Abort does NOT push to remote, does NOT delete branches, does NOT remove worktrees. Worktree removal is part of the merge step (Step 5b in sprint.md); abort leaves the worktree in place so the user can inspect it.
- The stash created by abort uses a tagged message (`harness-abort-TIMESTAMP`) so it's findable. To recover: `cd .worktrees/current && git stash list` then `git stash apply stash@{N}` (or `pop` to apply-and-drop).

## Anti-patterns

- **Aborting because the first negotiation round looked weird** — the negotiation loop is allowed up to 3 rounds; let it run. If round 3 escalates to human, that's the right escalation.
- **Aborting and then immediately running `/harness:rewind planning`** — `/harness:rewind planning` already does a destructive reset. Pick one or the other.
- **Using `pause` as a way to skip a phase** — pause is just exit-and-resume. To skip a phase, use `/harness:rewind` to go BACK, edit, and resume forward.
