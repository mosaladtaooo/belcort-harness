---
description: Post-plan structured clarification — surface ambiguities the Planner found in the spec, collect user answers, produce surgical spec patches. Runs before the human approval gate so ambiguities are resolved before negotiation. Answers flow through files (clarifications.md), never through orchestrator chat — keeps spec files clean of conversational noise.
---

# `/harness:clarify` — Post-plan structured clarification

Runs AFTER the Planner finishes and BEFORE the human approves. Surfaces ambiguities the Planner couldn't confidently resolve, captures user answers in `.harness/features/NNN/clarifications.md`, and applies them to the spec via a fresh Planner subagent — NEVER via orchestrator edits.

## Why this exists

The Planner works from a 1–4 sentence prompt. It has to make dozens of implicit decisions: is search case-sensitive? should signup support social providers? what's the pagination default? If the Planner guesses silently, those guesses become spec reality and the Generator builds against them. If the Planner refuses to guess, it asks — but asking dozens of questions inline during planning bloats the planner's context and produces worse specs overall.

`/harness:clarify` is the dedicated Q&A channel. The Planner batches its ambiguities into a structured file, the human answers once, answers flow back through files into spec patches. **Critically, the orchestrator never edits the spec directly** — the Planner does it with clean context. This is the file-ownership contract from [SKILL.md § File Ownership Contract](../skills/harness/SKILL.md).

## When it runs

- **Manually**: you read the Planner's output, feel unsure about something, run `/harness:clarify` to surface everything the Planner was also unsure about.
- **Automatically suggested**: at the human approval gate in [sprint.md](sprint.md), if the Planner self-reports ≥3 ambiguities, the orchestrator suggests running clarify before approval.

## Procedure

### Step 0: Phase guard (FR-2)

Set the phase so the FR-2 spec-ownership hook authorizes the orchestrator's `Edit` calls in Step 6. Without this, the hook blocks patch application as an unauthorized orchestrator-side spec edit.

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_set "clarifying"
```

The phase persists across tool calls via `manifest.yaml`. Restored at Step Final.

### Step 1: Precondition check

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

# Must have a draft contract — clarify only makes sense post-planning
[ -f ".harness/features/${FEATURE}/contract.md" ] || {
  echo "No draft contract for ${FEATURE}. Run /harness:sprint first."
  exit 1
}
```

If no feature is active, tell the user to run `/harness:sprint` first.

### Step 2: Dispatch Planner in CLARIFY-QUESTIONS mode

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in CLARIFY-QUESTIONS mode (see your system prompt's MODE ROUTING table).

You have already written the spec. Now identify ambiguities — places where you made an implicit decision the user might want to override, or gaps where you had to pick a default without enough information.

Read via Read tool:
- .harness/spec/prd.md
- .harness/spec/architecture.md
- .harness/features/${FEATURE}/contract.md

Write 3–10 structured questions to .harness/features/${FEATURE}/clarifications.md using the template defined in your MODE: CLARIFY-QUESTIONS section. Do NOT edit any spec file. Do NOT write code. Only clarifications.md." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/planner.md" \
  --allowedTools "Read,Write"
```

### Step 3: Read the questions, present to the user

Read `.harness/features/${FEATURE}/clarifications.md`. Present the questions interactively — one at a time, with the Planner's suggested default for each. Format:

```
═══════════════════════════════
  Harness — Clarification Round
═══════════════════════════════
Planner identified N ambiguities in the spec.

Q1/N: [Question]
  Context: [Why this is ambiguous]
  Suggested default: [What the Planner would pick]

Your answer (or "accept" for the suggested default, or "skip" to leave ambiguous):
_
```

After each answer, append to `clarifications.md` under the relevant question:

```
### Q1 — [question title]
**Asked**: [original question text]
**Context**: [why it mattered]
**Suggested default**: [what Planner proposed]
**User answer**: [verbatim answer, or "accepted default", or "skipped"]
```

If user says `skip` on all → abort with "no changes to apply".

### Step 4: Dispatch Planner in CLARIFY-APPLY mode

Only if at least one question was answered (not all skipped):

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in CLARIFY-APPLY mode (see your system prompt's MODE ROUTING table).

Read via Read tool:
- .harness/features/${FEATURE}/clarifications.md (contains user answers)
- .harness/spec/prd.md
- .harness/spec/architecture.md
- .harness/features/${FEATURE}/contract.md

For every question that has a user answer (not 'skipped', not 'accepted default' unless the default requires spec text you didn't write before), produce a patch that updates the spec file to reflect the answer. Write all patches to .harness/features/${FEATURE}/clarify-patches.md per your MODE: CLARIFY-APPLY template. Do NOT write to spec files directly in this mode. Only clarify-patches.md." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/planner.md" \
  --allowedTools "Read,Write"
```

### Step 5: Present the patches to the user

Read `clarify-patches.md`. Show each patch as a diff (before/after) with context. Ask: "Apply these N patches?" User can:
- `yes` → apply all
- `no` → discard, patches stay on disk for record
- Select specific patches by number (`yes 1,3,4`) — apply only those

### Step 6: Apply approved patches

For each approved patch, apply the before→after edit using the `Edit` tool. The orchestrator is performing a mechanical apply, not authoring — the Planner wrote the exact before/after strings, the orchestrator just executes them.

This is the ONE exception to the "orchestrator does not edit spec files" rule, and it's safe specifically because:
1. The patch content came from a fresh Planner subagent with clean context
2. Each patch is a pre-computed before→after pair with no interpretation
3. The user approved the patches explicitly

### Step 7: Run `/harness:analyze`

After applying, automatically invoke the [analyze.md](analyze.md) procedure. If CRITICAL findings appear (e.g., the clarifications broke constitution compliance), report them and offer to rollback via `git checkout spec/`.

### Step 8: Update the feature folder and manifest

- Mark clarifications.md with a "Resolved: YYYY-MM-DD" line at the top
- Append a changelog entry:
  ```
  ## YYYY-MM-DD — features/NNN — Clarifications applied
  - Questions answered: [N]
  - Patches applied: [N]
  - Files modified: [list]
  ```

### Step 9: Back to the human gate

Tell the user the spec has been updated. They can now:
- Review the updated spec files and approve to continue to negotiate
- Run `/harness:clarify` again if the clarifications revealed new ambiguities
- Run `/harness:amend "<specific change>"` if they want to make a targeted tweak
- Run `/harness:rewind planning` if clarifications revealed a fundamentally wrong direction

### Step Final: Restore phase (FR-2)

Restore the previous phase so subsequent orchestrator activity reverts to the default hook posture.

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_restore
```

Run on every exit path (early skip-all, no-changes-to-apply, post-apply success). The guard is idempotent.

## Anti-patterns

- **Skipping step 7 (analyze)** — clarifications can introduce inconsistency (e.g., a Q&A tightens an AC but the architecture no longer supports it). Always re-analyze.
- **Clicking "yes" without reading the diff** — the whole point is human approval. If the diff is long, ask the user to take their time.
- **Editing clarifications.md directly as the orchestrator** — the questions and suggested defaults are the Planner's work product. The orchestrator only *appends user answers*.
- **Running clarify multiple times without applying** — each run overwrites the previous questions file. If the user answers Q1-Q5 then re-runs clarify, those answers are gone. Warn the user before re-running.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `.harness/features/NNN/clarifications.md` | Planner CLARIFY-QUESTIONS (questions) + orchestrator (user answers appended) | feature-scoped, kept as record |
| `.harness/features/NNN/clarify-patches.md` | Planner CLARIFY-APPLY | feature-scoped, kept as record of what was proposed |
| `spec/*.md` | Orchestrator applies Planner-authored patches via Edit | updated in place |
| `progress/changelog.md` | Orchestrator append | append-only |
