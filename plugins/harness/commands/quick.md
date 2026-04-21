---
description: Fast harness path for small tasks. Skips Planner, writes a minimal contract inline, single Generator → Evaluator pass. Use when scope is obvious and under 30 minutes.
argument-hint: "<what to build, 1 sentence>"
---

# `/harness:quick` — Fast path

For small tasks where planning overhead is more than the work itself. The prompt is `$ARGUMENTS`. If empty, ask what to build.

## When to use `/harness:quick` vs `/harness:sprint`

| Signal | `/harness:quick` | `/harness:sprint` |
|---|---|---|
| Scope | One component or one file | Multiple components, cross-cutting |
| Novel decisions | None — approach is obvious | New stack choice, new data shape, new API surface |
| Test strategy | Unit tests suffice | Playwright flows needed |
| Estimated time | < 30 min | ≥ 30 min OR unknown |
| Can you write all ACs in one sentence each, without research? | Yes | No |
| Does it touch the constitution? | No — fits existing principles | Maybe — needs architecture deliberation |
| Bug fix with clear reproduction? | Yes | No, or bug is deep |

**Auto-promotion**: if the quick Generator reports PARTIAL self-eval with ≥2 unresolved decisions, OR the Evaluator flags multiple FRs at `Met? = N`, the orchestrator suggests promoting to `/harness:sprint` before retrying. The 30-minute estimate was wrong — reshape the work.

## Procedure

### 0. Doctor — environment preflight (mandatory, blocking)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

Exit-code handling (same as sprint):
- `0` → proceed.
- `1` → CRITICAL. Stop. Show report. Tell user to fix and re-run.
- `2` → doctor errored. Hard stop. Tell user to investigate.

### 1. Write minimal contract (orchestrator-authored — the ONLY place orchestrator authors spec)

Because `/harness:quick` skips the Planner, the orchestrator composes the contract directly. This is intentionally narrow — never use quick for substantial work.

The orchestrator:
1. Picks the next available number for `NNN` under `.harness/features/`.
2. Derives a kebab-case name from the user prompt.
3. Creates `.harness/features/NNN-name/contract.md` (via Write tool) with:

```markdown
# Quick Build Contract

**Quick mode**: single-pass, no negotiation, no retrospective.

## Scope
[One-paragraph restatement of $ARGUMENTS]

## Acceptance Criteria
- AC-1: [observable behavior 1]
- AC-2: [observable behavior 2]
(2-4 ACs max. If you need more, escalate to /harness:sprint.)

## Definition of Done
- All ACs verified via Playwright or unit tests.
- Lint clean.
- Atomic commit: `[harness:quick] <one-line summary>`.
```

4. Initialises `.harness/manifest.yaml` from `@templates/manifest.yaml` if missing. Fills `project.name`, `state.current_feature`, `state.phase = "building"`.

### 2. Build — dispatch Generator BUILD

The orchestrator reads `state.current_feature` from `.harness/manifest.yaml` (call this `${FEATURE}`), then dispatches the Generator via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Quick build ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in BUILD mode for a /harness:quick sprint. The contract at .harness/features/${FEATURE}/contract.md is minimal — 2-4 ACs. Implement via TDD (use superpowers:test-driven-development). This is NOT the full sprint path: there is no proposal/review, no per-FR stories. Keep scope tight. If the work grows beyond the contract, stop and tell the user to escalate to /harness:sprint.

### 3. Evaluate — single pass (no retry)

Same Agent-tool dispatch pattern as [sprint.md § 4. Evaluate](sprint.md) — `subagent_type: harness:evaluator`, EVALUATE-mode prompt. Reads examples.md first (calibration-mandatory), runs Playwright against the app, writes eval-report.md. Single pass; no retry loop on quick.

### 4. Result

- **PASS**: orchestrator merges directly (no retrospective on quick). Updates manifest + ROADMAP.
- **FAIL**: present eval-report.md to user with two options:
  1. Manually fix and re-run `/harness:quick` with the same prompt.
  2. Escalate to `/harness:sprint` for full pipeline treatment.

## Notes

- No tuning check on quick (single-pass, insufficient calibration signal).
- No retrospective on quick (no spec to reconcile against).
- No per-FR stories, no negotiation, no multi-round iteration.
- If the task turned out larger than estimated, next time run `/harness:sprint` for similar work — the heuristic was wrong.
