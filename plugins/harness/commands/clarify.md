---
description: Post-plan structured clarification — surface ambiguities the Planner found in the spec, collect user answers, produce surgical spec patches. Runs before the human approval gate so ambiguities are resolved before negotiation. Answers flow through files (clarifications.md), never through orchestrator chat — keeps spec files clean of conversational noise.
---

# `/harness:clarify` — Post-plan structured clarification

Runs AFTER the Planner finishes and BEFORE the human approves. Surfaces ambiguities the Planner couldn't confidently resolve, captures user answers in `.harness/features/NNN/clarifications.md`, and applies them to the spec via a fresh Planner subagent — NEVER via orchestrator edits.

## Why fresh-subagent Q&A?

The Planner works from a 1–4 sentence prompt; dozens of implicit decisions go unspoken (case-sensitivity, pagination defaults, provider choices). If the Planner guesses silently, those guesses become spec reality. If the Planner asks inline during planning, the context bloats and the spec degrades.

`/harness:clarify` is the dedicated Q&A channel. One fresh Planner collects ambiguities into a file; the human answers once; a second fresh Planner turns answers into surgical patches. The orchestrator never authors spec content — it only appends user answers and mechanically applies approved patches.

See SKILL.md § File Ownership Contract.

## When to use

- Manually: after reading the draft contract, when something feels unresolved.
- Automatically suggested: the sprint flow proposes clarify when the Planner self-reports ≥3 ambiguities.

## When NOT to use

- Single targeted wording change → `/harness:amend`.
- Fundamental direction change → `/harness:rewind planning`.
- Multi-file cascade change → `/harness:edit`.
- Constitution change → `/harness:constitution-amend`.

## Procedure

### Step 1: Precondition check

The orchestrator reads `.harness/manifest.yaml` to get `state.current_feature` (call this `${FEATURE}`). Verify `.harness/features/${FEATURE}/contract.md` exists. If not, tell the user "No draft contract for ${FEATURE}. Run /harness:sprint first." and exit.

### Step 2: Dispatch fresh Planner in CLARIFY-QUESTIONS mode

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Surface ambiguities for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in CLARIFY-QUESTIONS mode. Read spec/prd.md, spec/architecture.md, .harness/features/${FEATURE}/contract.md via Read tool. Identify 3-10 genuine ambiguities in the current spec. Write structured questions to .harness/features/${FEATURE}/clarifications.md per your CLARIFY-QUESTIONS mode template (each Q with target, location, question, context, suggested default, why it matters). Cap at 10 — if more, flag as spec-fundamentally-under-determined.

### Step 3: Present questions to user, collect answers

The orchestrator reads `.harness/features/${FEATURE}/clarifications.md` and presents the questions one at a time:

```
═══════════════════════════════
  Harness — Clarification Round
═══════════════════════════════
Planner identified N ambiguities in the spec.

Q1/N: [question text]
  Context: [why this is ambiguous]
  Suggested default: [what the Planner would pick]
  Why it matters: [downstream impact]

Your answer (or "accept" for the suggested default, or "skip" to leave ambiguous):
_
```

For each question answered, the orchestrator uses the `Edit` tool to append a `**User answer:**` block under that question in `clarifications.md`. Verbatim answers only — no orchestrator paraphrasing. If the user says `skip` on every question, abort with "No answers collected; nothing to apply."

### Step 4: Dispatch fresh Planner in CLARIFY-APPLY mode

Only if at least one question has a non-skipped user answer, the orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Apply clarifications for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in CLARIFY-APPLY mode. Read .harness/features/${FEATURE}/clarifications.md — the user has filled in **User answer:** for each question. Produce surgical before→after patches to .harness/features/${FEATURE}/clarify-patches.md per your CLARIFY-APPLY mode template. Do NOT apply — orchestrator does that after user confirmation.

### Step 5: Read patches, present to user

Orchestrator reads `.harness/features/${FEATURE}/clarify-patches.md` and shows each patch as a before/after diff:

```
═══════════════════════════════
  Harness — Clarification Patches
═══════════════════════════════
Questions answered: N
Patches proposed: M

Patches:
  [1] spec/prd.md § FR-003 — [short title]
  [2] spec/architecture.md § ... — [short title]
  [3] features/${FEATURE}/contract.md § ... — [short title]

Apply all / Apply some (list numbers) / Apply none / Show diff N / Cancel?
═══════════════════════════════
```

### Step 6: Apply approved patches

For each approved patch, the orchestrator uses the `Edit` tool with the patch's `old_string` and `new_string`. The patch content was authored by the fresh Planner subagent; the orchestrator is performing a mechanical apply, not authoring.

### Step 7: Run analyze

Invoke `/harness:analyze`. Clarifications can introduce inconsistency (e.g., a Q&A tightens an AC but architecture no longer supports it). CRITICAL findings → report + offer rollback or follow-up amendment.

### Step 8: Mark clarifications resolved + log changelog

Orchestrator uses `Edit` tool to add `Resolved: YYYY-MM-DD` at the top of `clarifications.md`, then appends to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Clarifications applied
- Questions answered: [N]
- Patches applied: [N of M]
- Files modified: [list]
- Post-analyze: [PASS/WARN/CRITICAL]
```

### Step 9: Back to the human gate

Tell the user the spec has been updated. They can now review and approve to continue to negotiate, run clarify again if new ambiguities surfaced, run `/harness:amend "<tweak>"` for a targeted change, or `/harness:rewind planning` if clarifications revealed a wrong direction.

## Anti-patterns

- **Skipping analyze**: step 7 isn't optional. Clarifications propagate in unexpected ways.
- **Orchestrator paraphrasing user answers**: append verbatim. Paraphrasing is authoring.
- **Re-running clarify without applying**: each CLARIFY-QUESTIONS dispatch overwrites the questions file. Unapplied answers are lost. Warn the user before re-running.
- **Clicking "yes" on diffs without reading**: the whole point is human approval.

## Files written

| File | Writer |
|---|---|
| `.harness/features/NNN/clarifications.md` | Planner CLARIFY-QUESTIONS writes questions; orchestrator appends `**User answer:**` blocks |
| `.harness/features/NNN/clarify-patches.md` | Planner CLARIFY-APPLY |
| `spec/*.md` / `contract.md` | Orchestrator applies Planner patches via Edit |
| `progress/changelog.md` | Orchestrator appends |
