---
description: Targeted spec amendment via a fresh Planner subagent. User gives a one-line change request, Planner produces before→after patches, orchestrator shows diffs, user confirms per-patch, patches applied mechanically. NEVER edits spec from orchestrator's own context. Solves the "post-plan tweak pollutes the pipeline" failure mode.
argument-hint: "<the change you want to make, one or two sentences>"
---

# `/harness:amend` — Safe spec amendment

For when you want to change something in the spec *after* the Planner has finished but before the feature ships. The change request is `$ARGUMENTS`. If empty, ask the user what they want to change first.

## Why this exists (the problem it fixes)

Before this command, the natural way to adjust a plan was to say it in chat:

> "Make the search case-insensitive and pagination default to 20."

The orchestrator would then use `Edit` to modify spec files. But at that moment, the orchestrator's context contained the entire session transcript — every earlier message, tool result, harness-state injection, Planner output. When it wrote into `spec/architecture.md`, it didn't just write the tweak, it wrote *with the whole transcript as implicit context*. Noise bled into files. Subsequent agents inherited the noise. Quality degraded.

**The single rule that prevents this:** the orchestrator does NOT author spec content. Every character of every spec edit is produced by a fresh Planner subagent with clean context. The orchestrator only shows diffs and mechanically applies approved ones.

See [SKILL.md § File Ownership Contract](../skills/harness/SKILL.md) for the full contract.

## When it runs

**Invoke manually** any time after planning, including:

- At the human approval gate (before negotiate)
- During negotiate (if the negotiation surfaces spec issues)
- During building (rare — usually better to `/harness:rewind negotiating` first)
- Between features (to evolve the spec for future work)

**Do NOT use for:**
- Clarifying ambiguities → use `/harness:clarify` (batches multiple questions)
- Mid-build implementation nudges → use `/harness:steer`
- Fundamental direction changes → use `/harness:rewind planning`
- Spec drift after the feature is done → use `/harness:retrospective`
- One-line text fixes with no downstream impact → direct manual edit is fine

## Procedure

### Step 0: Phase guard (FR-2)

Set the phase so the FR-2 spec-ownership hook authorizes the orchestrator's `Edit` calls in Step 4. Without this, the hook will block the patch application as an unauthorized orchestrator-side spec edit.

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_set "amending"
```

The phase persists in `manifest.yaml` across this command's tool calls. It's restored to the prior value at Step Final (success OR failure path).

### Step 1: Precondition check

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
PHASE=$(grep 'phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')

[ -f ".harness/features/${FEATURE}/contract.md" ] || {
  echo "No draft contract for ${FEATURE}. Run /harness:sprint first."
  exit 1
}
```

If the contract already has the `**Negotiated**:` marker (negotiation complete), tell the user:

> "The contract for ${FEATURE} has been finalized through negotiation. Applying an amendment will require re-running `/harness:negotiate` to propagate changes to the negotiated proposal and review. Continue anyway?"

If they say no → exit. If they say yes → continue and flag in the changelog.

### Step 2: Dispatch fresh Planner in AMEND mode

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in AMEND mode (see your system prompt's MODE ROUTING table).

The user wants this specific change applied to the spec:
$ARGUMENTS

Read the current spec via Read tool (paths: .harness/spec/prd.md, architecture.md, constitution.md, .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md). Produce structured before→after patches to .harness/features/${FEATURE}/amend-patches.md per your AMEND mode procedure. Do NOT apply patches — the orchestrator applies after user confirmation." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

The Planner interprets the request, identifies which files need to change, and writes a structured patch set to `.harness/features/${FEATURE}/amend-patches.md`.

### Step 3: Read the patches and present them

Read `.harness/features/${FEATURE}/amend-patches.md`. It contains:

- A top-level summary of the interpretation (the Planner's understanding of the request)
- A list of impacted files and why
- One or more structured patches with before/after diffs
- Any "UNCLEAR" or "OUT-OF-SCOPE" flags the Planner raised

Present to the user in this format:

```
═══════════════════════════════
  Harness — Amendment Preview
═══════════════════════════════
Request: ${ARGUMENTS}

Planner's interpretation:
  [1–3 sentence summary of what it understood]

Impact:
  - Modifies: [list of files]
  - Unclear: [any items the Planner flagged as ambiguous]
  - Out of scope: [items the Planner deemed outside amendment scope]

Patches:
  [1] spec/prd.md § FR-003 — add case-insensitivity to search ACs
  [2] spec/architecture.md § Architectural Style — note lowercase index
  [3] features/${FEATURE}/contract.md § Test Criteria — add AC-003-3

For each patch, show the before/after diff, then prompt:

Apply all / Apply some / Apply none / Show diff N / Cancel?
═══════════════════════════════
```

### Step 4: Apply approved patches

For each patch the user approves, apply using `Edit`. The patch's `old_string` and `new_string` were written by the Planner — the orchestrator is performing a mechanical apply, not authoring.

This is the SAME safe-apply principle as `/harness:clarify`. It works because:
1. Patch content came from a fresh Planner subagent (clean context)
2. Each patch is a pre-computed before→after pair
3. The user approved it

### Step 5: Run `/harness:analyze`

After applying, invoke the [analyze.md](analyze.md) procedure automatically. If CRITICAL findings appear:

- Report them to the user
- Offer to rollback: `git checkout -- spec/ features/${FEATURE}/contract.md`
- OR continue and address them manually via another `/harness:amend` or `/harness:edit`

### Step 6: If contract was FINAL, suggest re-negotiation

If the precondition check in Step 1 found a finalized contract, and the amendment modified it, tell the user:

> "Amendment applied to a previously-negotiated contract. The Generator's proposal and Evaluator's review may no longer match. Run `/harness:negotiate` to re-negotiate before building."

Do NOT auto-run negotiate — that's a user decision (it costs subagent dispatches).

### Step 7: Log the amendment as an ADR

Append to `.harness/progress/decisions.md`:

```
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
- [Any downstream implications — re-negotiate, re-build, etc.]
```

Amendments are significant design changes — they belong in the ADR log so the retrospective can reference them.

### Step 8: Update the changelog

```
## YYYY-MM-DD — features/NNN — Amendment applied
- Request: "${ARGUMENTS}"
- Patches applied: [N]
- Files modified: [list]
- Post-analyze: [PASS/WARN/CRITICAL]
- Re-negotiate required: [yes/no]
```

### Step Final: Restore phase (FR-2)

Restore the previous phase so subsequent orchestrator activity reverts to the default hook posture (spec edits blocked).

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_restore
```

Run this even on early-exit paths (e.g., the user cancels in Step 3, the precondition check fails in Step 1). The guard is idempotent — calling it without a prior `phase_set` is a no-op.

## Anti-patterns

- **Chat-then-amend pattern**: typing the change into chat, discussing it, THEN running `/harness:amend` — the discussion is already in the orchestrator's context and may leak into the Planner's dispatch via implicit context. Run `/harness:amend` as the first response to user feedback. Don't discuss first.
- **Batch amendments**: `/harness:amend "change X, and also Y, and while we're at it Z"` — the Planner will try to interpret all three but context may smear. Prefer one amendment per invocation for isolated changes.
- **Skipping analyze**: step 5 is not optional. Amendments routinely introduce inconsistencies.
- **Amending post-build**: if the feature is built and passed evaluation, use `/harness:retrospective` to capture drift instead — an amendment after the fact doesn't rebuild the code to match.
- **Treating unclear flags as minor**: if the Planner flagged something as UNCLEAR or OUT-OF-SCOPE in its patches, treat that as a real signal. Resolve it (perhaps via `/harness:clarify`) before applying.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `.harness/features/NNN/amend-patches.md` | Planner AMEND mode | feature-scoped, kept as record of proposed changes |
| `spec/*.md` (and/or contract.md) | Orchestrator applies Planner-authored patches via `Edit` | updated in place |
| `progress/decisions.md` | Orchestrator appends ADR | append-only |
| `progress/changelog.md` | Orchestrator appends | append-only |
