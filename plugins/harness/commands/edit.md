---
description: Cascade-aware spec edit via a fresh Planner subagent. User states a change; the Planner identifies every file it affects (architecture, init.sh, NFRs, contract) and produces a coordinated patch set; orchestrator shows diffs, user approves per-file, patches applied mechanically. Follows the same "orchestrator doesn't author spec content" rule as /harness:amend but emphasises cross-file cascade propagation.
argument-hint: "<what to change, 1-3 sentences>"
---

# `/harness:edit` — Cascade-aware spec edit

For targeted spec changes that ripple across multiple files — e.g., swapping databases, changing a framework, tightening an NFR. The change request is `$ARGUMENTS`. If empty, ask what to change.

## How this differs from `/harness:amend`

| | `/harness:amend` | `/harness:edit` |
|---|---|---|
| Intent | Change WHAT (FRs, ACs, product behaviour) | Change HOW the spec describes cross-file concerns |
| Typical use | "make search case-insensitive" | "swap SQLite for PostgreSQL" |
| Files touched | Usually 1 (PRD or contract) | Typically 3+ (architecture + NFRs + init.sh + etc.) |
| Cascade awareness | Minimal | Primary concern |

They share the same safety property: **the orchestrator does NOT author spec content**. Both commands dispatch a fresh Planner subagent to produce before→after patches; the orchestrator only shows diffs and mechanically applies on confirmation.

If in doubt, use `/harness:amend`. Use `/harness:edit` when you already know the change will touch multiple files and you want the Planner to be explicitly cascade-aware.

## Why this matters (the problem it fixes)

Previously, `/harness:edit` was documented as "apply the change surgically — only modify the affected sections", which the orchestrator carried out using its own `Edit` tool. This violated the File Ownership Contract introduced in v1.3 — the orchestrator's chat context leaked into spec edits, and cross-file consistency had no explicit mechanism.

This PR rewrites `/harness:edit` to match the amend/clarify pattern: subagent-authored patches + orchestrator-applied + auto-analyzed.

## Procedure

### Step 0: Phase guard (FR-2)

Set the phase so the FR-2 spec-ownership hook authorizes the orchestrator's mechanical `Edit` calls in Step 4. Without this, the hook blocks patch application across the multiple files that an edit typically touches.

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_set "editing"
```

Restored at Step Final.

### Step 1: Precondition check

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')

# /harness:edit works even without an active feature (you may be editing the constitution or global spec between features).
# Warn if there's a build in progress — edits to architecture mid-build are dangerous.
PHASE=$(grep 'phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')
if [ "$PHASE" = "building" ] || [ "$PHASE" = "evaluating" ]; then
  echo "⚠ Phase is $PHASE. Editing spec files now will diverge from what the Generator is building."
  echo "  Consider /harness:rewind first. Continue anyway?"
fi
```

### Step 2: Dispatch fresh Planner with the edit request

The dispatch is identical in shape to `/harness:amend`'s but the instruction emphasises cascade analysis:

```bash
CLAUDE_SUBAGENT=1 claude -p "You are being dispatched in EDIT mode (cascade-aware spec edit; note: this mode is currently driven by instruction since planner.md does not yet have a dedicated MODE: EDIT section — treat it as an AMEND-like flow with explicit cascade emphasis).

The user wants this change (expected to touch MULTIPLE files):
$ARGUMENTS

Read the current spec via Read tool (paths to check: .harness/spec/prd.md, architecture.md, constitution.md; .harness/features/${FEATURE:-global}/contract.md if exists; .harness/evaluator/criteria.md; .harness/init.sh).

Your job:
1. Identify EVERY file affected by the requested change.
2. For each file, draft a before→after patch.
3. If a downstream file (e.g., init.sh, NFR metric, test criteria) exists only because of a choice the edit is reversing, flag that the downstream file may need to be rewritten entirely rather than patched — do NOT produce a patch for it yourself; flag it in an UNCLEAR section.

Write all patches to .harness/features/${FEATURE:-global}/edit-patches.md. Do NOT apply patches — the orchestrator applies after user confirmation." \
  --append-system-prompt-file "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

The Planner's default MODE is PLAN, so the `--- MODE: EDIT ---` marker here is interpreted by the instruction block rather than a dedicated mode section in `planner.md`. If a future PR promotes EDIT to a first-class mode in `planner.md` (parallel to AMEND), update this dispatch to match. For now the inline instruction is sufficient.

### Step 3: Present the patches

Read `edit-patches.md`. Unlike amend (which typically has 1–3 patches), edit outputs may have 5–10 patches across files. Present them grouped by file:

```
═══════════════════════════════
  Harness — Edit Preview
═══════════════════════════════
Request: ${ARGUMENTS}

Planner's interpretation:
  [1-2 sentence summary]

Affected files ([N]):
  • spec/architecture.md — [N patches]
  • .harness/init.sh — [N patches]
  • spec/prd.md (NFR-002) — [N patches]
  • features/${FEATURE}/contract.md — [N patches]

Unclear items ([N]):
  • [each item — file, reason, suggested resolution]

Out-of-scope items ([N]):
  • [each item]

Commands:
  all        — apply every patch (review first by 'diff all')
  diff N     — show the Nth patch's diff
  diff FILE  — show all patches targeting FILE
  apply N    — apply only patch N
  apply FILE — apply all patches for FILE
  skip       — discard; patches remain in edit-patches.md for reference
  cancel     — exit without applying anything
═══════════════════════════════
```

### Step 4: Apply approved patches

Same pattern as amend: use `Edit` tool mechanically. The orchestrator is executing a pre-computed plan written by the Planner in a clean context, not authoring.

### Step 5: Run `/harness:analyze`

Automatic. Cascade edits are *exactly* the case where analyze earns its keep — a change to architecture.md might leave an NFR orphaned, an AC untestable, or a constitution principle violated. If analyze flags a CRITICAL finding, offer to rollback: `git checkout -- <affected files>`.

### Step 6: Log to ADR + changelog

Append an ADR to `progress/decisions.md`:

```
## ADR-NNN — Edit: [short title]
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE:-global}
**Status**: Accepted

### Context
User requested: "${ARGUMENTS}"

### Decision
Edited [N] files; applied [N] of [proposed M] patches.
Affected files: [list]

### Consequences
- [What changed]
- [Downstream: which systems / phases are affected]
- [If phase was building/evaluating: was a rewind needed?]
```

Append to `progress/changelog.md`:

```
## YYYY-MM-DD — [features/NNN or global] — Edit applied
- Request: "${ARGUMENTS}"
- Files modified: [list]
- Patches applied: [N] of [M]
- Analyze result: [PASS / WARN / CRITICAL]
```

### Step Final: Restore phase (FR-2)

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_restore
```

Run on every exit path. Idempotent.

## Anti-patterns

- **Using edit for one-file tweaks**: use `/harness:amend` — edit's machinery is overkill for a single-file change
- **Using edit during active build**: the Generator is already building against the current spec. Spec edits now create divergence. Either `/harness:rewind` first, or wait until evaluation completes.
- **Editing the constitution**: the constitution is effectively immutable after initial Pass 1. If you need to change it, the correct action is to rewind to planning and reinitialise the harness.
- **Orchestrator-authored edits**: DO NOT take the "affected files" list from the preview and run `Edit` yourself with free-form new content. If the Planner's patch for a file is "UNCLEAR", treat that as a signal, not an invitation to improvise.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `features/NNN/edit-patches.md` (or `.harness/edit-patches.md` if no active feature) | Planner EDIT-mode dispatch | kept as record |
| `spec/*.md`, `features/NNN/contract.md`, `init.sh` (whichever apply) | Orchestrator applies Planner-authored patches via `Edit` | updated in place |
| `progress/decisions.md` | Orchestrator appends ADR | append-only |
| `progress/changelog.md` | Orchestrator appends | append-only |

---

**Historical note**: Before this PR, `/harness:edit` was a thin wrapper around the orchestrator's `Edit` tool and relied on the orchestrator to identify affected files and write the edits. That violated the File Ownership Contract (codified in SKILL.md as of v1.3) and had no explicit cascade coordination. This rewrite brings `/harness:edit` into alignment with `/harness:amend` and `/harness:clarify`: subagent-authored patches + orchestrator-applied + auto-analyzed. Backwards-compatible from the user's perspective (same command name, same argument shape); internally restructured.
