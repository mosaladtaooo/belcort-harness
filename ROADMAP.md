# BELCORT Harness — Roadmap

This file tracks what's shipped, what's active, and what's parked for future releases. For per-release detail, see [CHANGELOG.md](CHANGELOG.md).

## Format

Each watch-list item uses this 4-field format:
- **What**: one-sentence description.
- **Why parked**: why it's not happening now.
- **When to revisit**: the specific condition that would promote it into active work.
- **Context**: links to commits, CHANGELOG entries, or conversation notes.

"When to revisit" is a condition, not a date. Conditions don't go stale; dates do.

---

## Shipped

See [CHANGELOG.md](CHANGELOG.md) for per-release detail.

| Version | Date | Summary |
|---|---|---|
| 3.1.1 | 2026-05-10 | Monitor integration — real-time worker readiness/failure streams in SIMULATE + Evaluator worker-side forensics |
| 3.1.0 | 2026-05-08 | Verification augmentation — worker readiness signal + axe-core a11y + code-reviewer integration + Stryker mutation + fast-check property + MADR ADR matrix + size-limit budget + refactor pattern stub |
| 3.0.0 | 2026-05-07 | Runtime-verification phase + audit pass — Generator SIMULATE mode + contract template tightening + Evaluator Step 2 lightening + audit polish |
| 2.2.0 | 2026-04-28 | Stale-assumption pruning + operational hardening — story files removed, `/harness:negotiate` standalone removed, Planner mode collapse (6 → 3), pause snapshot, 1M-context banner |
| 2.1.9 | 2026-04-24 | Secrets-handling contract (.env.example vs .env.local) + Evaluator setup-required gate |
| 2.1.8 | 2026-04-24 | Worktree cwd contract — root `.harness/` authoritative, frozen worktree copy never read |
| 2.1.7 | 2026-04-24 | Frontmatter tuning — `model: inherit`, `effort: max`, `maxTurns: 2000` on all three agents |
| 2.1.6 | 2026-04-23 | AgentLint config file fix (`.agentlint.toml` → `agentlint.yml`) |
| 2.1.5 | 2026-04-23 | Planner feature-size gate + pre-TDD scaffolding commit rule + SKILL.md Recovery expanded |
| 2.1.4 | 2026-04-23 | Evaluator tuning category vocabulary alignment + tune-evaluator watch-list |
| 2.1.3 | 2026-04-23 | Removed ~413 lines of inline-template duplication + REVIEW-PROPOSAL reads constitution.md + architecture.md |
| 2.1.2 | 2026-04-22 | Stress-test patches (Windows python3 stub, `/quick` spec-drift, `/clarify` ADR gap) |
| 2.1.1 | 2026-04-22 | Dropped `tools:` frontmatter allowlist + project-tools propagation |
| 2.1.0 | 2026-04-21 | Native Agent-tool subagent dispatch (migrated from `claude -p` subprocess) |
| 2.0.0 | 2026-04-21 | Minimalist refactor — Planner → Generator → Evaluator pipeline rewrite |
| 1.5.x | (prior) | Prior stable; see git tags |

## v3.1.1 — Shipped 2026-05-10

- Monitor preferred path in SIMULATE Step 2.6 for real-time worker readiness + failure detection.
- Bash polling fallback preserved for environments where Monitor cannot be loaded.
- Optional parallel Monitor stream during SIMULATE Steps 3-5 Playwright driving.
- Evaluator Step 2b can stream the worker log path recorded by SIMULATE and attach captured stack traces to eval-report findings.
- `simulation-report.md` surfaces real-time captures separately from post-hoc tail output.

## v3.1.0 — Shipped 2026-05-08

- Worker readiness signal via stdout pattern matching (replaces 30s polling)
- axe-core accessibility scanning per State-Transition row (PRD WCAG-Level declared via AskUserQuestions)
- superpowers code-reviewer integration in Evaluator Step 3a (anti-leniency preservation rules mandatory; soft-fallback if not installed)
- Stryker.js mutation testing (per-FR scored against NEGOTIATE-declared targets; closes semantic test-weakness bug class)
- fast-check property-based testing (NEGOTIATE per-FR eligibility; race-condition detection via fc.scheduler)
- MADR ADR matrix with Context7-verified alternatives (closes familiarity-bias bug class; new V8b self-validation; 18-point → 19-point)
- size-limit bundle-size budget (deterministic gate via Evaluator Step 4)
- Refactor pattern documentation (Generator RED FLAG + SKILL.md § Refactor Pattern; NO new command)
- 8 new docs/anthropic-alignment.md decision-map rows
- 7 v3.2 deferrals tracked with explicit "When to revisit" conditions

## v3.0.0 — Shipped 2026-05-07

- Generator gains MODE: SIMULATE (drives prod build + worker + Playwright + DB queries before Evaluator handoff)
- Cumulative regression replay across all shipped features (per-feature `tests/e2e/<NNN>/journey.spec.ts`)
- Contract template gains State-Transition AC + Negative-Path Coverage + UI-surface AC sections
- Catch-block ban as new constitution MUST principle (canonical baseline; existing projects opt-in via /constitution-amend)
- Evaluator EVALUATE Step 2 lightens (reads simulation-report.md as authoritative; Step 2a + Step 2b spot-check)
- Planner Pass 2 brainstorming pass over user-journey ACs (closes Bug #8 class at spec time)
- Audit polish (Phase 2): factor HANDLING FETCHED CONTENT preamble into SKILL.md; downgrade pre-tool-use.sh test-deletion hard-block to advisory; remove ~16 lines of dead manifest fields
- Self-validation grew 16 → 18 points in Planner Pass 2 (V17 + V18)

## v2.2.0 — Shipped 2026-04-28

- Per-FR story files removed (stale BMAD-V6 assumption on Opus 4.7[1m])
- `/harness:negotiate` standalone removed (procedure preserved in sprint.md § 2c)
- Planner internal mode collapse (6 → 3; user-facing commands unchanged)
- Generator pause `State at pause` snapshot for resume safety
- Doctor + sprint 1M-context confirmation banner
- Soft-only Planner feature-size gate (advisory; trust the model)

## In Progress

_(Nothing active — `main` is at v3.1.1; future work remains in the watch list below.)_

---

## v3 Watch List

Deferred items with non-trivial value. Revisit when the "When to revisit" condition fires.

### 1. Parallel subagent dispatch patterns
- **What**: make naturally-parallelizable pipeline phases actually run in parallel — REVALIDATE across shipped features, `/harness:audit` dimension scans, Planner A/B decomposition.
- **Why parked**: current pipeline is structurally sequential. Most phases depend on prior phase outputs. Adding parallel machinery without a concrete parallel use case = YAGNI.
- **When to revisit**: when a specific parallel phase has concrete demand — e.g., `/harness:constitution-amend` on a project with ≥10 shipped features where serial REVALIDATE becomes painful.
- **Context**: discussed 2026-04-24 (fork-subagent research). Claude Code v2.1.117+ ships a fork-subagent cost optimization that shares parent's cached system prompt across N parallel children — natural pair for any parallel phase we build. Our sequential pipeline can't benefit today.

### 2. Per-agent model configuration
- **What**: wire `manifest.harness.model` into Agent-tool dispatch; add optional per-agent override (e.g., Planner on Opus, Generator on Opus, Evaluator on Sonnet for cost savings).
- **Why parked**: currently subagents inherit the parent session's model. No user-visible pain yet — Opus 4.7 handles all three roles well.
- **When to revisit**: when cost-per-sprint becomes measurable pain OR when Sonnet-for-Evaluator quality is validated on a real project (adversarial testing may be more mechanical than planning; Sonnet may be sufficient).
- **Context**: discussed 2026-04-23 after BELCORT ACCOUNTING stress-test debrief. The `harness.model` field in `templates/manifest.yaml:7` is currently informational — no code reads it at dispatch.

### 3. Parallel `/harness:audit` dimension scans
- **What**: dispatch N audit sub-scans in parallel (constitution violations, test coverage debt, spec drift, ADR rot, etc.) instead of serial.
- **Why parked**: current `/harness:audit` runs one orchestrator-driven pass through all dimensions; acceptable for today's feature counts.
- **When to revisit**: when `/audit` latency becomes noticeable on projects with ≥20 shipped features.
- **Context**: candidate consumer of the fork-subagent pattern (see item 1).

### 4. Parallel `/harness:constitution-amend` REVALIDATE across shipped features
- **What**: after a constitution amendment, re-evaluate all shipped features in parallel rather than serial.
- **Why parked**: REVALIDATE today is serial. For projects with few shipped features, serial is fine.
- **When to revisit**: when a user has ≥10 shipped features and reports REVALIDATE taking too long after an amendment. Strongest natural fit for fork-subagent.
- **Context**: discussed 2026-04-24 as the highest-leverage fork-subagent use case in the harness.

### 5. Planner A/B decomposition proposals
- **What**: at Pass 2, spawn 2 Planner forks with different architectural priors (e.g., monolith vs microservices), compare outputs, let human pick.
- **Why parked**: speculative. Current single-proposal Planner works well. Adds human decision fatigue without validated benefit.
- **When to revisit**: when a user reports "the Planner keeps picking the wrong architecture and I want to see alternatives."
- **Context**: discussed 2026-04-24 as a theoretical fork-subagent consumer.

### 6. Sparse-checkout for mechanical worktree `.harness/` isolation
- **What**: use `git worktree add --no-checkout` + `git sparse-checkout set --no-cone '*' '!.harness'` at worktree creation, so `.worktrees/current/.harness/` never physically appears.
- **Why parked**: v2.1.8 ships prose + prompt-discipline fix (SKILL.md Working Directory Contract + dispatch prompts + resume.md guidance). Mechanical prevention via sparse-checkout adds Windows-compat fragility (path separators, case-sensitivity, git-for-Windows quirks) disproportionate to the confusion risk.
- **When to revisit**: if the prose-level fix proves insufficient in practice (e.g., a subagent still reads the stale `.harness/` despite the contract), or if Anthropic's GAN-isolation philosophy evolves toward requiring mechanical enforcement of ownership contracts.
- **Context**: discussed 2026-04-24. The `.gitignore` / `git rm --cached` approaches don't work (would cause squash-merge to delete main's `.harness/`); sparse-checkout is the correct mechanical path. See CHANGELOG v2.1.8 "Honest note on the mechanical fix that got deferred."

### 7. Standardize test-fixture lifecycle for SIMULATE
- **What**: spec a `.harness/test-fixtures/` convention with seed scripts so SIMULATE can drive auth-gated flows reliably without per-project glue.
- **Why parked**: surfaced during v3.0 implementation; not in spec scope. Today projects handle this informally via `init.sh` + Playwright fixture files. Acceptable per-project; problematic when SIMULATE is supposed to be a portable verification leg.
- **When to revisit**: after first canary sprint surfaces an auth-gated SIMULATE failure, OR when ≥3 projects independently invent the same test-fixture pattern.
- **Context**: discussed during v3.0 Batch 3 follow-up — the user asked how SIMULATE can drive a real e2e flow without test accounts and `.env.local` access.
- *Update 2026-05-08 (v3.0):* partial fix shipped — SKILL.md § Test-Fixture Pattern documents the canonical `fixtures.ts` convention; Generator NEGOTIATE+BUILD enforces it. Full standardization (e.g., DB-snapshot fixtures) deferred.

### 8. Worker readiness signal during SIMULATE Step 2
- **What**: standardize a `worker:health` script projects must implement, so SIMULATE Step 2 can wait for worker bind via a positive signal instead of port-bind heuristic + 30s timeout.
- **Why parked**: ports work for web servers; many workers don't bind ports. Today SIMULATE assumes 30s is enough for any worker to be "ready". Imperfect; not blocking for v3.0.
- **When to revisit**: when a SIMULATE timeout false-positives because a worker took >30s but was actually working.
- *Update 2026-05-08 (v3.0):* partial fix shipped — SIMULATE Step 3 retries first worker-dependent row 3x with 10s backoff. Positive readiness signal (e.g., HTTP health endpoint convention) deferred.
- *Update 2026-05-08 (v3.1):* CLOSED via Bash `run_in_background` + `until grep -q "<pattern>"` pattern. architecture.md declares `worker_ready_pattern`; convention-only fallback covers projects without explicit declaration. Monitor-based real-time variant deferred to v3.2 pending empirical Monitor-in-subagent confirmation.

### 9. Real-time worker log tailing during SIMULATE
- **What**: SIMULATE could `tail -f worker.log` in background and surface tail snippets in `simulation-report.md` if the worker crashes during Step 5 (cumulative regression).
- **Why parked**: today SIMULATE only sees Playwright tests fail with no root cause if the worker crashes mid-replay. Manual log inspection works as a workaround.
- **When to revisit**: after a real worker-crash incident during canary or post-release where root cause was hidden.
- *Update 2026-05-08 (v3.0):* partial fix shipped — SIMULATE Step 1 discovers log paths; Steps 3-5 tail on failure; Step 7 surfaces in `## Worker logs (on failure)` section. Real-time live tailing during dispatch (vs post-failure) still deferred.
- *Update 2026-05-08 (v3.1):* Still partial — v3.0's post-hoc tail-100 capture preserved as the v3.1 baseline. Real-time streaming via Monitor tool deferred to v3.2 (research subagent confirmed Monitor's signature but public docs don't confirm callability from plugin-declared subagents; sandbox empirical test required before integration).

### 10. Test-account convention
- **What**: define how SIMULATE creates / authenticates against test users (DB seed fixture vs Playwright signup-form-driven vs test-mode auth provider). Currently project-dependent.
- **Why parked**: heavily project-dependent (Clerk dev keys differ from custom auth differ from no-auth). Hard to standardize without project examples to abstract from.
- **When to revisit**: when ≥3 projects' test-account patterns are visible — extract the common shape into a convention.
- *Update 2026-05-08 (v3.0):* partial fix shipped — `TEST_USER_*` env-var convention + `init.sh` `seed_test_user` stub + setup-gate enumeration (now sprint.md Step 3.5). Auth-provider abstraction (Clerk/Auth0/custom) deferred.
- *Update 2026-05-08 (v3.1):* Stable in v3.1 — v3.0's `TEST_USER_*` env-var convention + init.sh `seed_test_user` stub continues. Auth-provider abstraction (Clerk vs Auth0 vs custom) remains deferred — research confirms each provider has its own admin API surface; right answer is convention + per-project examples in init.sh.

### 11. CLOSED — Real-time worker log tailing via Monitor tool (N1, deferred from v3.1)
- **What**: SIMULATE Steps 1, 3-5 use Claude Code's Monitor tool to stream worker stdout in real-time, reacting to ERROR/FATAL/panic patterns as they arrive.
- **Why parked**: Public Anthropic docs don't confirm Monitor is callable from plugin-declared subagents. v2.1.1+ tool-inheritance SHOULD include Monitor, but unverified.
- **When to revisit**: empirical sandbox test confirms Monitor invokes successfully from `harness:generator` subagent dispatched via Agent tool. OR: a real BELCORT project hits a worker crash that v3.1's post-hoc + readiness signal failed to surface root cause for.
- **Context**: research-subagent finding 2026-05-08. v3.0 ROADMAP item 9 partial-closure preserved; this is the upgrade path.
- *Update 2026-05-10 (v3.1.1):* CLOSED. Empirical research dispatched via
  research subagent (session a9ded9c27131fe4e1) confirmed Monitor IS callable
  from plugin-declared subagents. Shipped in v3.1.1 patch — SIMULATE Step 2.6
  preferred path uses Monitor + ToolSearch `select:Monitor` for real-time
  worker readiness + failure detection; Bash polling preserved as fallback.
  Steps 3-5 gain optional parallel Monitor stream for real-time crash
  detection during Playwright driving. Real-time captures surface in new
  simulation-report.md `## Worker logs (real-time captures, v3.1.1+)` section.
  Evaluator Step 2b also gains a parallel Monitor stream against the worker log path SIMULATE recorded — captured stack traces during the 15-min spot-check are appended to eval-report.md findings as worker-side evidence (upgrades SIMULATE Gap findings from "UI broke" to diagnostic-grade with stack context).

### 12. Parallel cumulative regression via fork-subagent (N2, deferred from v3.1)
- **What**: SIMULATE Step 5 dispatches N parallel sub-SIMULATE Generators (one per shipped feature's regression replay) in a single Agent-tool message; main consolidates results.
- **Why parked**: ROADMAP item 1's revisit condition not met. No real BELCORT project at N≥10 shipped features with documented serial-regression pain. Adding 180-250 LoC of fanout-merge complexity = YAGNI.
- **When to revisit**: a real project hits N≥10 shipped features and reports SIMULATE wall-clock time exceeding 15 minutes. OR: 1M-context launch becomes mechanically detectable AND BUILD truncation recurs despite [1m] launch.
- **Context**: confirmed via Anthropic canonical docs that `context: fork` is skill-only; CLAUDE_CODE_FORK_SUBAGENT excludes named subagents; subagents cannot spawn subagents. Architectural escape hatch is "multiple Agent-tool calls in one orchestrator message".

### 13. Visual regression via Playwright snapshots (N3, deferred from v3.1)
- **What**: Playwright `toHaveScreenshot()` baseline-diff at each State-Transition boundary in SIMULATE Step 3.
- **Why parked**: 4 documented Playwright issues (#20097, #29968, #31083, #2626) for OS-specific font-rendering deltas; per-OS baseline directories triple storage cost; LLMs don't ship more layout-shift bugs than humans. False-positive risk drowns Evaluator's anti-leniency protocol.
- **When to revisit**: ≥3 BELCORT projects ship UI features and flag screenshot regressions as recurring v3.0/v3.1 false-negatives. OR: Playwright resolves the documented font-rendering issues. OR: a hosted service (Argos, Chromatic, Percy) integrates cleanly with anti-leniency framing.
- **Context**: research-subagent finding 2026-05-08.

### 14. Cross-browser testing via Playwright projects (N4, deferred from v3.1)
- **What**: Playwright's `projects: [{name: 'chromium'}, {name: 'firefox'}, {name: 'webkit'}]` matrix in SIMULATE Step 5 cumulative regression.
- **Why parked**: Triples cumulative regression wall-clock time. Most BELCORT users today ship internal tools, not public-facing sites. No LLM-specific bug class.
- **When to revisit**: a real BELCORT project ships a public-facing feature where Chrome-only behavior is a documented user complaint.
- **Context**: research-subagent finding 2026-05-08.

### 15. Full Lighthouse CI Web Vitals (N5, deferred from v3.1)
- **What**: `@lhci/cli` integration for LCP/INP/CLS budget enforcement in SIMULATE Step 3 + Evaluator Step 4.
- **Why parked**: Lab-vs-field variance + shared-CI-runner CPU contention create persistent false-positive flakes. Bundle-size piece (G7) shipped in v3.1 as the deterministic portion.
- **When to revisit**: Lighthouse CI numberOfRuns + median patterns prove low-flake on a real BELCORT project's CI. OR: Web Vitals regression incident occurs that bundle-size budget alone wouldn't have caught.
- **Context**: research-subagent finding 2026-05-08.

### 16. /harness:refactor dedicated command (N6, deferred from v3.1)
- **What**: New 17th command for cross-cutting refactors. Generator BUILD gains REFACTOR sub-mode with binary AC contract. Evaluator gains thin EVALUATE-REFACTOR mode.
- **Why parked**: v2.2 mode-collapse precedent; speculative demand. v3.1 ships the stub (G8) directing refactor-shaped work to `/harness:quick`.
- **When to revisit**: telemetry shows ≥3 invocations of `/harness:quick "[refactor] ..."` with the v3.1 stub pattern. OR: a real BELCORT project reports the /quick-as-refactor pattern is insufficient.
- **Context**: research-subagent finding 2026-05-08. v3.1 stub explicitly tracks demand via the `[refactor]` description prefix convention.

### 17. Evaluator Context7 awareness for framework method verification (N7, deferred from v3.1)
- **What**: Evaluator Step 3 (or new Step 3d) queries Context7 for framework methods used by the implementation; flags MAJOR if implementation uses deprecated/incorrect API patterns.
- **Why parked**: Separable scope from v3.1's D3 (code-reviewer integration). v3.0+ code-reviewer dispatch already catches some API misuse — needs telemetry.
- **When to revisit**: After v3.1 ships and we have data on what code-reviewer catches vs what slips through. If pattern-of-misuse correlates with API-version drift, Context7 verification is the targeted fix.
- **Context**: research-subagent finding 2026-05-08 (Subagent 3, Category C+D).

---

## Legacy v2.2 Watch List

Items deferred from the v2.2 audit that may become load-bearing on future model regressions or revealed-by-use:

- **Stratum-splitting BUILD into N dispatches.** Premature on confirmed-1M sessions. Revisit only if truncation recurs after Change #1 lands.

  *Update 2026-05-07 (v3.0):* SIMULATE pulls runtime work *out* of BUILD's
  context budget. Truncation pressure that motivated this watch-list item is
  reduced. Revisit only if BUILD truncation recurs post-v3.0 despite the
  [1m] launch.
- **Pause-mechanic full unification** (Planner AskUserQuestions vs Generator file-based). Asymmetry is correct on current models; revisit if Planner sessions ever grow long enough to need file-based pauses.
- **Mechanical 1M-context detection from doctor.sh.** Requires Claude Code to expose `--model` to plugin scripts. Track upstream and promote the v2.2 advisory banner to a real check when available.

  *Update 2026-05-08 (v3.0):* priority elevated to medium per spec § 8.2 — v3.0's
  cumulative regression replay during SIMULATE compounds context cost with
  shipped-feature count, making the 1M-context launch load-bearing for projects
  past 5 features. Without it, SIMULATE's cumulative regression at scale will
  likely exhaust the 200K context.

  *Update 2026-05-08 (v3.1):* priority remains medium per spec § 8.2 — v3.1's Stryker incremental + code-reviewer dispatch + axe-core analysis modestly increase context budget per Evaluator dispatch (~+30-90s wall-clock). Cumulative regression at scale remains the dominant context-consumer. No change in revisit condition; still tracking upstream Claude Code exposure of `--model` to plugin scripts.
- **Audit-family merge** (`/analyze`, `/validate`, `/audit`, `/retrospective`, `REVALIDATE`). Each answers a distinct question per `SKILL.md` § Audit Commands. Revisit only if telemetry shows users running them in fixed pairs.
- **Story-file deprecation grace period** (one-shot warning if existing project has `stories/` folder). Not worth the code; CHANGELOG migration note is sufficient.

---

## Parked

Considered and explicitly decided against. Recorded here to prevent re-debate.

### P.1 Mechanical subagent turn/token budget enforcement
- **What it would do**: let the harness specify `max_turns` or `max_tokens` per subagent dispatch.
- **Why parked**: Claude Code does not expose these as Agent-tool parameters. No workaround without upstream API changes.
- **Workarounds already shipped**: v2.1.5 Planner feature-size gate (prevent oversized dispatches) + pre-TDD scaffold checkpoints (recover from hard-stops gracefully).
- **Context**: discussed 2026-04-23 during BELCORT ACCOUNTING debrief.

### P.2 Adopting fork-subagent at plugin level today
- **What it would do**: opt the harness into Claude Code's fork-subagent cost optimization (auto-trigger or `context: fork` activation).
- **Why parked**: **structurally incompatible** (Phase 0 research finding, 2026-04-24). Per Anthropic's official Claude Code docs, `context: fork` is a **skill-only** frontmatter field — it does not appear in the agent frontmatter schema (which exposes `model`, `effort`, `permissionMode`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `isolation`). Auto-trigger requires omitting `subagent_type`, which contradicts our plugin-declared subagent architecture. `CLAUDE_CODE_FORK_SUBAGENT=1` env var enables fork globally but does not override the skill-scoped activation semantics. No documented fallback exists for parallel plugin-declared subagent dispatches.
- **Revisit only if**: (a) Anthropic extends fork semantics to plugin-declared subagents via the Agent tool, OR (b) we adopt a skill-wrapper pattern (a skill with `context: fork` + `agent: harness:evaluator` that dispatches the agent through the skill-fork path — speculative, needs empirical validation).
- **Context**: discussed 2026-04-24 via claude-code-guide agent research. Phase 0 research gate executed 2026-04-24 during v3 planning; adoption aborted on definitive docs finding. See CHANGELOG v2.1.9 follow-up conversation for the reasoning trace.

---

## Adding to this roadmap

- **New watch-list item**: add to "v3 Watch List" with all 4 fields. Skip "When to revisit" and the entry rots — future-you won't remember why you wrote it.
- **Promoting to "In Progress"**: when a condition fires, move the entry, add PR/branch link.
- **Shipping**: move from In Progress to "Shipped" with version + date + one-liner. Detail goes in CHANGELOG.md.
- **Explicitly rejecting**: move to "Parked" with reason. Don't silently delete — the record prevents re-debate.
