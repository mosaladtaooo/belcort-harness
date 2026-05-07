---
description: Fast harness path for small tasks. Skips Planner, writes a minimal contract inline, single Generator → Evaluator pass. Use when scope is self-evident (single FR, no architectural decisions). Path selection is by spec complexity, not wall-clock — see Planner § WORKFLOW ASSUMPTION.
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

### 0a. 1M-context confirmation (one-line check)

`/quick` is short by design, so the 1M-context need is softer than for `/sprint`. Print one line:

> Quick mode: confirm Claude Code is on `claude --model claude-opus-4-7[1m]` if this fix touches more than ~5 files. (Press Enter to proceed.)

Do not block. Continue to Step 0b on any input.

### 0b. Doctor — environment preflight (mandatory, blocking)

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

> You are being dispatched in BUILD mode for a /harness:quick sprint. The contract at .harness/features/${FEATURE}/contract.md is minimal — 2-4 ACs. Implement via TDD (use superpowers:test-driven-development). This is NOT the full sprint path: there is no proposal/review. Keep scope tight. If the work grows beyond the contract, stop and tell the user to escalate to /harness:sprint.

### 3. Evaluate — single pass (no retry)

Same Agent-tool dispatch pattern as [sprint.md § 4. Evaluate](sprint.md) — `subagent_type: harness:evaluator`, EVALUATE-mode prompt. Reads examples.md first (calibration-mandatory), runs Playwright against the app, writes eval-report.md. Single pass; no retry loop on quick.

### 4. Result

- **PASS**: before merging, orchestrator asks the user ONE spec-drift question (see Step 4.5 below); then merges, updates manifest + ROADMAP.
- **FAIL**: present eval-report.md to user with two options:
  1. Manually fix and re-run `/harness:quick` with the same prompt.
  2. Escalate to `/harness:sprint` for full pipeline treatment.

### 4.5 Spec-drift check (v2.1.2+, PASS path only, single question)

`/quick` skips the full `/harness:retrospective` by design — there's no rich spec to reconcile against. But a quick fix CAN still reveal a spec-level issue (e.g., "while fixing this bug I realized the PRD says X but users actually need Y"). Without a reconciliation step, such drift never propagates back into `spec/prd.md` or `spec/architecture.md`, and future sprints build on an inaccurate spec.

The simplest Anthropic-aligned closure: one question.

Orchestrator asks the user (before the merge in Step 5):

> Did this fix change any behavior documented in `spec/prd.md`, `spec/architecture.md`, or the constitution?
> - **No** — proceed to merge.
> - **Yes — one-line summary** — orchestrator runs `/harness:amend "<the summary>"` FIRST (so spec catches up), then merges this quick feature against the updated spec.

No new machinery, no new file, no flag. Prose discipline. User has agency. Simplest gap-closer that keeps spec-sync optional per quick's fast-path philosophy while giving the user a one-click path to keep spec current when it matters.

## Notes

- No tuning check on quick (single-pass, insufficient calibration signal).
- No automatic retrospective on quick (no rich spec); Step 4.5 is the lightweight substitute.
- No negotiation, no multi-round iteration.
- If the task turned out larger than estimated, next time run `/harness:sprint` for similar work — the heuristic was wrong.
