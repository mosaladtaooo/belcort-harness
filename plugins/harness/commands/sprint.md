---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → simulate (prod runtime + cumulative regression) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1-4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → Planner → analyze → human gate → Generator ↔ Evaluator negotiate → Generator BUILD → Generator SIMULATE → Evaluator EVALUATE → retry-or-retrospective → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

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

## 0b. 1M-context confirmation (recommended — prevents Generator BUILD truncation)

Before dispatching any subagent, the orchestrator confirms the user's Claude Code session is on the 1M-context Opus variant. Multi-stratum sprints (foundation features, full-stack work) routinely exceed the default 200K Opus context during BUILD; truncation produces no `implementation-report.md` and forces a re-dispatch.

Print this prompt and wait for user input:

> This sprint can dispatch Generator BUILD for 30+ minutes on multi-stratum work. Confirm Claude Code was launched with `claude --model claude-opus-4-7[1m]` for the 1M-context variant. (Y to proceed / N to relaunch first.)

On `N`: print *"Relaunch Claude Code with: `claude --model claude-opus-4-7[1m]`, then re-run /harness:sprint"* and exit. On `Y`: continue to Step 0c. On any other input: re-prompt once, then proceed cautiously with a logged warning in `progress/changelog.md`.

Rationale: Claude Code does not currently expose `--model` to plugin scripts, so this is user-confirmation, not mechanical detection. See `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md` § 6.1 for why.

---

## 0c. Doctor — environment preflight (mandatory, blocking)

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

Dispatch pattern (v2.1.0+): the Planner is a plugin-shipped subagent type declared in `plugin.json` via the `agents` array. Its system prompt, allowed tools, and identity come from `agents/planner.md` frontmatter — the orchestrator invokes it through Claude Code's native Agent tool.

If a brainstorm file exists, the orchestrator includes its content in the Planner dispatch as additional context.

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Plan feature: <one-line summary of $ARGUMENTS>"`
- **prompt**: the following block (pass as the Agent tool's `prompt` parameter verbatim):

> You are being dispatched in PLAN mode (see your system prompt for the full role and 2-pass procedure).
>
> Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the Generator. Run your 19-point self-validation before exiting and report the pass count.
>
> User request:
> $ARGUMENTS
>
> [If `.harness/brainstorm-current.md` exists, the orchestrator appends its full content here under a `--- BRAINSTORM CONTEXT ---` marker before invoking the Agent tool.]

**After Planner returns, the orchestrator (not a subagent) performs these housekeeping steps using the Bash/Edit tools. These are natural-language instructions — not a shell script:**

1. Verify the Planner actually wrote the expected files (spec/, evaluator/criteria.md, features/NNN-name/contract.md, init.sh, manifest.yaml, ROADMAP.md). If any is missing, halt and ask the user.
2. If `.harness/brainstorm-current.md` still exists and the feature folder now exists, move the brainstorm file into the feature folder as `brainstorm.md`.
3. Make `.harness/init.sh` executable. The Planner has no Bash tool, so it cannot chmod its own output.

Then run the consistency check in Step 2 before presenting the human gate.

---

## 2. Analyze — cross-artifact consistency (automatic)

Run the [`/harness:analyze`](analyze.md) procedure immediately after Planner output exists, before asking the user to approve the plan.

- CRITICAL findings halt. Present the findings and route the user to `/harness:amend`, `/harness:edit`, `/harness:clarify`, or `/harness:rewind planning`.
- Warnings pass through. Include them in the Step 2b summary so the user approves the plan with the consistency report in view.

Do NOT update `state.phase = "negotiating"` yet. The human gate in Step 2b decides whether negotiation may start.

---

## 2b. Human gate — present summary, wait for approval

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
Planner self-validation: [N/19 passed].
Analyze: [PASS | N warning(s)].

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

After explicit approval, orchestrator updates `.harness/manifest.yaml` → `state.phase = "negotiating"` (Edit tool).

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
> Do NOT run Playwright — there is no app yet. Read (all via Read tool):
> - `.harness/evaluator/criteria.md` — grading rubric
> - `.harness/features/${FEATURE}/contract.md` — Planner's draft contract
> - `.harness/features/${FEATURE}/proposal.md` — Generator's proposed HOW
> - `.harness/spec/constitution.md` — use it to judge test-strategy adequacy + HOW-level coding-standard compliance (v2.1.3+)
> - `.harness/spec/architecture.md` — use it to verify the proposal's component/directory/data-model choices align with the declared architectural style (v2.1.3+)
>
> PRD is NOT needed at this stage — the contract already contains the NFR targets. Write your review to `.harness/features/${FEATURE}/review.md` per the canonical template at `@templates/features/review.md.txt` with a VERDICT line (agreed | needs-revision).

**Iterate**: if verdict is `needs-revision`, re-dispatch Generator via the Agent tool (same `harness:generator` subagent_type, NEGOTIATE mode prompt) to revise proposal.md; then Evaluator reviews again. Max 3 rounds (per `config.max_negotiation_rounds` in manifest). By round 3, continued disagreement signals an unclear upstream contract (the Planner's what/why is ambiguous), not a negotiation problem. More agent rounds won't resolve a values or clarity gap; human judgment will.

**If no agreement after 3 rounds, escalate to human with this structure:**

- **The blocker** (one sentence): what Generator wants vs what Evaluator wants, at the narrowest point of disagreement.
- **Why it's stuck** (one sentence): which upstream artifact is ambiguous — usually the draft contract, sometimes the architecture or constitution.
- **The decision being asked of you**: pick (a) force Generator's proposal as-is, (b) force Evaluator's asks as-is, (c) rewrite the draft contract to resolve the ambiguity (run `/harness:amend` or `/harness:edit`), (d) abandon the feature.

**Final: Generator writes the negotiated contract** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Finalize contract for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in FINALIZE-CONTRACT mode. Merge proposal.md + review.md into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (MUST include **Negotiated**: marker). Do NOT update manifest.yaml — the orchestrator handles phase transitions.

**After FINALIZE returns**: orchestrator updates `.harness/manifest.yaml` → `state.phase = "building"` using the Edit tool.


---

## 3. Build — dispatch Generator subagent

Create the worktree:

```bash
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true
```

**Note on the worktree's stale `.harness/`:** the checkout includes a frozen snapshot of `.harness/` at `.worktrees/current/.harness/` as a git-worktree side-effect. It is stale and must not be read or written by any agent or orchestrator step. The live `.harness/` is at project root. See SKILL.md § File Ownership Contract → Working directory and `.harness/` location. The dispatch prompt below restates this rule inline so the Generator has it in its fresh context.

Assemble the dispatch context. The Generator reads most files via its own Read tool — the inline file list in the prompt is a hint, not authoritative. Prefer per-FR section reads (grep by FR-NNN ID against contract.md) per TDD cycle over the full aggregate contract.

If `.harness/features/${FEATURE}/eval-report.md` exists (this is a retry), the orchestrator reads its content and appends it to the Agent prompt under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before the user-request block.

The orchestrator dispatches the Generator via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Build ${FEATURE} via TDD"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in BUILD mode (see your system prompt's MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root. All `.harness/...` paths below resolve from project root. The `.worktrees/current/.harness/` folder exists (git-worktree side-effect) but is a stale frozen snapshot — never read or write it. Source code goes into `.worktrees/current/src/...`; spec and report files stay under project-root `.harness/`. If you `cd .worktrees/current` for a Bash command, `cd` back before any `.harness/` Read/Write, or use `$CLAUDE_PROJECT_DIR/.harness/...` absolute paths.
>
> Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). For each FR's RED step, locate that FR's section in .harness/features/${FEATURE}/contract.md (grep by FR ID) — the contract is your per-cycle context.
>
> Key files (read via Read tool as needed, always from project-root `.harness/`):
> - .harness/spec/constitution.md
> - .harness/spec/architecture.md
> - .harness/features/${FEATURE}/contract.md (final, negotiated)
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
5. Re-dispatch Generator BUILD via the Agent tool (same `subagent_type: harness:generator`, same BUILD-mode prompt from Step 3), with TWO blocks appended to the end of the prompt: (a) the `## State at pause` section verbatim from `pause-questions.md` under a `--- PAUSE STATE SNAPSHOT (authoritative — prefer over manifest if they disagree) ---` marker, and (b) the collected answers under a `--- PAUSE ANSWERS ---` marker.
6. If a new `pause-questions.md` appears after the re-dispatch, loop again.

After `MAX_PAUSES`, escalate: "Generator has paused N times on this sprint — the contract is likely under-determined. Recommend `/harness:rewind negotiating` to re-spec the affected FR(s) before continuing." Halt the sprint.

After the Generator dispatch completes successfully, the setup-required gate runs before SIMULATE so auth/env gaps do not burn simulation or evaluation attempts.

---

## 3.5. Setup-required gate before SIMULATE/EVALUATE (v2.1.9+)

Before dispatching SIMULATE, the orchestrator reads `.harness/features/${FEATURE}/implementation-report.md` → `## Setup required` section. If it lists required files that the user must create (e.g., `.env.local`) OR other user-completable steps (database migrations with user credentials, external service config), the orchestrator:

1. Checks whether each required file exists at the project-root path.
2. If all required files exist AND the report doesn't flag remaining user steps, proceed to Step 3.6 (SIMULATE).
3. Otherwise: present the Setup section to the user verbatim, with a message like *"Generator finished building. Before SIMULATE or Evaluator can run, complete this setup: [list]. Type 'continue' when ready."* Wait for confirmation. Do NOT auto-retry or skip — a SIMULATE/Evaluator run against an app that can't start produces a false failure that wastes retry budget.

This gate exists because the app under test often needs secrets (DB URLs, API keys, signing keys) that the Generator cannot write (AgentLint's `no-env-commit` + `no-secrets` rules are unsuppressible errors, by design). The two-file convention `.env.example` (Generator) + `.env.local` (user) hands off cleanly at this gate.

**Test-account env vars (v3.0+).** If the implementation-report's
`## Setup required` section lists any `TEST_USER_*` or `TEST_TENANT_*` /
`TEST_FIRM_*` env vars (Generator BUILD adds these to `.env.example` for
auth-gated apps per the Test-account placeholders rule), the orchestrator
explicitly enumerates them in the user-facing setup checklist:

> Before SIMULATE can drive auth-gated flows, populate these test-account
> values in `.env.local`:
>   • `TEST_USER_EMAIL` — a valid email for a test user (e.g., `tester@yourdomain.test`)
>   • `TEST_USER_PASSWORD` — at least 12 characters
>   • [any other `TEST_*` vars listed in `.env.example`]
>
> Then run `bash .harness/init.sh` — its `seed_test_user` function will
> use these to create the test user record. Type 'continue' when ready.

Wait for confirmation. If the user types 'continue' but the env vars are
still empty (sourced from `.env.local`), do NOT proceed — re-prompt with
"TEST_USER_EMAIL is empty in .env.local; SIMULATE will fail at any auth
flow. Set the values first, then type 'continue'."

---

## 3.6. Simulate — drive prod-mode runtime (automatic)

After Generator BUILD returns successfully (and the pause-protocol loop in
Step 3a plus the setup-required gate have resolved), the orchestrator updates
`manifest.yaml → state.phase = "simulating"` (Edit tool) and dispatches
Generator in SIMULATE mode via the Agent tool.

The orchestrator dispatches:

- **subagent_type**: `harness:generator`
- **description**: `"Simulate ${FEATURE} via prod-mode Playwright"`
- **prompt** (passed verbatim):

> You are being dispatched in SIMULATE mode (see your system prompt's MODE
> ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root.
> All `.harness/...` paths resolve from project root. The
> `.worktrees/current/.harness/` folder is a stale frozen snapshot — never
> read or write it. Source code lives in `.worktrees/current/src/...`;
> spec, contract, and report files stay under project-root `.harness/`. If
> you `cd .worktrees/current` for a Bash command, `cd` back before any
> `.harness/` Read/Write, or use `$CLAUDE_PROJECT_DIR/.harness/...`
> absolute paths.
>
> Drive the production-mode runtime through the contract's State-Transition
> AC + Negative-Path Coverage tables. Replay all prior features'
> tests/e2e/<NNN>/journey.spec.ts cumulatively. Write your verdict to
> .harness/features/${FEATURE}/simulation-report.md per the template at
> @templates/features/simulation-report.md.txt with **Verdict**: VERIFIED |
> NEEDS-REPAIR header.
>
> Mandatory reads BEFORE driving:
> - .harness/features/${FEATURE}/contract.md (final, with State-Transition
>   + Negative-Path tables)
> - .harness/features/${FEATURE}/implementation-report.md
> - .harness/features/${FEATURE}/proposal.md
> - .harness/spec/prd.md § "User Journeys" + § "UI-Surface Audit"
> - manifest.yaml → features.completed[]

After dispatch returns:

1. Extract the line matching `\*\*Verdict\*\*: (VERIFIED|NEEDS-REPAIR)`.
2. **If VERIFIED:** orchestrator updates `state.phase = "evaluating"` and
   proceeds to Step 4.
3. **If NEEDS-REPAIR:** for v3.0, **proceed to Step 4 anyway**. Evaluator's
   Part A binary check will FAIL on gap rows (per updated Step 2a in
   evaluator.md), triggering standard retry loop. Inner repair loop
   (auto-retry Generator BUILD with simulation-report context) deferred to
   v3.1 per spec § 3 N2.
4. **If simulation-report.md missing or malformed** (no verdict header):
   treat as SIMULATE failure. Block merge; ask user to rerun via
   `/harness:resume` or rewind.

---

## 4. Evaluate — dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

The setup-required gate already ran before SIMULATE in Step 3.5. If the Evaluator discovers missing setup anyway, report it as infrastructure/setup failure rather than spending a retry on Generator BUILD.

**4b. Evaluator dispatch.** The orchestrator dispatches the Evaluator via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Evaluate ${FEATURE} via Playwright"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in EVALUATE mode (see your system prompt's MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root. All `.harness/...` paths (`eval-report.md`, `criteria.md`, `examples.md`, `evaluator-notes.md`, `contract.md`, `proposal.md`, `review.md`, `constitution.md`, `prd.md`, `init.sh`) resolve from project root. The `.worktrees/current/.harness/` folder is a stale frozen snapshot — never read or write it. Source code to exercise lives in `.worktrees/current/src/...`; if `init.sh` needs to `cd` there to start the app, that's fine for launching the app, but always come back to project root for `.harness/...` writes like `eval-report.md`.
>
> Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan (Step 4.5), and write your verdict to .harness/features/${FEATURE}/eval-report.md per the template at @templates/features/eval-report.md.txt.
>
> Calibration-mandatory reads BEFORE scoring (all from project-root `.harness/`):
> - .harness/evaluator/examples.md (few-shot anchors)
> - .harness/spec/evaluator-notes.md (if exists)
> - .harness/evaluator/criteria.md
>
> Then: read implementation-report.md, contract.md, proposal.md, review.md, constitution.md, prd.md (via Read tool — all from project-root `.harness/`). Start the app with bash .harness/init.sh (also project-root). Exercise via Playwright.

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
