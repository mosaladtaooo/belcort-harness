---
description: Generator ↔ Evaluator contract negotiation round. Generator proposes HOW, Evaluator reviews, iterate up to 3 rounds before code is written.
---

# `/harness:negotiate`

Invoke the BELCORT Harness skill and execute the **`/harness:negotiate`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:negotiate` section. In order:

1. Dispatch Generator in NEGOTIATE mode — writes `.harness/features/<current>/proposal.md` (HOW to build)
2. Dispatch Evaluator in REVIEW-PROPOSAL mode — writes `.harness/features/<current>/review.md` (verdict + asks, no Playwright)
3. If verdict = ACCEPT → dispatch Generator in FINALIZE-CONTRACT mode → writes final `contract.md`
4. If verdict = REVISE → increment `negotiation_round` in manifest, loop back to step 1
5. After 3 rounds without agreement → escalate to human

Generator and Evaluator MUST be separate subagents with fresh context. Do NOT self-evaluate.

If run standalone, use the currently active feature from `manifest.yaml`, or ask the user which feature to negotiate.
