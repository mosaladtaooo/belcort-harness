---
description: Targeted spec amendment via a fresh Planner subagent. User gives a one-line change request; Planner produces before→after patches; orchestrator shows diffs; user confirms per-patch; orchestrator mechanically applies approved patches.
argument-hint: "<the change, 1-2 sentences>"
---

# `/harness:amend` — Safe spec amendment

For changing something in the spec after the Planner has finished but before the feature ships. The request is `$ARGUMENTS`. If empty, ask what to change.

## Why fresh-subagent patching?

Before this command, adjusting a plan meant typing the change into chat, where the orchestrator would `Edit` spec files directly. At that moment the orchestrator's context contained every prior message — noise bled into spec files, subsequent agents inherited the noise. The rule: the orchestrator never authors spec content. Every character of every spec edit is produced by a fresh Planner subagent with clean context. The orchestrator only shows diffs and mechanically applies approved ones.

See SKILL.md § File Ownership Contract.

## When to use

- At the human approval gate (before negotiate).
- During negotiate (if issues surface).
- During building (rare — usually `/harness:rewind negotiating` is cleaner).
- Between features (to evolve the spec).

## When NOT to use

- Ambiguity resolution → `/harness:clarify`.
- Fundamental direction change → `/harness:rewind planning`.
- Post-merge drift → `/harness:retrospective`.
- Multi-file coordinated change → `/harness:edit`.
- Constitution change → `/harness:constitution-amend`.

## Procedure

### Step 1: Precondition check

The orchestrator reads `.harness/manifest.yaml` to get `state.current_feature` (call this `${FEATURE}`). Verify `.harness/features/${FEATURE}/contract.md` exists. If not, tell the user "No draft contract for ${FEATURE}. Run /harness:sprint first." and exit.

If the contract already has the `**Negotiated**:` marker (negotiation complete), warn the user: "This contract was finalized through negotiation. Applying an amendment will require re-running `/harness:negotiate` to propagate changes. Continue?" On no → exit. On yes → continue; flag in changelog later.

### Step 2: Dispatch fresh Planner in AMEND mode

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Amend spec: <short summary of $ARGUMENTS>"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in AMEND mode (see your system prompt's MODE ROUTING table).
>
> The user wants this specific change applied to the spec:
> $ARGUMENTS
>
> Read the current spec via Read tool (paths: .harness/spec/prd.md, architecture.md, constitution.md, .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md). Produce structured before→after patches to .harness/features/${FEATURE}/amend-patches.md per your AMEND mode procedure. Do NOT apply patches — the orchestrator applies after user confirmation.

### Step 3: Read patches, present to user

Orchestrator reads `.harness/features/${FEATURE}/amend-patches.md` and presents:

```
═══════════════════════════════
  Harness — Amendment Preview
═══════════════════════════════
Request: ${ARGUMENTS}

Planner's interpretation: [1-3 sentences from the patches file]

Impact:
  - Modifies: [list of files]
  - Unclear: [UNCLEAR items, if any]
  - Out of scope: [OOS items, if any]

Patches:
  [1] spec/prd.md § FR-003 — [short title]
  [2] spec/architecture.md § ... — [short title]
  [3] features/${FEATURE}/contract.md § ... — [short title]

For each patch, show the before/after diff.

Apply all / Apply some / Apply none / Show diff N / Cancel?
═══════════════════════════════
```

### Step 4: Apply approved patches

For each patch the user approves, the orchestrator uses the Edit tool with the patch's `old_string` and `new_string`. The patch content was authored by the fresh Planner subagent; the orchestrator is performing a mechanical apply, not authoring.

### Step 5: Run analyze

Invoke `/harness:analyze`. CRITICAL findings → report + offer rollback or follow-up amendment.

### Step 6: Re-negotiation warning (if contract was FINAL)

If Step 1 detected a finalized contract and the amendment modified it, tell the user: "Amendment applied to a previously-negotiated contract. The Generator's proposal and Evaluator's review may no longer match. Run `/harness:negotiate` to re-negotiate before building." Do NOT auto-run negotiate.

### Step 7: Log ADR

Orchestrator appends to `.harness/progress/decisions.md` (using Edit tool). Use the template at `@templates/progress/decisions.md`:

```markdown
## ADR-NNN — Amendment: [short title]
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE}
**Status**: Accepted

### Context
User requested: "${ARGUMENTS}"

### Decision
Amended: [list of files modified]
Patches applied: [N] of [proposed M]

### Consequences
- [What changed in the spec]
- [Downstream: re-negotiate required / none / etc.]
```

### Step 8: Update changelog

Orchestrator appends to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — features/NNN — Amendment applied
- Request: "${ARGUMENTS}"
- Patches applied: [N]
- Files modified: [list]
- Post-analyze: [PASS/WARN/CRITICAL]
- Re-negotiate required: [yes/no]
```

## Anti-patterns

- **Chat-then-amend**: typing the change into chat first, then running `/harness:amend`. Run `/harness:amend` as the FIRST response to user feedback — don't discuss first, or the discussion pollutes subsequent context.
- **Batch amendments**: "change X, and also Y, and while we're at it Z" → run three separate amendments.
- **Skipping analyze**: step 5 isn't optional.
- **Amending post-build**: use `/harness:retrospective` instead.
- **Treating UNCLEAR flags as minor**: resolve them (perhaps via `/harness:clarify`) before applying.

## Files written

| File | Writer |
|---|---|
| `.harness/features/NNN/amend-patches.md` | Planner AMEND mode |
| `spec/*.md` (or contract.md) | Orchestrator applies Planner patches via Edit |
| `progress/decisions.md` | Orchestrator appends ADR |
| `progress/changelog.md` | Orchestrator appends |
