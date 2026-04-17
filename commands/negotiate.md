---
description: Generator ↔ Evaluator contract negotiation round. Generator proposes HOW, Evaluator reviews, iterate up to 3 rounds before code is written. Bridges the Planner's "what/why" to a testable "how".
---

# `/harness:negotiate` — Generator ↔ Evaluator contract negotiation

Runs AFTER [analyze.md](analyze.md) clears and BEFORE the Generator builds. Translates the Planner's high-level contract into a testable implementation plan that both Generator and Evaluator commit to.

**When it runs automatically:**
In the full [sprint.md](sprint.md) flow, `/harness:negotiate` runs automatically between ANALYZE and BUILD. You don't invoke it manually in the happy path.

**When to invoke manually:**
- `/harness:resume` landed on phase "negotiating" after session interruption
- You edited the draft contract and want to re-negotiate before rebuilding
- Previous negotiation was escalated to human and you now want to restart it

## Why this exists

The Planner stays at the "what & why" level on purpose. File paths, component boundaries, data schemas, and API shapes are NOT in the architecture doc. This negotiation is where those details get pinned down — but by the agents that will actually build and test, not by the Planner upfront. This prevents the Planner from cascading wrong technical details into the entire downstream pipeline.

## Procedure

1. **Generator proposes** (writes `proposal.md`)
   - Reads: draft contract, architecture direction, constitution, criteria
   - Writes: implementation plan with components, files, schemas, test strategy
   - Does NOT write code

2. **Evaluator reviews** (writes `review.md`)
   - Reads: contract, proposal, criteria
   - Checks: HOW clarity, AC testability, risk flags
   - Writes: verdict (`agreed` / `needs-revision`) + specific asks
   - Does NOT run Playwright — there's no app yet

3. **If `needs-revision`:** Generator revises proposal (append new round to `proposal.md`), Evaluator re-reviews. Max 3 rounds.

4. **If no agreement after 3 rounds:** Escalate to human with:
   - Diff of what Generator wants vs what Evaluator wants
   - The core disagreement summarized
   - Options: force one side, rewrite the draft contract, abandon feature

5. **On agreement:** Generator writes final `contract.md` (overwrites Planner's draft) merging the original deliverables + negotiated implementation details + any Evaluator-added ACs.

## Dispatch blocks

Full shell-dispatch blocks (Round 1 Generator NEGOTIATE, Round 2 Evaluator REVIEW-PROPOSAL, final Generator FINALIZE-CONTRACT) live in [sprint.md § 2c. NEGOTIATE](sprint.md). Reuse them verbatim.

## Anti-patterns to watch for

- **Generator proposing every detail (over-specifying)** → Evaluator should push back on anything not needed to test the AC
- **Evaluator rubber-stamping without reading** → check `review.md` — if it's 3 lines, the Evaluator didn't actually engage
- **Negotiation loop going 3+ rounds** → the draft contract itself is probably unclear; escalate to human rather than letting agents thrash

Generator and Evaluator MUST be separate subagents with fresh context. Do NOT self-evaluate.
