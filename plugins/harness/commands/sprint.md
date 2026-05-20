---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → simulate (prod runtime + cumulative regression) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1-4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → create team + spawn teammates → Plan → analyze → human gate → Generator ↔ Evaluator negotiate → Build (TDD) → Simulate → Evaluate → retry-or-retrospective → merge → team cleanup. Pipeline phases run as a dependency-chained task list (T1–T10) on a single agent team led by the orchestrator (the lead); the persistent planner / generator / evaluator teammates self-claim each task when its dependencies clear. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before creating the team.

---

## 0a. Brainstorm check — ambiguity gate (optional)

Before touching the environment, scan the prompt for vagueness signals:

- Prompt ≤2 sentences AND no concrete verbs (build, implement, create, fix, migrate, refactor).
- Uncertainty words: `maybe`, `not sure`, `I think`, `figure out`, `help me decide`.
- Multiple plausible interpretations (e.g., "a dashboard").
- Unfamiliar domain with no prior features in `manifest.yaml`.

If ANY signal hits, offer the user: run `/harness:brainstorm` first (recommended), proceed anyway (Planner will use AskUserQuestions to clarify), or cancel.

If NO signal hits, skip this step silently.

If `.harness/brainstorm-current.md` exists from a prior brainstorm session, treat its content as additional context for the T1 Plan task assignment in Step 1. After the planner teammate reports T1 done and the feature folder exists, the lead moves `brainstorm-current.md` into the feature folder as `brainstorm.md`.

---

## 0b. 1M-context confirmation (recommended — prevents T6 Build truncation)

Before spawning any teammate, the lead confirms the user's Claude Code session is on the 1M-context Opus variant. Multi-stratum sprints (foundation features, full-stack work) routinely exceed the default 200K Opus context during the T6 Build task; truncation produces no `implementation-report.md` and forces the lead to re-open T6.

Print this prompt and wait for user input:

> This sprint keeps the generator teammate on the T6 Build task for 30+ minutes on multi-stratum work. Confirm Claude Code was launched with `claude --model claude-opus-4-7[1m]` for the 1M-context variant. (Y to proceed / N to relaunch first.)

On `N`: print *"Relaunch Claude Code with: `claude --model claude-opus-4-7[1m]`, then re-run /harness:sprint"* and exit. On `Y`: continue to Step 0c. On any other input: re-prompt once, then proceed cautiously with a logged warning in `progress/changelog.md`.

Rationale: Claude Code does not currently expose `--model` to plugin scripts, so this is user-confirmation, not mechanical detection. The teammates inherit the lead's session model, so a 1M-context launch covers the whole team. See `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md` § 6.1 for why.

---

## 0c. Doctor — environment preflight (mandatory, blocking)

Before creating the team or spawning any teammate, run the doctor:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

- `DOCTOR_EXIT = 0`: environment ready, proceed.
- `DOCTOR_EXIT = 1`: CRITICAL failure. Show the doctor's report (with fix suggestions) and STOP. Tell the user: "Fix the items above, then re-run `/harness:sprint \"$ARGUMENTS\"`."
- `DOCTOR_EXIT = 2`: doctor itself errored. Hard stop. Show stderr. Tell the user to run the doctor manually and investigate.

See [doctor.md](doctor.md) for what it checks.

---

## 0d. Create team + spawn teammates (lead, blocking)

Doctor has passed (Step 0c ran the environment preflight). The orchestrator now becomes the **team lead** and stands up the agent team that will run the whole pipeline. See SKILL.md § Agent Team Protocol for the full contract this step implements.

1. **Verify the team runtime.** Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set and Claude Code is v2.1.32+ (the env preflight in Step 0c established the baseline; the lead verifies this teams-specific requirement before creating the team). If either is missing, STOP and tell the user to enable it (settings.json `env` block or shell export) — the team protocol cannot run without it. There is no subagent fallback on this branch (hard-replace).

2. **Create one team** for the sprint, named `harness-<feature-slug>` (derive the slug from `$ARGUMENTS`; reconcile with the Planner's `features/NNN-name/` once T1 completes). One team per lead, one team at a time (platform limit); the team persists for the whole sprint.

3. **Spawn three long-lived teammates** by their plugin-declared agent type — the same definitions used as subagents on `main`:

   | Teammate name | Agent type | Roles it plays (lead assigns MODE per task) |
   |---|---|---|
   | `planner` | `harness:planner` | PLAN (PASS 1+2), CLARIFY-QUESTIONS, EDIT |
   | `generator` | `harness:generator` | NEGOTIATE, FINALIZE-CONTRACT, BUILD, SIMULATE |
   | `evaluator` | `harness:evaluator` | REVIEW-PROPOSAL, EVALUATE, REVALIDATE |

   Spawn the `planner` with **plan-approval required** — when it finishes T1 it submits its plan to the lead, who relays it to the human (this is how the mandatory human gate in Step 2 is enforced).

4. **Build the shared task list** as a dependency chain mirroring the pipeline. Dependencies enforce sequential ordering through the parallel team mechanism — a teammate cannot self-claim a task until its dependency completes:

   | Task | Owner | Depends on | MODE assigned |
   |---|---|---|---|
   | T1 Plan | planner | — | PLAN (plan-approval → human gate) |
   | T2 Analyze | lead | T1 | lead runs `/harness:analyze` logic |
   | T3 Negotiate | generator | T2 + gate | NEGOTIATE |
   | T4 Review proposal | evaluator | T3 | REVIEW-PROPOSAL |
   | T5 Finalize contract | generator | T4 | FINALIZE-CONTRACT |
   | T6 Build | generator | T5 | BUILD (TDD) |
   | T7 Simulate | generator | T6 | SIMULATE |
   | T8 Evaluate | evaluator | T7 | EVALUATE |
   | T9 Repair (conditional) | generator | T8 if FAIL | BUILD (retry) → re-opens T7 |
   | T10 Retrospective | lead | T8 if PASS | lead runs retrospective logic |

   The negotiate↔review loop (T3↔T4, ≤3 rounds) is the lead re-opening T3/T4 until the proposal converges. To bias the lead's gate judgment, pass the user's gate instructions ("only approve if scope ≤ N FRs", etc.) to the lead.

Once the team exists, the teammates are persistent for the rest of the sprint: the steps below are written as the **lead opening / re-opening each Tn task to the right teammate**, not as fresh per-phase dispatches. Manifest-state transitions stay lead-owned throughout.

---

## 1. Plan — open T1 (Plan) to the planner teammate (two-pass)

The Planner works in two passes:
- Pass 1: PRD + constitution (the WHAT and WHY).
- Pass 2: Architecture + criteria + contract (the HOW — informed by Pass 1).

Agent-definition pattern (v2.1.0+): the planner teammate resolves to the plugin-shipped agent type declared in `plugin.json` via `"agents": "./agents/"`. Its system prompt, allowed tools, and identity come from `agents/planner.md` frontmatter; the teammate was spawned from this definition in Step 0d.

If a brainstorm file exists, the lead includes its content in the T1 task assignment as additional context.

The lead opens task T1 (Plan) to the planner teammate. The task assignment carries the MODE sentence + task framing + file list / user request below:

> Claim T1 in PLAN mode (see your system prompt for the full role and 2-pass procedure).
>
> Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the generator. Run your 19-point self-validation before reporting T1 done, and report the pass count to the lead.
>
> User request:
> $ARGUMENTS
>
> [If `.harness/brainstorm-current.md` exists, the lead appends its full content here under a `--- BRAINSTORM CONTEXT ---` marker before assigning the task.]

**After the planner teammate reports T1 done, the lead (not a teammate) performs these housekeeping steps using the Bash/Edit tools. These are natural-language instructions — not a shell script:**

1. Verify the planner actually wrote the expected files (spec/, evaluator/criteria.md, features/NNN-name/contract.md, init.sh, manifest.yaml, ROADMAP.md). If any is missing, halt and ask the user.
2. If `.harness/brainstorm-current.md` still exists and the feature folder now exists, move the brainstorm file into the feature folder as `brainstorm.md`.
3. Make `.harness/init.sh` executable. The planner has no Bash tool, so it cannot chmod its own output.

Then relay the human gate in Step 2 (the planner submitted its plan for approval when it completed T1).

---

## 2. Human gate — relay plan-approval, wait for approval

This gate is the plan-approval the planner teammate submitted to the lead on completing T1 (Step 0d spawned it with plan-approval required). The lead relays the plan to the human and summarises what was planned:

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

Next:
  • approved               → negotiate + build
  • /harness:clarify       → surface ambiguities, answer, auto-patch
  • /harness:amend "<X>"   → targeted tweak
  • /harness:edit "<X>"    → multi-file spec edit
  • /harness:rewind planning → fundamental re-plan
═══════════════════════════════
```

**Do NOT proceed until the user explicitly approves.** This is the only mandatory human gate. On approval, the lead clears the plan-approval and unblocks T3 (Negotiate); the generator teammate self-claims it once T2 has also completed.

If the user wants changes, route through a command — the lead never edits spec files from its own context (see SKILL.md § File Ownership Contract).

**Auto-suggest `/harness:clarify`** if: Planner self-validation mentioned ≥3 silent defaults, OR user's approval text contains uncertainty words ("maybe", "not sure", "probably").

---

## 2b. Analyze — cross-artifact consistency (automatic) — task T2 (lead-owned)

T2 is a lead-owned task (no teammate). The lead runs the [`/harness:analyze`](analyze.md) procedure. CRITICAL findings halt; warnings pass through.

The lead updates `.harness/manifest.yaml` → `state.phase = "negotiating"` (Edit tool), then marks T2 done so the (already-approved) T3 dependency clears.

---

## 2c. Negotiate — Generator ↔ Evaluator agree on sprint contract (automatic)

Three task assignments in sequence (T3 → T4 → T5), all routed through the lead — the generator and evaluator teammates NEVER message each other (GAN separation; see SKILL.md § GAN separation inside a team). The lead reads `state.current_feature` from manifest.yaml before each assignment to get the `${FEATURE}` value.

**Round 1 (T3 Negotiate): generator writes proposal.md** — the lead opens task T3 (Negotiate) to the generator teammate. Task assignment:

> Claim T3 in NEGOTIATE mode (see your system prompt's MODE ROUTING table).
>
> Do NOT write code in this mode. Read the draft contract, architecture direction, constitution, and criteria via Read tool. Write your implementation proposal to .harness/features/${FEATURE}/proposal.md per the template at @templates/features/proposal.md.txt. Report T3 done to the lead — do not message the evaluator.

**Round 2 (T4 Review-proposal): evaluator reviews the proposal** — after the generator reports T3 done, the lead opens task T4 (Review-proposal) to the evaluator teammate. Task assignment:

> Claim T4 in REVIEW-PROPOSAL mode (see your system prompt's MODE ROUTING table).
>
> Do NOT run Playwright — there is no app yet. Judge from files only. Read (all via Read tool):
> - `.harness/evaluator/criteria.md` — grading rubric
> - `.harness/features/${FEATURE}/contract.md` — Planner's draft contract
> - `.harness/features/${FEATURE}/proposal.md` — Generator's proposed HOW
> - `.harness/spec/constitution.md` — use it to judge test-strategy adequacy + HOW-level coding-standard compliance (v2.1.3+)
> - `.harness/spec/architecture.md` — use it to verify the proposal's component/directory/data-model choices align with the declared architectural style (v2.1.3+)
>
> PRD is NOT needed at this stage — the contract already contains the NFR targets. Write your review to `.harness/features/${FEATURE}/review.md` per the canonical template at `@templates/features/review.md.txt` with a VERDICT line (agreed | needs-revision). Report T4 done to the lead — do not message the generator.

**Iterate**: if the verdict is `needs-revision`, the lead re-opens T3 to the SAME persistent generator teammate (NEGOTIATE mode) to revise proposal.md, then re-opens T4 to the evaluator to review again. Max 3 rounds (per `config.max_negotiation_rounds` in manifest). By round 3, continued disagreement signals an unclear upstream contract (the Planner's what/why is ambiguous), not a negotiation problem. More rounds won't resolve a values or clarity gap; human judgment will.

**If no agreement after 3 rounds, the lead escalates to the human with this structure:**

- **The blocker** (one sentence): what the generator wants vs what the evaluator wants, at the narrowest point of disagreement.
- **Why it's stuck** (one sentence): which upstream artifact is ambiguous — usually the draft contract, sometimes the architecture or constitution.
- **The decision being asked of you**: pick (a) force the generator's proposal as-is, (b) force the evaluator's asks as-is, (c) rewrite the draft contract to resolve the ambiguity (run `/harness:amend` or `/harness:edit`), (d) abandon the feature.

**Final (T5 Finalize-contract): generator writes the negotiated contract** — once the evaluator's verdict is `agreed`, the lead opens task T5 (Finalize-contract) to the generator teammate. Task assignment:

> Claim T5 in FINALIZE-CONTRACT mode. Merge proposal.md + review.md into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (MUST include **Negotiated**: marker). Do NOT update manifest.yaml — the lead handles phase transitions.

**After the generator reports T5 done**: the lead updates `.harness/manifest.yaml` → `state.phase = "building"` using the Edit tool, which clears the T6 dependency.


---

## 3. Build — open T6 (Build) to the generator teammate

Create the worktree:

```bash
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true
```

**Note on the worktree's stale `.harness/`:** the checkout includes a frozen snapshot of `.harness/` at `.worktrees/current/.harness/` as a git-worktree side-effect. It is stale and must not be read or written by any teammate or lead step. The live `.harness/` is at project root. See SKILL.md § File Ownership Contract → Working directory and `.harness/` location. The T6 task assignment below restates this rule inline so the generator has it in context.

Assemble the task context. The generator reads most files via its own Read tool — the inline file list in the assignment is a hint, not authoritative. Prefer per-FR section reads (grep by FR-NNN ID against contract.md) per TDD cycle over the full aggregate contract.

If `.harness/features/${FEATURE}/eval-report.md` exists (this is a retry — see the retry loop in Step 5, which re-opens T9 Repair → T6 Build), the lead reads its content and appends it to the task assignment under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before the user-request block.

The lead opens task T6 (Build) to the generator teammate. Task assignment:

> Claim T6 in BUILD mode (see your system prompt's MODE ROUTING table).
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
> [If `.harness/features/${FEATURE}/eval-report.md` exists, the lead appends its full content here under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before assigning the task.]

---

## 3a. Pause check — the generator may have requested user input mid-build

If `.harness/features/${FEATURE}/pause-questions.md` exists after the generator reports T6 done (or pauses against it), the generator paused and needs answers.

Loop (up to `MAX_PAUSES = 3`):
1. Read pause-questions.md; present each question to the user with its "default if unanswered" fallback.
2. Collect answers. Each answer is either a user response, "accept default", or "skip" (marks FR partial).
3. Archive the pause file: move to `.harness/features/${FEATURE}/paused-history/pause-N-TIMESTAMP.md`.
4. The lead increments `manifest.yaml → config.calibration_metrics.agent_checkins` by 1 using the Edit tool.
5. The lead re-opens T6 (Build) to the SAME persistent generator teammate (same BUILD-mode task framing from Step 3), with TWO blocks appended to the end of the assignment: (a) the `## State at pause` section verbatim from `pause-questions.md` under a `--- PAUSE STATE SNAPSHOT (authoritative — prefer over manifest if they disagree) ---` marker, and (b) the collected answers under a `--- PAUSE ANSWERS ---` marker.
6. If a new `pause-questions.md` appears after the re-opened T6, loop again.

After `MAX_PAUSES`, escalate: "The generator has paused N times on this sprint — the contract is likely under-determined. Recommend `/harness:rewind negotiating` to re-spec the affected FR(s) before continuing." Halt the sprint.

The lead updates `.harness/manifest.yaml` → `state.phase = "simulating"` after the generator reports T6 done successfully, which clears the T7 dependency (Step 3.5 then transitions `simulating → evaluating` on VERIFIED).

---

## 3.5. Simulate — drive prod-mode runtime (automatic)

After the generator reports T6 Build done successfully (and the
pause-protocol loop in Step 3a has resolved), the lead updates `manifest.yaml →
state.phase = "simulating"` (Edit tool) and opens task T7 (Simulate) to the
SAME persistent generator teammate.

The lead opens task T7 (Simulate). Task assignment:

> Claim T7 in SIMULATE mode (see your system prompt's MODE
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

After the generator reports T7 done:

1. Extract the line matching `\*\*Verdict\*\*: (VERIFIED|NEEDS-REPAIR)`.
2. **If VERIFIED:** the lead updates `state.phase = "evaluating"` (which
   clears the T8 dependency) and proceeds to Step 4.
3. **If NEEDS-REPAIR:** for v3.0, **proceed to Step 4 anyway**. The evaluator's
   Part A binary check will FAIL on gap rows (per updated Step 2a in
   evaluator.md), triggering the standard retry loop. Inner repair loop
   (the lead auto-re-opening T6 Build with simulation-report context)
   deferred to v3.1 per spec § 3 N2.
4. **If simulation-report.md missing or malformed** (no verdict header):
   treat as SIMULATE failure. Block merge; ask user to rerun via
   `/harness:resume` or rewind.

---

## 4. Evaluate — open T8 (Evaluate) to the evaluator teammate (judges from files only)

The evaluator teammate judges from files only; GAN separation is preserved by lead-mediation + file-only handoff, not by platform isolation (the evaluator never receives generator mailbox content — see SKILL.md § GAN separation inside a team). The evaluator has been idle since T4; when it claims T8 it reads contract.md + simulation-report.md + source, never any build-task chatter.

**4a. Setup-required gate (v2.1.9+).** Before opening T8 to the evaluator, the lead reads `.harness/features/${FEATURE}/implementation-report.md` → `## Setup required` section. If it lists required files that the user must create (e.g., `.env.local`) OR other user-completable steps (database migrations with user credentials, external service config), the lead:

1. Checks whether each required file exists at the project-root path.
2. If all required files exist AND the report doesn't flag remaining user steps, proceed to 4b (open T8 to the evaluator).
3. Otherwise: present the Setup section to the user verbatim, with a message like *"The generator finished building. Before I open the evaluation task, complete this setup: [list]. Type 'continue' when ready."* Wait for confirmation. Do NOT auto-retry or skip — an evaluation run against an app that can't start produces a false FAIL that wastes retry budget.

This gate exists because the app under test often needs secrets (DB URLs, API keys, signing keys) that the generator cannot write (AgentLint's `no-env-commit` + `no-secrets` rules are unsuppressible errors, by design). The two-file convention `.env.example` (generator) + `.env.local` (user) hands off cleanly at this gate.

**Test-account env vars (v3.0+).** If the implementation-report's
`## Setup required` section lists any `TEST_USER_*` or `TEST_TENANT_*` /
`TEST_FIRM_*` env vars (the T6 Build task adds these to `.env.example` for
auth-gated apps per the Test-account placeholders rule), the lead
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

**4b. Open T8 (Evaluate).** The lead opens task T8 (Evaluate) to the evaluator teammate. Task assignment:

> Claim T8 in EVALUATE mode (see your system prompt's MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root. All `.harness/...` paths (`eval-report.md`, `criteria.md`, `examples.md`, `evaluator-notes.md`, `contract.md`, `proposal.md`, `review.md`, `constitution.md`, `prd.md`, `init.sh`) resolve from project root. The `.worktrees/current/.harness/` folder is a stale frozen snapshot — never read or write it. Source code to exercise lives in `.worktrees/current/src/...`; if `init.sh` needs to `cd` there to start the app, that's fine for launching the app, but always come back to project root for `.harness/...` writes like `eval-report.md`.
>
> Judge from files + the running app only — do NOT request or read any generator mailbox content (GAN separation). Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan (Step 4.5), and write your verdict to .harness/features/${FEATURE}/eval-report.md per the template at @templates/features/eval-report.md.txt.
>
> Calibration-mandatory reads BEFORE scoring (all from project-root `.harness/`):
> - .harness/evaluator/examples.md (few-shot anchors)
> - .harness/spec/evaluator-notes.md (if exists)
> - .harness/evaluator/criteria.md
>
> Then: read implementation-report.md, contract.md, proposal.md, review.md, constitution.md, prd.md (via Read tool — all from project-root `.harness/`). Start the app with bash .harness/init.sh (also project-root). Exercise via Playwright.

---

## 5. Result — lead reads the evaluator report and decides

The lead reads `.harness/features/${FEATURE}/eval-report.md` after the evaluator reports T8 done, extracts the `**Result: PASS / FAIL**` line, and reads `state.retry_count` vs `config.max_retries` from manifest.yaml.

### If PASS

**5a-pre. Tuning check — capture human-Evaluator divergence (automatic)**

This implements the Anthropic-documented tuning loop. The lead presents the evaluator's judgment (read from eval-report.md, not from any mailbox exchange) to the user:

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

**5a. Retrospective — drift analysis (MANDATORY) — task T10 (lead-owned)**

T10 is a lead-owned task (no teammate). The lead runs `/harness:retrospective` (see retrospective.md). Writes `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update spec files + ADR.

If the retrospective itself fails (errors, malformed output), do NOT silently skip. Block merge, write a stub retrospective.md noting the failure, ask the user to retry / run manually / merge-without-retro with explicit confirmation.

**5b. Merge**

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [one-line summary]"
git worktree remove .worktrees/current 2>/dev/null
```

Then the lead (via Edit tool) updates:
- `ROADMAP.md` — move feature to "✅ Shipped".
- `.harness/manifest.yaml` — `features.completed` append, `features.in_progress = ""`, `state.phase = "complete"`, `state.retry_count = 0`.

**Team cleanup (lead, end of sprint).** With T10 done and the merge committed, the lead cleans up the agent team it created in Step 0d: confirm the planner / generator / evaluator teammates are idle (or shut them down first), then tear down the `harness-<feature-slug>` team. Only the lead cleans up — never a teammate (the platform forbids teammate cleanup), and the cleanup frees the one-team-at-a-time slot for the next sprint.

Print scores + completion message.

### If FAIL and retries < max

The lead updates `manifest.yaml` → `state.retry_count += 1`, `state.phase = "building"`. Prints failing scores + critical findings. The lead opens task T9 (Repair) to the SAME persistent generator teammate — a BUILD-mode retry with the eval-report.md content appended as `--- EVALUATOR FEEDBACK (fix these) ---` (the Step 3 task framing, re-used). T9 re-opens T7 (Simulate) on completion, which then re-runs T8 (Evaluate); mechanically this is the same loop as re-opening T6 Build → T7 Simulate.

Before retry: run the same tuning check from 5a-pre, but with the reversed framing: "Do you agree the evaluator should have failed this?" Log divergences. Proceed to retry regardless.

### If FAIL and retries ≥ max

Present the user with options:
1. Force merge with known issues.
2. Manually fix and re-run `/harness:resume` (picks up from evaluating phase).
3. Increase `config.max_retries` and continue.
4. Abandon.

---

## Constraints

- The evaluator is a separate teammate that judges from files only; GAN separation is preserved by protocol (lead-mediation + file-only handoff), not platform isolation. The generator and evaluator MUST NOT exchange mailbox messages.
- All artifacts go in `.harness/features/NNN-name/`.
- Atomic commits on the build branch: `[harness:<phase>] <description>`.
- Teammates are workers, not managers — they self-claim their assigned tasks but NEVER manage the team or re-invoke the harness pipeline (only the lead creates, advances, and cleans up the team).
- The lead does NOT edit spec files directly (see SKILL.md § File Ownership Contract). Use `/harness:amend`, `/harness:edit`, `/harness:clarify`, or `/harness:constitution-amend`.
