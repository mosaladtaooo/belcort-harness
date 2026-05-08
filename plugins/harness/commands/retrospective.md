---
description: Post-merge drift analysis & spec sync — orchestrator-driven reconciliation of what was specified vs what was built. Identifies positive, negative, and neutral drift, proposes spec updates, keeps PRD and architecture in sync with reality across sprints.
---

# `/harness:retrospective` — Post-merge drift analysis & spec sync

Runs AFTER the Evaluator returns PASS and BEFORE the final merge + archive. Reconciles what was actually built against what the spec said would be built. Keeps PRD and architecture in sync with reality over many sprints.

Unlike amend/edit/clarify, retrospective has NO subagent dispatch. The orchestrator reads the artifacts, classifies drift, writes the retrospective findings, presents them, and mechanically applies approved spec updates. This is a reconciliation pass, not a generation pass.

## When it runs

- Automatically in the sprint flow after Evaluator PASS, before ROADMAP update.
- Manually, against the last completed feature if reconciliation was skipped.

## Why it matters

Over many features, specs drift. The Generator might add a helper not mentioned in architecture. An AC might be satisfied differently than specified. Without periodic reconciliation, the spec becomes fiction and future features build on lies.

## Procedure

### Step 1: Precondition check

Orchestrator reads `.harness/manifest.yaml`. Verify `state.phase` is `evaluating` or `retrospective`, and `state.current_feature` is set (call it `${FEATURE}`). If no active feature, default to the last item of `features.completed[]` or ask the user which feature to retrospect.

### Step 2: Read the artifacts

Orchestrator reads via `Read` tool:
- `.harness/features/${FEATURE}/contract.md` — what was negotiated
- `.harness/features/${FEATURE}/implementation-report.md` — what Generator claims was built
- `.harness/features/${FEATURE}/eval-report.md` — what Evaluator verified (PASS)
- Source files named in implementation-report.md (scan to confirm reality)
- `git log --oneline origin/main..HEAD` (or the build branch) — commits landed

### Step 3: Classify drift

For each divergence between contract and reality, the orchestrator assigns one of three categories:

- **Positive drift** — implementation went beyond the contract (extra polish, new helper, additional edge case). Candidate for capture into the spec.
- **Negative drift** — contract said X, implementation is Y where Y is weaker (stubbed edge case that still passed, shortcut in error handling). Resolve as either accept-and-tighten OR flag-as-debt.
- **Neutral drift** — different path, same outcome (Planner named Redis, built with in-memory Map; behavior equivalent). Update architecture to reflect reality.

### Step 4: Write retrospective.md

Orchestrator uses `Write` tool to create `.harness/features/${FEATURE}/retrospective.md`:

```markdown
# Retrospective — ${FEATURE}
**Date**: YYYY-MM-DD
**Eval result**: PASS
**Spec adherence (0-10)**: [score]

## Drift Findings
### Positive drift (candidates for spec capture)
- [component]: [what was added] → Proposed update: [file + section]

### Negative drift (debt or tightening)
- [contract item]: [how weaker] → Resolution: [accept-and-tighten | flag-as-debt]

### Neutral drift (update architecture to reflect reality)
- [contract said X, built Y]: [why equivalent] → Proposed update: [section]

## Proposed Spec Updates
| # | File | Section | Change type | Summary |
|---|---|---|---|---|
| 1 | spec/prd.md | FR-003 | tighten | [one line] |

## Known-issues / Debt
- [item to add to ROADMAP or known-issues.md]
```

### Step 5: Present findings

```
═══════════════════════════════
  Harness — Retrospective
═══════════════════════════════
Feature: ${FEATURE}
Spec adherence: [score]/10

Positive drift:  [N items]
Negative drift:  [N items]
Neutral drift:   [N items]

Proposed spec updates: [N]
  [1] spec/prd.md § FR-003 — [summary]
  [2] spec/architecture.md § ... — [summary]

Apply all / Apply some (list numbers) / Apply none / Show full retrospective / Cancel?
═══════════════════════════════
```

### Step 6: Apply approved updates

For each approved update, orchestrator uses the `Edit` tool on `spec/prd.md` and/or `spec/architecture.md` per the proposed-updates table. Each gets an ADR at Step 9.

### Step 7: Update ROADMAP.md

Orchestrator uses `Edit` tool to:
- Move `${FEATURE}` from `In Progress` to `Shipped` (with PASS scores, retry count, merge date).
- Append new feature ideas to `Considered` if the retrospective surfaced any.
- Append negative-drift debt items under `Constitutional debt` or a Debt section.

### Step 8: Update manifest.yaml

Orchestrator uses `Edit` tool on `.harness/manifest.yaml`:
- Append `${FEATURE}` to `features.completed[]`.
- Clear `features.in_progress`.
- Set `state.phase: "complete"`.
- Clear `state.current_feature`.

### Step 9: Log ADR per approved update

Append one ADR per applied update to `.harness/progress/decisions.md`:

```markdown
## ADR-NNN — Retrospective: [short title]
**Date**: YYYY-MM-DD
**Feature**: ${FEATURE}
**Status**: Accepted

### Context
Post-merge retrospective identified [positive/negative/neutral] drift.

### Decision
Updated [file] § [section]: [before → after summary]

### Consequences
- Spec now reflects built reality.
```

### Step 10: Append changelog

```markdown
## YYYY-MM-DD — ${FEATURE} — Retrospective applied
- Spec adherence: [score]/10
- Drift: [P positive, N negative, U neutral]
- Spec updates applied: [N of M]
- Debt items logged: [N]
```

On decline: retrospective.md stays on disk as a record; no spec is modified.

## Anti-patterns

- **Skipping retrospective "because eval PASSed"**: PASS means the contract's ACs held, not that implementation matches intent.
- **Auto-accepting every positive-drift item**: only capture patterns that should be binding; incidental polish should stay out.
- **Rewriting spec freehand** instead of using this command: retrospective findings need the classification step. Ad-hoc edits lose the audit trail.
- **Burying negative drift as "neutral"**: if weaker than contracted, it's either accepted-and-tightened or it's debt. Don't hide it.

## Files written

| File | Writer |
|---|---|
| `.harness/features/NNN/retrospective.md` | Orchestrator writes findings |
| `spec/prd.md`, `spec/architecture.md` | Orchestrator applies approved updates via Edit |
| `ROADMAP.md` | Orchestrator updates |
| `manifest.yaml` | Orchestrator updates |
| `progress/decisions.md` | Orchestrator appends ADR per update |
| `progress/changelog.md` | Orchestrator appends |
