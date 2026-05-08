---
description: Cascade-aware spec edit via a fresh Planner subagent. User states a change; the Planner identifies every file it affects (architecture, init.sh, NFRs, contract) and produces a coordinated patch set; orchestrator shows diffs grouped by file, user approves, patches applied mechanically. Follows the same "orchestrator doesn't author spec content" rule as /harness:amend but emphasises cross-file cascade propagation.
argument-hint: "<what to change, 1-3 sentences>"
---

# `/harness:edit` — Cascade-aware spec edit

For spec changes that ripple across multiple files — swapping a database, changing a framework, tightening an NFR. The request is `$ARGUMENTS`. If empty, ask what to change.

## How this differs from `/harness:amend`

| | `/harness:amend` | `/harness:edit` |
|---|---|---|
| Intent | Change WHAT (FRs, ACs, product behaviour) | Change cross-file concerns |
| Typical use | "make search case-insensitive" | "swap SQLite for PostgreSQL" |
| Files touched | Usually 1 | Typically 3+ |
| Cascade awareness | Minimal | Primary concern |

Both share the safety property: **the orchestrator does NOT author spec content**. Both dispatch a fresh Planner subagent to produce before→after patches; the orchestrator only shows diffs and mechanically applies on confirmation.

If in doubt, use `/harness:amend`. Use `/harness:edit` when you know the change will touch multiple files and want the Planner explicitly cascade-aware.

## When NOT to use

- Single-file tweak → `/harness:amend`.
- Constitution change → `/harness:constitution-amend`.
- Fundamental direction change → `/harness:rewind planning`.
- Post-merge drift reconciliation → `/harness:retrospective`.

## Procedure

### Step 1: Precondition check

The orchestrator reads `.harness/manifest.yaml` for `state.current_feature` (call this `${FEATURE}`; may be absent if editing between features). Also read `state.phase`. If `phase` is `building` or `evaluating`, warn: "Phase is ${PHASE}. Editing spec files now will diverge from what the Generator is building. Consider `/harness:rewind` first. Continue anyway?" Require explicit `yes` to proceed.

### Step 2: Dispatch fresh Planner in EDIT mode

Planner's EDIT mode (see `agents/planner.md § MODE: EDIT`) is the cascade-aware sibling of AMEND: same patch-generation discipline, but the user's intent is expected to touch ≥2 spec files. The Planner reads the full spec + contract + criteria + init.sh, identifies every affected file, and produces coordinated patches grouped by file.

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Cascade edit: <short summary of $ARGUMENTS>"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in EDIT mode (see your system prompt's MODE ROUTING table — EDIT is the unified post-PLAN spec-patches mode).
>
> --- EDIT REQUEST ---
> $ARGUMENTS
>
> --- CONTEXT ---
> Read via Read tool: .harness/spec/prd.md, .harness/spec/architecture.md, .harness/spec/constitution.md (read-only — NEVER patch from this marker), .harness/features/${FEATURE}/contract.md, .harness/evaluator/criteria.md, and .harness/init.sh if relevant.
>
> --- CONSTRAINTS (EDIT-specific) ---
> - Multi-file cascade expected; identify ALL affected files (resist under-scoping). Stack swap → architecture.md + init.sh + relevant NFR section + sometimes evaluator/criteria.md.
> - NEVER patch spec/constitution.md (route via OUT-OF-SCOPE → /harness:constitution-amend).
> - Preserve all IDs.
> - Use Context7 to verify any new framework/library API and that NFRs remain satisfiable.
> - Output: .harness/features/${FEATURE}/edit-patches.md, OR .harness/edit-patches.md (top-level) if state.current_feature is empty. Group patches by file.
>
> Do NOT apply patches.

If `state.current_feature` is empty (editing spec between features), the Planner writes patches to `.harness/edit-patches.md` (top-level) per its EDIT mode template. The orchestrator reads whichever path exists after the dispatch returns.

### Step 3: Present patches grouped by file

The orchestrator reads `.harness/features/${FEATURE}/edit-patches.md`. Unlike amend (1–3 patches), cascade edits commonly produce 5–10 patches. Group by file:

```
═══════════════════════════════
  Harness — Cascade Edit Preview
═══════════════════════════════
Request: ${ARGUMENTS}

Planner's interpretation: [1-3 sentences]

Affected files (N):
  • spec/architecture.md          — [M patches]
  • spec/prd.md (NFR-002)         — [M patches]
  • features/${FEATURE}/contract.md — [M patches]
  • .harness/init.sh              — [M patches]

UNCLEAR items (N):  [file + question]
OUT-OF-SCOPE items (N):  [file + item]

Commands:
  all          — apply every patch
  diff N       — show patch N's before/after
  diff FILE    — show all patches for FILE
  apply N      — apply only patch N
  apply FILE   — apply all patches for FILE
  skip         — discard; patches remain on disk
  cancel       — exit
═══════════════════════════════
```

### Step 4: Apply approved patches

For each approved patch, the orchestrator uses the `Edit` tool with the patch's `old_string` and `new_string`. Mechanical apply — the Planner wrote the exact strings. If a patch is flagged UNCLEAR, do NOT improvise: either skip it or run `/harness:clarify` first.

### Step 5: Run analyze (consistency check)

Invoke `/harness:analyze`. Cascade edits are exactly where analyze earns its keep — a change in architecture.md might leave an NFR orphaned, an AC untestable, or a constitution principle violated. On CRITICAL findings, offer rollback via `git checkout --`.

### Step 6: Run validate (completeness check)

Invoke `/harness:validate` on the post-edit spec. Analyze catches *inconsistency* (files don't reference each other correctly); validate catches *incompleteness* (a section the edit gutted, a removed NFR that now lacks a measurable target, an AC that lost its verification path). Cascade edits are the specific risk scenario where both audits are proportional — single-file amendments don't warrant this second pass.

On V-gate failures (V1–V18 + V8b from `agents/planner.md § SELF-VALIDATION`):
- **Fix-now** (recommended if ≤2 failures): run `/harness:amend "<fix>"` or `/harness:edit "<fix>"` per failure, then re-run validate.
- **Defer-to-sprint** (acceptable if failures are expected to be filled by an imminent sprint, e.g., adding a new FR that the next sprint will flesh out with ACs): note each deferred V-gate in `.harness/progress/known-issues.md` with a target feature/date. Do NOT defer silently — the gap is a ticking drift timer.

Skip Step 6 only if the edit turned out to be single-file after all (rare — flag as "used /edit for an amend-scale change" in the ADR).

### Step 7: Log ADR + changelog

Orchestrator appends to `.harness/progress/decisions.md` (use the template at `@templates/progress/decisions.md`):

```markdown
## ADR-NNN — Cascade edit: [short title]
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE:-global}
**Status**: Accepted

### Context
User requested: "${ARGUMENTS}"

### Decision
Edited [N] files; applied [M] of [proposed K] patches.
Affected files: [list]

### Consequences
- [What changed across files]
- [Downstream: re-negotiate, rebuild, or none]
```

Append to `.harness/progress/changelog.md`:

```markdown
## YYYY-MM-DD — [features/NNN or global] — Cascade edit applied
- Request: "${ARGUMENTS}"
- Files modified: [list]
- Patches applied: [M of K]
- Post-analyze: [PASS/WARN/CRITICAL]
```

## Anti-patterns

- **Using edit for one-file tweaks**: overkill — use `/harness:amend`.
- **Editing during active build**: creates divergence with the Generator. Rewind first or wait for evaluation.
- **Orchestrator-authored "fixes"** for UNCLEAR items: skip or clarify, never improvise.
- **Ignoring analyze**: cascades are the whole reason analyze exists.

## Files written

| File | Writer |
|---|---|
| `.harness/features/NNN/edit-patches.md` (or `.harness/edit-patches.md` if global) | Planner EDIT mode (EDIT marker, cascade-aware) |
| `spec/*.md`, `contract.md`, `init.sh` | Orchestrator applies Planner patches via Edit |
| `progress/decisions.md` | Orchestrator appends ADR |
| `progress/changelog.md` | Orchestrator appends |
