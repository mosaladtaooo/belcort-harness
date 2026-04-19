---
description: Mid-build steering note. Appends a short guidance nudge to features/NNN/steering.md. The Generator reads steering.md at the start of each TDD cycle in BUILD mode, so notes take effect at the next cycle without interrupting the current one.
argument-hint: "<short guidance, one sentence>"
---

# `/harness:steer` — Mid-build steering

For when the Generator is building and you notice something you want it to do differently — but not something big enough to warrant `/harness:amend` or stopping the build. The nudge is `$ARGUMENTS`. If empty, ask what to steer.

## Why this exists

Between the pre-build human gate and post-build evaluation, there's a long gap where the Generator builds in isolation. If during that gap you notice "search results should order by relevance not recency" or "use date-fns not moment" or "the list empty state should have a CTA to create the first item," there's previously been nowhere to put that observation. You'd either:

1. Wait for evaluation (risk: the Generator already shipped a half-broken approach)
2. Stop the build and run `/harness:amend` (heavy — triggers re-negotiation)
3. Chat at the orchestrator and hope (pollutes context, note lost to next dispatch)

Steering is the lightweight channel: append a short note to a file the Generator reads at each TDD cycle start. No re-planning, no re-negotiation, no orchestrator context pollution.

## What steering is NOT for

- **Spec changes**: use `/harness:amend` — those modify FRs/ACs/architecture
- **Ambiguity questions**: use `/harness:clarify` — those are batched Q&A
- **Direction changes**: use `/harness:rewind` — those reset phase
- **Bug reports**: let the Evaluator find them — that's what it's for

Steering is for *implementation nudges* that don't change the contract but improve how the contract is satisfied. Examples of good steering:
- "Use vitest's `expect.poll` for the async assertions instead of hand-rolled setTimeout"
- "Order the settings page sections by user-frequency-of-use rather than alphabetically"
- "Prefer `@tanstack/react-query` defaults over custom cache keys"

## Procedure

### Step 1: Precondition check

```bash
FEATURE=$(grep 'current_feature:' .harness/manifest.yaml | awk '{print $2}' | tr -d '"')
PHASE=$(grep 'phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')

[ -n "$FEATURE" ] || {
  echo "No active feature. Start one with /harness:sprint."
  exit 1
}

case "$PHASE" in
  building) ;;  # primary use case
  negotiating|analyzing|planning)
    echo "Phase is $PHASE, not building. Steering is a mid-build tool."
    echo "For planning-phase changes: /harness:amend or /harness:clarify."
    exit 1 ;;
  evaluating|retrospective|complete)
    echo "Phase is $PHASE — build is already done. Steering has no effect at this phase."
    echo "For post-build adjustments: /harness:amend (then re-evaluate) or /harness:retrospective (for drift)."
    exit 1 ;;
esac
```

### Step 2: Append the note

```bash
STEERING=".harness/features/${FEATURE}/steering.md"

# Initialize the file with a header if it doesn't exist yet
if [ ! -f "$STEERING" ]; then
  cat > "$STEERING" <<EOF
# Steering Notes — features/${FEATURE}

Append-only. The Generator reads this file at the start of each TDD cycle in
BUILD mode. Notes accumulate — a later note does not override an earlier one
unless it explicitly says so.

Do NOT use this file for spec changes, ambiguity questions, or bug reports.
See /harness:amend, /harness:clarify, and the Evaluator for those cases.
EOF
fi

# Append the new note
cat >> "$STEERING" <<EOF

## $(date +%Y-%m-%dT%H:%M:%S%z) — Steering Note
${ARGUMENTS}

**Applies to**: [next TDD cycle and beyond, until superseded or build completes]
EOF
```

### Step 3: Tell the user

```
═══════════════════════════════
  Harness — Steering Note Appended
═══════════════════════════════
Feature: ${FEATURE}
Note: "${ARGUMENTS}"
File: .harness/features/${FEATURE}/steering.md

The Generator reads this file at the start of each TDD cycle (between
FR implementations). Your note will take effect at the NEXT cycle, not
the current one — TDD cycles are atomic.

Total steering notes for this feature: [count lines matching "^## " in steering.md]
═══════════════════════════════
```

### Step 4: Log to changelog

```
## YYYY-MM-DD — features/NNN — Steering note
- Note: "[first line of ARGUMENTS]"
- Total steering notes this feature: [N]
```

## How the Generator picks up steering

The Generator's BUILD-mode prompt ([agents/generator.md](../agents/generator.md)) has been updated so Phase 1 (Orient) reads `steering.md` if present, and Phase 2 (TDD loop) re-reads it at the start of each cycle. A note added mid-build is picked up at the next cycle boundary — not mid-cycle.

If the Generator notices a steering note conflicts with the contract (e.g., steering says "use PostgreSQL" but contract says SQLite), it escalates via `implementation-report.md` rather than silently obeying either. The contract wins unless the orchestrator applies a matching `/harness:amend`.

## Anti-patterns

- **Using steer as a way to avoid amend**: if the nudge changes spec meaning, it's an amendment, not steering. Steering is for HOW, not WHAT.
- **Writing paragraphs in a single steer call**: keep each note to one or two sentences. If you have five things to say, five `/harness:steer` calls are clearer than one long one.
- **Steering the same FR repeatedly during a single build**: the Generator is likely stuck or misinterpreting — stop the build, run `/harness:amend` to tighten the contract.
- **Retroactive steering after evaluation**: evaluation catches behaviour gaps. Don't steer then re-evaluate — let the eval report drive the retry.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `.harness/features/NNN/steering.md` | Orchestrator appends | feature-scoped, preserved as record |
| `progress/changelog.md` | Orchestrator appends | append-only |
