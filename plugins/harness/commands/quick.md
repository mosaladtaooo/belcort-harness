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

**Auto-promotion**: if the quick generator reports PARTIAL self-eval with ≥2 unresolved decisions, OR the evaluator flags multiple FRs at `Met? = N`, the lead suggests promoting to `/harness:sprint` before retrying. The 30-minute estimate was wrong — reshape the work.

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

### 0c. Create a reduced team + spawn teammates (lead, blocking)

Doctor has passed (Step 0b ran the environment preflight). `/harness:quick` is a build-pipeline command, so it runs on an agent team — but a **reduced** one. Quick skips planning (there is no Planner; the lead writes the minimal contract inline in Step 1), so the team is just the **generator + evaluator** teammates. The orchestrator now becomes the **team lead** and stands up this reduced team. See SKILL.md § Agent Team Protocol for the full contract this step implements.

1. **Verify the team runtime.** Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set and Claude Code is v2.1.32+ (the doctor in Step 0b established the baseline; the lead verifies this teams-specific requirement before creating the team). If either is missing, STOP and tell the user to enable it (settings.json `env` block or shell export) — the team protocol cannot run without it. There is no subagent fallback on this branch (hard-replace).

2. **Create one team** for the quick build, named `harness-quick-<slug>` (derive the slug from `$ARGUMENTS`; reconcile with the `features/NNN-name/` folder once Step 1 picks the number). One team per lead, one team at a time (platform limit); the team persists for the whole quick run.

3. **Spawn two long-lived teammates** by their plugin-declared agent type — the same definitions used as subagents on `main`. NOT a planner — quick skips planning:

   | Teammate name | Agent type | Roles it plays (lead assigns MODE per task) |
   |---|---|---|
   | `generator` | `harness:generator` | BUILD |
   | `evaluator` | `harness:evaluator` | EVALUATE |

4. **Build the reduced task list** as a dependency chain. Dependencies enforce sequential ordering through the parallel team mechanism — a teammate cannot self-claim a task until its dependency completes:

   | Task | Owner | Depends on | MODE assigned |
   |---|---|---|---|
   | T1 Build | generator | — | BUILD (TDD) |
   | T2 Evaluate | evaluator | T1 | EVALUATE (single pass, no retry) |

   No plan-approval / human gate (quick has no Planner and no negotiation). No T3+ negotiate/simulate/retrospective tasks — quick is BUILD then a single EVALUATE pass.

Once the team exists, the generator and evaluator are persistent for the rest of the quick run: the steps below are written as the **lead opening each Tn task to the right teammate**, not as fresh per-phase dispatches. Manifest-state transitions stay lead-owned throughout.

### 1. Write minimal contract (lead-authored — the ONLY place the lead authors spec)

Because `/harness:quick` skips the Planner, the lead composes the contract directly. This is intentionally narrow — never use quick for substantial work.

The lead:
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

### 2. Build — open T1 (Build) to the generator teammate

The lead reads `state.current_feature` from `.harness/manifest.yaml` (call this `${FEATURE}`), then opens task T1 (Build) to the generator teammate. Task assignment:

> Claim T1 in BUILD mode (see your system prompt's MODE ROUTING table). This is a /harness:quick run: the contract at .harness/features/${FEATURE}/contract.md is minimal — 2-4 ACs. Implement via TDD (use superpowers:test-driven-development). This is NOT the full sprint path: there is no proposal/review/negotiation. Keep scope tight. If the work grows beyond the contract, stop and tell the user to escalate to /harness:sprint. Report T1 done to the lead.

(The generator's internal TDD / code-reviewer helpers stay ordinary nested subagents it dispatches itself — nested subagents are allowed; nested teams are not.)

### 3. Evaluate — open T2 (Evaluate) to the evaluator teammate (judges from files only), single pass

After the generator reports T1 done, the lead opens task T2 (Evaluate) to the evaluator teammate (judges from `.harness/` files only; GAN separation is preserved by lead-mediation + file-only handoff, not platform isolation — the evaluator never receives generator mailbox content; see SKILL.md § GAN separation inside a team). Same EVALUATE behaviour as [sprint.md § 4. Evaluate](sprint.md): the evaluator reads examples.md first (calibration-mandatory), reads contract.md + implementation-report.md + source, runs Playwright against the running app, and writes eval-report.md. Single pass; no retry loop on quick.

### 4. Result

- **PASS**: before merging, the lead asks the user ONE spec-drift question (see Step 4.5 below); then merges, updates manifest + ROADMAP.
- **FAIL**: present eval-report.md to user with two options:
  1. Manually fix and re-run `/harness:quick` with the same prompt.
  2. Escalate to `/harness:sprint` for full pipeline treatment.

  Either way the quick run ends here — the lead tears down the team per Step 6 before handing control back.

### 4.5 Spec-drift check (v2.1.2+, PASS path only, single question)

`/quick` skips the full `/harness:retrospective` by design — there's no rich spec to reconcile against. But a quick fix CAN still reveal a spec-level issue (e.g., "while fixing this bug I realized the PRD says X but users actually need Y"). Without a reconciliation step, such drift never propagates back into `spec/prd.md` or `spec/architecture.md`, and future sprints build on an inaccurate spec.

The simplest Anthropic-aligned closure: one question.

The lead asks the user (before the merge):

> Did this fix change any behavior documented in `spec/prd.md`, `spec/architecture.md`, or the constitution?
> - **No** — proceed to merge.
> - **Yes — one-line summary** — the lead runs `/harness:amend "<the summary>"` FIRST (so spec catches up), then merges this quick feature against the updated spec.

No new machinery, no new file, no flag. Prose discipline. User has agency. Simplest gap-closer that keeps spec-sync optional per quick's fast-path philosophy while giving the user a one-click path to keep spec current when it matters.

### 6. Team cleanup (lead, end of quick run)

The quick run ends here, whether the verdict was PASS (after the Step 4.5 merge) or FAIL. The lead cleans up the reduced team it created in Step 0c: confirm the generator + evaluator teammates are idle (or shut them down first), then tear down the `harness-quick-<slug>` team. Only the lead cleans up — never a teammate (the platform forbids teammate cleanup) — and the cleanup frees the one-team-at-a-time slot for the next quick run or sprint.

## Notes

- No tuning check on quick (single-pass, insufficient calibration signal).
- No automatic retrospective on quick (no rich spec); Step 4.5 is the lightweight substitute.
- No negotiation, no multi-round iteration.
- If the task turned out larger than estimated, next time run `/harness:sprint` for similar work — the heuristic was wrong.
