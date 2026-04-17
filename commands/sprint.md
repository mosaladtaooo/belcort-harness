---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1–4 sentences>"
---

# `/harness:sprint`

Invoke the BELCORT Harness skill and execute the **`/harness:sprint`** procedure with the user's prompt: `$ARGUMENTS`

Read `skills/harness/SKILL.md` and follow the `/harness:sprint "<prompt>"` section. In order:

1. Dispatch Planner subagent (two-pass: PRD + architecture/contract)
2. Run analyze phase (cross-artifact consistency check)
3. Present summary to user — **wait for human approval before proceeding**
4. Negotiate phase: Generator proposes HOW → Evaluator reviews → up to 3 rounds
5. Dispatch Generator in BUILD mode (TDD, atomic commits)
6. Dispatch Evaluator in EVALUATE mode (fresh context, Playwright MCP)
7. Tuning check (ask user if they agree with verdict; capture divergences)
8. On PASS: retrospective + merge + update ROADMAP
9. On FAIL: feedback loop to fresh Generator (max 3 retries, then escalate)

Constraints:
- Evaluator MUST be a separate subagent from Generator (GAN-inspired isolation)
- All artifacts go in `.harness/features/NNN-name/`
- Atomic commits: `[harness:<phase>] <description>`
- If user's prompt (`$ARGUMENTS`) is empty, ask them to describe what to build before dispatching anything.
