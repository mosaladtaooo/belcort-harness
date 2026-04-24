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

## In Progress

_(Nothing active — v2-beta is in live-stress-test observation before merge to main.)_

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
