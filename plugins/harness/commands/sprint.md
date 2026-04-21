---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1-4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → Planner → analyze → human gate → Generator ↔ Evaluator negotiate → Generator BUILD → Evaluator EVALUATE → retry-or-retrospective → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

---

## 0a. Brainstorm check — ambiguity gate (optional)

Before touching the environment, scan the prompt for vagueness signals:

- Prompt ≤2 sentences AND no concrete verbs (build, implement, create, fix, migrate, refactor).
- Uncertainty words: `maybe`, `not sure`, `I think`, `figure out`, `help me decide`.
- Multiple plausible interpretations (e.g., "a dashboard").
- Unfamiliar domain with no prior features in `manifest.yaml`.

If ANY signal hits, offer the user: run `/harness:brainstorm` first (recommended), proceed anyway (Planner will use AskUserQuestions to clarify), or cancel.

If NO signal hits, skip this step silently.

If `.harness/brainstorm-current.md` exists from a prior brainstorm session, treat its content as additional context for the Planner dispatch in Step 1. After Planner creates the feature folder in Step 1, the orchestrator moves `brainstorm-current.md` into the feature folder as `brainstorm.md`.

---

## 0. Doctor — environment preflight (mandatory, blocking)

Before dispatching any subagent, run the doctor:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

- `DOCTOR_EXIT = 0`: environment ready, proceed.
- `DOCTOR_EXIT = 1`: CRITICAL failure. Show the doctor's report (with fix suggestions) and STOP. Tell the user: "Fix the items above, then re-run `/harness:sprint \"$ARGUMENTS\"`."
- `DOCTOR_EXIT = 2`: doctor itself errored. Hard stop. Show stderr. Tell the user to run the doctor manually and investigate.

See [doctor.md](doctor.md) for what it checks.

---

## 1. Plan — dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD + constitution (the WHAT and WHY).
- Pass 2: Architecture + criteria + contract (the HOW — informed by Pass 1).

Dispatch pattern (v2.1.0+): the Planner is a plugin-shipped subagent type declared in `plugin.json` via `"agents": "./agents/"`. Its system prompt, allowed tools, and identity come from `agents/planner.md` frontmatter — the orchestrator invokes it through Claude Code's native Agent tool.

If a brainstorm file exists, the orchestrator includes its content in the Planner dispatch as additional context.

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Plan feature: <one-line summary of $ARGUMENTS>"`
- **prompt**: the following block (pass as the Agent tool's `prompt` parameter verbatim):

> You are being dispatched in PLAN mode (see your system prompt for the full role and 2-pass procedure).
>
> Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, per-FR story files under features/NNN-name/stories/, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the Generator. Run your 16-point self-validation before exiting and report the pass count.
>
> User request:
> $ARGUMENTS
>
> [If `.harness/brainstorm-current.md` exists, the orchestrator appends its full content here under a `--- BRAINSTORM CONTEXT ---` marker before invoking the Agent tool.]

**After Planner returns, the orchestrator (not a subagent) performs these housekeeping steps using the Bash/Edit tools. These are natural-language instructions — not a shell script:**

1. Verify the Planner actually wrote the expected files (spec/, evaluator/criteria.md, features/NNN-name/contract.md, stories/, init.sh, manifest.yaml, ROADMAP.md). If any is missing, halt and ask the user.
2. If `.harness/brainstorm-current.md` still exists and the feature folder now exists, move the brainstorm file into the feature folder as `brainstorm.md`.
3. Make `.harness/init.sh` executable. The Planner has no Bash tool, so it cannot chmod its own output.

Then wait for the human gate in Step 2.

---

## 2. Human gate — present summary, wait for approval

Summarise what was planned:

```
═══════════════════════════════
  Harness — Planning Complete
═══════════════════════════════
Project: [name]
Complexity: [small/medium/large] ([N] FRs)
Stack: [framework + db]

PRD: [N] personas, [N] journeys, [N] FRs, [N] NFRs, [N] risks.
Architecture: [N] components, Context7 verified.
Contract: [strategy], [N] deliverables, [N] ACs.
Files: ✓ spec/prd.md, ✓ spec/constitution.md, ✓ spec/architecture.md,
       ✓ evaluator/criteria.md, ✓ features/NNN/contract.md, ✓ init.sh.
Planner self-validation: [N/16 passed].

Next:
  • approved               → negotiate + build
  • /harness:clarify       → surface ambiguities, answer, auto-patch
  • /harness:amend "<X>"   → targeted tweak
  • /harness:edit "<X>"    → multi-file spec edit
  • /harness:rewind planning → fundamental re-plan
═══════════════════════════════
```

**Do NOT proceed until the user explicitly approves.** This is the only mandatory human gate.

If the user wants changes, route through a command — never edit spec files from this orchestrator's context (see SKILL.md § File Ownership Contract).

**Auto-suggest `/harness:clarify`** if: Planner self-validation mentioned ≥3 silent defaults, OR user's approval text contains uncertainty words ("maybe", "not sure", "probably").

---

## 2b. Analyze — cross-artifact consistency (automatic)

Run the [`/harness:analyze`](analyze.md) procedure. CRITICAL findings halt; warnings pass through.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "negotiating"` (Edit tool).

---

## 2c. Negotiate — Generator ↔ Evaluator agree on sprint contract (automatic)

Three dispatches in sequence. The orchestrator reads `state.current_feature` from manifest.yaml before each dispatch to get the `${FEATURE}` value.

**Round 1: Generator writes proposal.md** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Negotiate proposal for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in NEGOTIATE mode (see your system prompt's MODE ROUTING table).
>
> Do NOT write code in this mode. Read the draft contract, architecture direction, constitution, and criteria via Read tool. Write your implementation proposal to .harness/features/${FEATURE}/proposal.md per the template at @templates/features/proposal.md.txt.

**Round 2: Evaluator reviews the proposal** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Review generator proposal for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in REVIEW-PROPOSAL mode (see your system prompt's MODE ROUTING table).
>
> Do NOT run Playwright — there is no app yet. Read .harness/evaluator/criteria.md, the draft contract, and the Generator's proposal. Write your review to .harness/features/${FEATURE}/review.md per the template at @templates/features/review.md.txt with a VERDICT line (agreed | needs-revision).

**Iterate**: if verdict is `needs-revision`, re-dispatch Generator via the Agent tool (same `harness:generator` subagent_type, NEGOTIATE mode prompt) to revise proposal.md; then Evaluator reviews again. Max 3 rounds (per `config.max_negotiation_rounds` in manifest). If no agreement at round 3, escalate to human.

**Final: Generator writes the negotiated contract** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Finalize contract for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in FINALIZE-CONTRACT mode. Merge proposal.md + review.md into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (MUST include **Negotiated**: marker). Do NOT update manifest.yaml — the orchestrator handles phase transitions.

**After FINALIZE returns**: orchestrator updates `.harness/manifest.yaml` → `state.phase = "building"` using the Edit tool.

See [negotiate.md](negotiate.md) for the standalone variant.

---

## 3. Build — dispatch Generator subagent

Create the worktree:

```bash
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true
```

Assemble the dispatch context. The Generator reads most files via its own Read tool — the inline file list in the prompt is a hint, not authoritative. Prefer per-FR story reads per TDD cycle over the full aggregate contract.

If `.harness/features/${FEATURE}/eval-report.md` exists (this is a retry), the orchestrator reads its content and appends it to the Agent prompt under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before the user-request block.

The orchestrator dispatches the Generator via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Build ${FEATURE} via TDD"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in BUILD mode (see your system prompt's MODE ROUTING table).
>
> Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). Read per-FR stories at .harness/features/${FEATURE}/stories/FR-NNN.md per cycle — that's your canonical per-cycle context.
>
> Key files (read via Read tool as needed):
> - .harness/spec/constitution.md
> - .harness/spec/architecture.md
> - .harness/features/${FEATURE}/contract.md (final, negotiated)
> - .harness/features/${FEATURE}/stories/*.md
> - .harness/evaluator/criteria.md
>
> [If `.harness/features/${FEATURE}/eval-report.md` exists, the orchestrator appends its full content here under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before invoking the Agent tool.]

---

## 3a. Pause check — Generator may have requested user input mid-build

If `.harness/features/${FEATURE}/pause-questions.md` exists after the Generator dispatch returns, the Generator paused and needs answers.

Loop (up to `MAX_PAUSES = 3`):
1. Read pause-questions.md; present each question to the user with its "default if unanswered" fallback.
2. Collect answers. Each answer is either a user response, "accept default", or "skip" (marks FR partial).
3. Archive the pause file: move to `.harness/features/${FEATURE}/paused-history/pause-N-TIMESTAMP.md`.
4. Orchestrator increments `manifest.yaml → config.calibration_metrics.agent_checkins` by 1 using the Edit tool.
5. Re-dispatch Generator BUILD via the Agent tool (same `subagent_type: harness:generator`, same BUILD-mode prompt from Step 3), with the collected answers appended to the end of the prompt under a `--- PAUSE ANSWERS ---` marker.
6. If a new `pause-questions.md` appears after the re-dispatch, loop again.

After `MAX_PAUSES`, escalate: "Generator has paused N times on this sprint — the contract is likely under-determined. Recommend `/harness:rewind negotiating` to re-spec the affected FR(s) before continuing." Halt the sprint.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "evaluating"` after the Generator dispatch completes successfully.

---

## 4. Evaluate — dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

The orchestrator dispatches the Evaluator via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Evaluate ${FEATURE} via Playwright"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in EVALUATE mode (see your system prompt's MODE ROUTING table).
>
> Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan (Step 4.5), and write your verdict to .harness/features/${FEATURE}/eval-report.md per the template at @templates/features/eval-report.md.txt.
>
> Calibration-mandatory reads BEFORE scoring:
> - .harness/evaluator/examples.md (few-shot anchors)
> - .harness/spec/evaluator-notes.md (if exists)
> - .harness/evaluator/criteria.md
>
> Then: read implementation-report.md, contract.md, proposal.md, review.md, constitution.md, prd.md (via Read tool). Start the app with bash .harness/init.sh. Exercise via Playwright.

---

## 5. Result — read evaluator report and decide

Orchestrator reads `.harness/features/${FEATURE}/eval-report.md`, extracts the `**Result: PASS / FAIL**` line, and reads `state.retry_count` vs `config.max_retries` from manifest.yaml.

### If PASS

**5a-pre. Tuning check — capture human-Evaluator divergence (automatic)**

This implements the Anthropic-documented tuning loop. Present the Evaluator's judgment to the user:

```
═══════════════════════════════
  Harness — Evaluator Judgment Check
═══════════════════════════════
Verdict: PASS
Scores: F:X/10  Q:X/10  T:X/10  P:X/10
Critical findings: [N]  (titles)
Major findings: [N]   (titles)

Do you agree with this evaluation?
  1. Agree — proceed
  2. Disagree — flag specific divergences
  3. Partial — some findings right, some wrong
═══════════════════════════════
```

- **Agree** → skip to retrospective.
- **Disagree/Partial** → enter divergence capture: for each divergence, record what Evaluator said, what the user thinks, and why. Append to `.harness/evaluator/tuning-log.md`. Ask if this should become a calibration example → if yes, append to `.harness/evaluator/examples.md`; if project-specific, append to `.harness/spec/evaluator-notes.md`.
- Check for pattern emergence: if any divergence category has ≥3 entries in tuning-log.md, tell the user: "Pattern detected: [category] has diverged [N] times. Consider `/harness:tune-evaluator`."
- Proceed to retrospective regardless.

**5a. Retrospective — drift analysis (MANDATORY)**

Run `/harness:retrospective` (see retrospective.md). Writes `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update spec files + ADR.

If the retrospective itself fails (subagent errors, malformed output), do NOT silently skip. Block merge, write a stub retrospective.md noting the failure, ask the user to retry / run manually / merge-without-retro with explicit confirmation.

**5b. Merge**

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [one-line summary]"
git worktree remove .worktrees/current 2>/dev/null
```

Then the orchestrator (via Edit tool) updates:
- `ROADMAP.md` — move feature to "✅ Shipped".
- `.harness/manifest.yaml` — `features.completed` append, `features.in_progress = ""`, `state.phase = "complete"`, `state.retry_count = 0`.

Print scores + completion message.

### If FAIL and retries < max

Orchestrator updates `manifest.yaml` → `state.retry_count += 1`, `state.phase = "building"`. Prints failing scores + critical findings. Auto-loops back to Step 3 (BUILD dispatch).

Before retry: run the same tuning check from 5a-pre, but with the reversed framing: "Do you agree the Evaluator should have failed this?" Log divergences. Proceed to retry regardless.

### If FAIL and retries ≥ max

Present the user with options:
1. Force merge with known issues.
2. Manually fix and re-run `/harness:resume` (picks up from evaluating phase).
3. Increase `config.max_retries` and continue.
4. Abandon.

---

## Constraints

- Evaluator MUST be a separate subagent from Generator (GAN isolation).
- All artifacts go in `.harness/features/NNN-name/`.
- Atomic commits on the build branch: `[harness:<phase>] <description>`.
- Subagents are workers, not managers — they NEVER re-invoke the harness pipeline.
- Orchestrator does NOT edit spec files directly (see SKILL.md § File Ownership Contract). Use `/harness:amend`, `/harness:edit`, `/harness:clarify`, or `/harness:constitution-amend`.
