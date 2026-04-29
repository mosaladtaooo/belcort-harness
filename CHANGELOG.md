# Changelog

All notable changes to BELCORT Harness are documented here. Versions follow [Semantic Versioning](https://semver.org/).

The canonical source for the *why* behind each release is [docs/feature-contracts/](docs/feature-contracts/), one file per release. This file is the user-facing summary.

---

## v2.3.0 — 2026-04-29 — Agent-prompt deduplication + bash de-prescription

Continues the v2.0/v2.2 minimalist refactor logic, applied to three accreted patterns surfaced on a follow-up audit of `agents/generator.md` and `agents/evaluator.md`. Single-PR atomic merge. ~50-55 LoC net reduction. No user-facing command surface change. No contract format change. All v2.2 invariants preserved.

### Removed

- **`## ANTI-PATTERNS` section in `plugins/harness/agents/generator.md`** (was lines 498-505). Every bullet (Test-after / Mega-commits / Stubbing / Guessing APIs / Skipping self-eval) was already a row in the `RED FLAGS` table at lines 144-167. Single-source-of-truth restoration.
- **Agent-level `READ THIS CAREFULLY` leniency-bias warning in `plugins/harness/agents/evaluator.md`** (was lines 54-55). The same warning at line 261 (EVALUATE-mode-specific) is preserved. Reason: REVIEW-PROPOSAL has a different failure mode (rubber-stamping, addressed at line 151), REVALIDATE is binary (covered at line 246), only EVALUATE involves numeric leniency.

### Changed

- **`## REWARD-HACKING — FORBIDDEN` section in `plugins/harness/agents/generator.md` compressed** from 18 lines to ~6 lines. The 4 of 5 NEVER rules already appear in the RED FLAGS table; cross-reference replaces verbatim restatement. The 5th rule (modify test+code in same commit) and the corrective procedure are preserved.
- **Step 1 Setup, Step 3 Code Quality Review, Step 4 Test Suite Analysis in `plugins/harness/agents/evaluator.md` converted from literal bash to natural-language intent**. Step 4.5 reward-hacking scan (six archaeological greps A-F) preserved literal — those regex patterns ARE the spec, not boilerplate. This aligns evaluator.md with the planner.md philosophy already at line 76 ("You do NOT have Bash. Planning is a read-and-write activity") — the framework already trusted the model in one agent; v2.3 brings the others into alignment.

### Migration

None required. All changes are agent-prompt content. No manifest format change, no contract format change, no command surface change. Existing v2.2 features, sprints, and feature folders work unchanged.

### Spec

- Design: `docs/superpowers/specs/2026-04-29-belcort-v2.3-agent-prompt-deduplication-design.md`
- ADR: `docs/feature-contracts/v2.3-agent-prompt-deduplication.md`

---

## v2.2.0 — 2026-04-28 — Stale-assumption pruning + operational hardening

Continues the v2.0 minimalist refactor logic, applied to four post-v2.0 stale-assumption targets plus two operational hardening items. Single-PR atomic merge. ~300 LoC net reduction. No user-facing command surface change beyond removing one redundant front door.

### Removed

- **Per-FR story files** (`features/NNN/stories/FR-NNN.md`) — the BMAD-V6 scoping assumption that drove inclusion in v2.0 has staled on Opus 4.7[1m]. The full contract is ~8k tokens out of 1M; per-cycle scoping is trivial without a separate file. The "drift = build fails" hash-check was Planner-asserted and Evaluator-unimplemented (v2.x inconsistency). Generator BUILD now reads the per-FR section of `contract.md` directly via grep on FR-IDs. Existing projects with `stories/` folders: ignored from v2.2 forward; safe to delete manually.
- **`/harness:negotiate` standalone command** — 17 commands → 16. Procedure (Generator NEGOTIATE → Evaluator REVIEW-PROPOSAL → Generator FINALIZE-CONTRACT, ≤3 rounds) is canonical in `commands/sprint.md` § 2c; recovery from `negotiating` phase uses `/harness:resume`; restart uses `/harness:rewind negotiating`. Standalone command was almost never user-invoked.
- **Planner mode duplication** — 6 modes → 3. CLARIFY-APPLY + AMEND + EDIT + CONSTITUTION-AMEND collapsed into one unified `MODE: EDIT` that reads a marker from the dispatch prompt (`AMENDMENT REQUEST` / `EDIT REQUEST` / `CLARIFY ANSWERS` / `CONSTITUTION AMENDMENT`). Mode-specific constraints (which files may be patched, scope expectations, etc.) now live in each command file's dispatch prompt — single source of truth per constraint. Net Planner LoC: -400. User-facing commands `/harness:amend`, `/harness:edit`, `/harness:clarify`, `/harness:constitution-amend` unchanged.

### Added

- **1M-context confirmation banner** in `doctor.sh` (advisory; mechanical detection deferred until Claude Code exposes `--model` to plugin scripts).
- **1M-context confirmation prompt** in `commands/sprint.md` § 0b (blocking) and `commands/quick.md` § 0a (non-blocking one-liner).
- **`### Recommended launch` section** in README.md Quick Start, promoting `claude --model claude-opus-4-7[1m]` from buried-in-Status to top-level. Also new troubleshooting entry "Generator BUILD truncated / no implementation-report.md produced" pointing to the same fix.
- **`## State at pause` section** in `pause-questions.md` template — Generator authors a state snapshot (current FR, last completed FR, last commit SHA, working tree status, timestamp, reason category) at pause time. Snapshot is authoritative for the re-dispatched Generator's resume orientation, beating `manifest.yaml` if they disagree (manifest can move via interleaving commands).

### Changed

- **Planner feature-size sanity check** (planner.md § Feature-size sanity check) is reworded to be advisory-only with an explicit operational dependency note: trust-the-model stance assumes 1M-context launch.
- `commands/sprint.md` § 3a pause re-dispatch now passes the State-at-pause snapshot through to the resumed Generator under a `--- PAUSE STATE SNAPSHOT (authoritative — prefer over manifest if they disagree) ---` marker.
- `agents/generator.md` Phase 1 rule 3 prefers the snapshot over manifest for resume orientation.

### Migration

- **Existing projects with `.harness/features/NNN/stories/` folders**: harmless. Generator and Evaluator no longer read them. Safe to delete the folder; no migration script is provided. The hash-check that would have failed on drift was never enforced in code, so no spurious failures will occur from leaving them in place.
- **Muscle-memory `/harness:negotiate` users**: the command now returns "command not found". Use `/harness:resume` (when in `negotiating` phase) or `/harness:rewind negotiating` (to restart from finalized contract).

### Spec & ADR

- Design spec: `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md`
- Implementation plan: `docs/superpowers/plans/2026-04-28-belcort-audit-and-refine.md`
- ADR pending: append to `progress/decisions.md` after merge documenting the v2.0-spec contradiction (story files removed; v2.0 preserved them) and the trust-the-model stance.

## [2.1.9] — 2026-04-24

### Feature — Secrets-handling contract (two-file convention) + Evaluator setup gate
Generator was hitting AgentLint's `no-env-commit` + `no-secrets` hooks (both `severity: error`, unsuppressible per AgentLint's safety-invariant contract) when trying to write `.env.local`. Bash heredoc fallback also failed — AgentLint intercepts at PreToolUse regardless of how the write is framed. Correct behavior on the hook side; the gap was in Generator's prose contract, which didn't specify the two-file handoff convention.

Surfaced during live stress-test on BELCORT ACCOUNTING.

Fixes:
- **`agents/generator.md`** Phase 2 gains a "Secrets and environment files (v2.1.9+)" section above the numbered TDD rules. Explicit: Generator writes `.env.example` with obvious placeholders (`REPLACE_ME`, `<your-value>`); user writes `.env.local`. Forbids writing `pause-questions.md` for secret values (secrets must not enter conversation history).
- **`templates/features/implementation-report.md.txt`** gains a `## Setup required (before Evaluator can run)` section. Generator populates with required files, env vars (with sources), other user steps, and the final `bash .harness/init.sh` command. If no setup needed, Generator writes "None — init.sh handles everything."
- **`commands/sprint.md` Step 4 adds a "4a. Setup-required gate"** before Evaluator dispatch. Orchestrator reads the implementation-report's Setup section, checks required-file existence, and pauses for user completion if incomplete. Prevents false-FAIL Evaluator runs against apps that can't start because of missing env.

### Why this fits Anthropic's GAN-isolation philosophy
Secrets belong to the user's domain, not the agent's. The two-file convention makes the ownership boundary explicit: `.env.example` (agent-authored placeholder) lives in the agent's domain; `.env.local` (user-authored actual values) lives in the user's. The setup gate enforces the handoff: agent finishes building, user completes setup, evaluator tests the combined result. No role bleeds into another.

### Release-cadence note
v2.1.5 (feature sizing), v2.1.8 (worktree cwd), v2.1.9 (secrets handling) all followed the same pattern: real bug found via stress-test → fix is an explicit rule in Generator's prose contract → shipped as patch. The mechanism is sound; the rough edges live in the contract, and they surface quickly under real use — which is what v2-beta stress-testing is designed to produce.

## [2.1.8] — 2026-04-24

### Fix — Two-`.harness/` folder cognitive-confusion hazard (docs + prompt discipline)
During a sprint's build phase, `.harness/` appears in two places due to git-worktree mechanics: the **live** copy at project root and a **frozen snapshot** at `.worktrees/current/.harness/` (checked out as a side-effect of `git worktree add`). The root copy is authoritative; the worktree copy goes stale immediately. A subagent or `/harness:resume` invocation that reads from the worktree copy would see stale manifest phase, stale contract, stale scores — and the risk is structural (nothing mechanically prevents the wrong read).

Surfaced during live stress-test on BELCORT ACCOUNTING — retrospective phase wrote correctly to root, but the two visible `.harness/` folders raised the question of whether dispatch could pick the wrong one.

Fixes shipped:
- **SKILL.md § File Ownership Contract** gains a new sub-section "Working directory and `.harness/` location — root is authoritative" with an explicit table distinguishing live vs stale + a cwd rule for subagents + a specific note for `/harness:resume`.
- **sprint.md Step 3 (BUILD dispatch)** adds a note after `git worktree add` explaining the stale snapshot, and prepends a "Working directory contract (v2.1.8)" paragraph to the Generator's dispatch prompt so the Generator has the rule in its fresh context.
- **sprint.md Step 4 (EVALUATE dispatch)** prepends the same cwd contract paragraph to the Evaluator prompt, explicitly listing every `.harness/...` file the Evaluator reads and clarifying that source-code-launching Bash (`cd .worktrees/current`) is fine for starting the app but must not be a base for subsequent `.harness/` Read/Write.
- **resume.md** adds a lead-in directive: invoke from project root, not from `.worktrees/current/`. Reading the stale manifest would misidentify the pipeline state.

### Honest note on the mechanical fix that got deferred
I originally proposed a mechanical Option A for v2.1.8: add `.harness/` to the build-branch's `.gitignore` to prevent the stale copy from appearing in the worktree. During implementation I discovered this approach doesn't work cleanly — `.gitignore` only affects untracked files; `.harness/` is already tracked on every branch. Untracking (`git rm -r --cached`) on the build branch would cause squash-merge to delete `.harness/` from main. The correct mechanical approach is `git sparse-checkout` at worktree creation, which adds Windows-compatibility fragility disproportionate to the confusion risk.

Sparse-checkout-based mechanical prevention is now recorded on the v3 Watch List (ROADMAP.md item 6). Shipping the prose + prompt-discipline fix alone follows Anthropic's "simplicity first" — it addresses the cognitive confusion without introducing cross-OS git complexity.

## [2.1.7] — 2026-04-24

### Feature — Explicit frontmatter tuning for maximum context + turns
Adds four frontmatter fields to all three harness agents (`planner.md`, `generator.md`, `evaluator.md`):

- **`model: inherit`** — subagents use whatever model the parent session runs. For maximum context, start Claude Code with `claude --model claude-opus-4-7[1m]` and every subagent inherits the 1M context window. Without this runtime pairing, inherit picks the default 200K Opus variant — still fine, but 5x less than the 1M variant.
- **`effort: max`** — deepest reasoning on extended-thinking models. Anthropic's frontmatter reference notes max was introduced on Opus 4.6; behavior on Opus 4.7 is reasonable-but-unverified. If subagent dispatches start erroring after this release, `effort: max` is the first candidate to roll back.
- **`permissionMode: default`** — subagents follow parent session's approval regime; parent's `bypassPermissions` overrides.
- **`maxTurns: 2000`** — 7-10x headroom over the BELCORT ACCOUNTING stress-test hard-stop (69 tool uses). Generous but bounded; if Claude Code clamps to a lower internal ceiling it does so silently.

Fields we explicitly chose NOT to set (rationale documented):
- `tools` / `disallowedTools` — inheriting parent's full toolset continues the v2.1.1+ decision. Claude Code rewrites MCP namespaces at install time; allowlists prefix-break.
- `skills` — runtime invocation of `superpowers:test-driven-development` keeps the TDD contract honest (a runtime delegation, not a baked-in assumption). Pre-loading would add ~300 lines of context per dispatch for marginal savings.
- `memory` — our state lives in `.harness/*.md`. A second persistence channel would drift from the file-based source of truth (violates "file-based communication" principle).
- `isolation` — default fresh-subagent dispatch already provides the GAN separation we require. Explicit `isolation: true` may suppress parent-visible output the orchestrator uses for routing.

### Docs — Parent session model is load-bearing
- README Status section documents the Opus 4.7[1m] parent-session pairing. Without it, `model: inherit` + `effort: max` still work but deliver a smaller context window than the frontmatter implies.

## [2.1.6] — 2026-04-23

### Fix — AgentLint project config was silently ignored since v2.1.3
- Replaced `.agentlint.toml` with `agentlint.yml` at repo root. AgentLint reads YAML (`agentlint.yml`), not TOML (`.agentlint.toml`) — the v2.1.3-introduced `.agentlint.toml` with `[[suppress]]` blocks was never loaded. Confirmed by `agentlint doctor`: "Config file: agentlint.yml not found" and `get_config` returning `rules: {}` (empty, no project-level overrides).
- The new `agentlint.yml` sets `max-file-size: { limit: 1500 }` — global limit increase since the rule supports only a single `limit` option, no per-path suppression (verified by reading `site-packages/agentlint/packs/universal/max_file_size.py:28`). 1500 lines accommodates the largest harness file (`planner.md` at ~1120 lines) with ~33% headroom for growth.
- Root cause for why the broken config wasn't caught earlier: AgentLint silently treats a missing `agentlint.yml` as "use defaults" without warning about unrelated filenames present in the repo. The v2.1.3 commit that added `.agentlint.toml` appeared to work (it committed cleanly, no hook errors) but had zero effect on AgentLint's actual behavior. Surfaced during v2.1.5 development when the `max-file-size` hook blocked an Edit to `planner.md` despite the nominal suppression.
- Rationale for all original suppressions (harness-engineering research cites, single-file plugin.json constraint, doctor.sh structural cohesion) preserved as inline comments in the new `agentlint.yml`.

## [2.1.5] — 2026-04-23

### Feature — Planner feature-size gate (prevent oversized dispatches)
- `agents/planner.md` Pass 2 adds a "Feature-size sanity check" gate before finalizing contract.md output. If a single feature folder matches any of four oversized-feature signals (>10 FRs, mixes Phase-0 bootstrap + Phase-1 data layer + Phase-2+ behavior, >30 expected files, touches >2 architectural strata), Planner MUST propose a split via a `## Split recommended` section and surface it at the `/harness:analyze` gate for human approval. Silent splitting is forbidden — a split affects ROADMAP.md and build-branch structure, so the human must see it.
- Why: Generator subagents have finite Claude Code budgets (token + tool-turn caps per dispatch). A 20-FR foundation feature or mixed bootstrap+schema+behavior blob exhausts that budget mid-build and hard-stops with an uncommitted worktree. Catching oversize at the Planner stage is cheaper than recovering from a truncated build — spec correctness once vs paying repeatedly in failed dispatches. Surfaced by live stress-test on BELCORT ACCOUNTING's `001-document-pipeline-foundation` feature (13 schema files + RLS + audit grants in one dispatch; Generator hard-stopped mid-work).

### Feature — Pre-TDD scaffolding commit rule (clean mid-scaffolding recovery)
- `agents/generator.md` Phase 2 adds a "Pre-TDD scaffolding commit rule" above the existing numbered TDD rules. Scaffolding work (deps, config, schema, RLS, migrations, type-only modules) is non-behavioral — there's no RED test to write first — but it still needs per-checkpoint commits. Rule: commit at logical group boundaries, never accumulate >10 files without a commit. Message format: `[harness:scaffold] <group> (checkpoint)`. Companion `scaffold-checkpoint` changelog entry mirrors the per-FR log schema (commit hash, files, next group).
- Why: before this rule, Generator had ONE commit trigger (after RED→GREEN→REFACTOR complete per FR). Scaffolding work NEVER crosses that trigger, so a 15-file scaffolding burst sat uncommitted until the first behavioral FR finished. Hard-stop before reaching behavioral FRs = 15+ uncommitted files with no audit trail, recovery meant manual `git add -A` and lossy intent-guessing. With this rule, `git log` + the scaffold-checkpoint changelog entries make recovery mechanical instead of judgment-heavy.

### Docs — SKILL.md Recovery section expanded for hard-stop scenarios
- `skills/harness/SKILL.md § Recovery` step 4 `building` bullet now distinguishes graceful pause (`pause-questions.md` exists) from hard-stop (subagent returned truncated, no pause file). Hard-stop branch further splits into mid-TDD (per-FR commits available → resume by FR) vs mid-scaffolding (scaffold-checkpoint commits available → resume by checkpoint group; if none exist from a legacy Generator, manual checkpoint first).
- Why: v2.1.4 Recovery docs only covered "read state.current_task, resume from last FR" — which assumes the Generator reached behavioral work. The real live-testing failure mode is hard-stop during Phase-0/Phase-1 scaffolding BEFORE any FR work begins. This entry makes recovery mechanical for that case.

## [2.1.4] — 2026-04-23

### Fix — Evaluator tuning category vocabulary mismatch
- `templates/evaluator/tuning-log.md.txt` schema listed `Leniency | Overclaim | Missed issue | Wrong severity | Out of scope | Other`. `commands/tune-evaluator.md` grouped by `Leniency | Strictness | Missed issue | Overclaim | Scope confusion | Other`. **Strictness** (false FAIL) and **Scope confusion** existed in the tuner but not in the log schema; **Wrong severity** and **Out of scope** existed in the log but not in the tuner's grouping vocabulary. The tuner greps for these exact strings, so mismatched entries were silently dropped from pattern analysis.
- Both files now use the canonical 7-category vocabulary: `Leniency | Strictness | Missed issue | Overclaim | Wrong severity | Scope confusion | Other`. Each category definition is now identical across the log schema and the tuner grouping step.
- tune-evaluator.md explicitly documents the vocabulary-must-match-exactly contract at Step 2 so future edits don't re-diverge.

### Feature — Tuning-review watch-list for insufficient-signal categories
- `/harness:tune-evaluator` Step 4 output now shows a "Watch-list" section below the detected patterns: categories with 1-2 entries (below the ≥3 pattern-threshold) are surfaced for visibility without triggering action proposals. Rationale: a third entry on the next run promotes it into a pattern, so seeing accumulating signal early avoids surprise.

### Refactor — Promote 3-round negotiation rationale into Procedure
- `commands/negotiate.md` Step 3 previously read "Max 3 rounds" with no inline rationale; the why-it's-3 reasoning lived in the Anti-patterns section at the bottom of the file. Readers making the escalation decision saw the limit but not the principle behind it.
- Step 3 now inlines: "by round 3, continued disagreement signals an unclear upstream contract (the Planner's what/why is ambiguous), not a negotiation problem. More agent rounds won't resolve a values or clarity gap; human judgment will."
- Step 4 (escalation) expanded with sharper human-decision UX: the blocker, why it's stuck, and the specific decision being asked (a/b/c/d).
- Anti-patterns section now cross-references Step 4 instead of restating the rationale.

### Docs — Sharpen retrospective vs tuning distinction
- `SKILL.md § Pipeline Timing` expanded with a new sub-section "Retrospective vs tuning — two different loops" and a side-by-side table. Retrospective audits the work product (did we build the right thing?). Tuning audits the judge (is the grader grading correctly?). They run back-to-back after every sprint and were easy to confuse; the table makes the distinct axes and distinct artifacts explicit.

## [2.1.3] — 2026-04-23

### Refactor
- Removed 5 inline templates across `agents/evaluator.md` + `agents/generator.md` that duplicated canonical `.txt` files under `templates/features/`. Replaced each with an `@templates/features/<name>.md.txt` reference + a tight list of pipeline invariants (VERDICT line, `**Negotiated**:` marker, Part-A-before-B, C1/M1/m1 finding IDs, etc.) — the invariants are what downstream consumers actually depend on; the structural template lives in one place. Net: ~−413 lines of inline duplication, consistent with Task-19/Task-20 pattern from the original v2 refactor. (Miss from Phase 1-2.)
- File sizes after dedup: `evaluator.md` 784 → 657 lines, `generator.md` 638 → 487 lines.

### Feature — REVIEW-PROPOSAL context expansion
- Evaluator REVIEW-PROPOSAL mode now reads `spec/constitution.md` + `spec/architecture.md` in addition to criteria + contract + proposal. The proposal introduces new HOW-level content (component breakdown, file structure, test strategy) that the contract never specified; those HOW decisions can violate constitution or architecture independently of contract-level consistency.
- Workflow Step 3 (test-strategy adequacy) now references constitution for project-specific test-layer requirements.
- Workflow Step 5 (missing ACs) expanded with explicit architecture-consistency + constitution-compliance checks — red flags become `R-NN` items in the review.
- `sprint.md` REVIEW-PROPOSAL dispatch prompt updated to enumerate the expanded Input file set.
- PRD intentionally excluded — contract already contains the NFR targets from Planner Pass 2; reading PRD again is redundant for this review.

### Chore
- Added `.agentlint.toml` at repo root with scoped `max-file-size` suppressions for `agents/*.md`, `skills/harness/SKILL.md`, `scripts/doctor.sh`. Each suppression documents the rationale (comprehensive by design per Anthropic harness-engineering; plugin system doesn't support splitting agent prompts; single-pass output formats users rely on).

## [2.1.2] — 2026-04-22

### Fix — surfaced during v2-beta live stress test
- Documented AgentLint Windows-path hook noise in README troubleshooting (MSYS bash eats `\U`, `\A`, `\L` escape sequences in the invoked path — not a harness bug).
- Added README guidance for the npm/npx/pnpm permission-block scenario: the Generator pauses gracefully via the pause protocol (working as designed); user pre-allows via `/allow Bash(npm *)` or `.claude/settings.json`.
- `scripts/doctor.sh` now detects when `.claude/settings.json` hasn't pre-allowed npm-family commands and warns with the exact fix command — saves users from mid-build surprises.
- `scripts/doctor.sh` added `superpowers` to the RECOMMEND plugin list (Generator BUILD delegates TDD to `superpowers:test-driven-development`).

### Refactor — known-issues.md ownership documentation
- `SKILL.md § File Ownership Contract` updated: `progress/known-issues.md` has **three** writers, not just retrospective. Primary: `/harness:retrospective` post-merge drift capture. Also: `/harness:edit` Step 6 V-gate defer ("defer-to-sprint"), and `/harness:audit` when the user chooses "record as debt". Append-only; entries persist across sprints. Readers: retrospective (dedup), audit (verification-debt scan), Planner CLARIFY-QUESTIONS (skip ambiguities already recorded), human.

### Feature — /quick spec-drift check
- `/harness:quick` Step 4.5 added on the PASS path: one question to the user — *"Did this fix change any behavior in prd.md / architecture.md / constitution?"* Yes routes through `/harness:amend "<summary>"` before merge. Simplest Anthropic-aligned gap closure (no new file, no new flag, no new machinery) for the "quick fix that happens to touch spec" scenario.

### Fix — /clarify ADR gap
- `SKILL.md § State Persistence` documented `/clarify` as an ADR writer but `clarify.md` Step 8 never actually appended one — doc-vs-code inconsistency. Fixed: Step 8 now writes an ADR to `progress/decisions.md` recording the Q→answer pairs as design decisions. Future clarify rounds + retrospective can now trace feature behavior back to the specific ambiguity that shaped it.
- Pipeline gap scan now shows all 7 spec-mutating commands (clarify, amend, edit, constitution-amend, retrospective, tune-evaluator, rewind) symmetric: each writes changelog + ADR.

## [2.1.1] — 2026-04-22

### Refactor — drop `tools:` frontmatter allowlist
- Removed the `tools:` field from `agents/{planner,generator,evaluator}.md` frontmatter. Subagents now inherit the parent Claude Code session's full tool set. Matches the industry-standard plugin format (Vercel declares no `tools:` on its 3 agents either).
- Rationale: the `tools:` allowlist encoded the assumption *"subagents might misbehave with unrestricted tool access"* — stale on Opus 4.7 with the `<SUBAGENT-CONTEXT>` prose rule + HANDLING FETCHED CONTENT prompt-injection defense + RED FLAGS tables + hook-enforced reward-hacking guards already in place. Additionally, Claude Code rewrites tool namespaces at install time (`.mcp.json`'s `context7` → runtime `mcp__plugin_harness_context7__*`), which prefix-broke our frontmatter allowlist — subagents were silently denied MCP access they were intended to have.

### Feature — project-tools propagation
- Added `## Project-specific tools / MCPs / skills` section to `templates/CLAUDE.md.project.txt` — the canonical place for users to declare project-level tool usage guidance.
- Added `SKILL.md § Orchestrator Behavior` item 7: before every subagent dispatch, orchestrator scans project CLAUDE.md for project-tool hints and includes them in the Agent-tool `prompt` under a `--- PROJECT TOOLS ---` marker. Inheritance grants access; the hint tells the agent when to reach for it.

### Fix — marketplace.json + plugin.json version strings
- `marketplace.json` metadata/version + plugins[0].version both bumped to match `plugin.json`. Earlier release-automation miss.

## [2.1.0] — 2026-04-21

### Refactor — native Agent-tool subagent dispatch
- Migrated from `claude -p` subprocess dispatch to native Claude Code Agent tool via plugin-declared subagent types.
- `plugin.json` declares `agents: ["./agents/planner.md", "./agents/generator.md", "./agents/evaluator.md"]` (array format — NOT the Cursor-plugin `"./agents/"` string form, which fails Claude Code's validator with `agents: Invalid input`).
- Agent md files gained YAML frontmatter (`name:`, `description:`) registering them as `harness:planner`, `harness:generator`, `harness:evaluator` subagent types.
- Every dispatch across 6 commands rewritten: `CLAUDE_SUBAGENT=1 claude -p ... --append-system-prompt-file ... --allowedTools "..."` → natural-language "dispatch via Agent tool with subagent_type=harness:X, prompt=..." prose. 13 dispatch sites migrated.
- Benefits: no subprocess startup, no env-var isolation tricks, no stdout parsing, parallel-dispatch capability, structured return values.

### Infrastructure
- `SKILL.md § Subagent Isolation Protocol` rewritten for v2.1 mechanism.
- `hooks/session-start.sh` `CLAUDE_SUBAGENT=1` check reclassified as backward-compat shim (no longer primary isolation gate — Agent-tool handles context isolation natively).
- `<SUBAGENT-CONTEXT>` blocks in all 3 agents explicitly forbid nested Agent-tool dispatches while permitting non-harness skill invocation (e.g., Generator BUILD using `superpowers:test-driven-development`).

### Fix — Windows python3 stub detection
- Discovered during v2.1.0 canary: on Windows, `python3.exe` is commonly a Microsoft Store PATH stub that resolves via `command -v python3` but doesn't execute, causing `pre-tool-use.sh` to silently fail-open on all safety rails (force-push / sudo / .harness-deletion / test-file-deletion blocks returned exit 0).
- Fixed: hook + doctor now probe actual execution (`python3 -c 'print(1)'`) and fall back to `python` (Windows naming) with 3.x version check. Detection message explicitly calls out the MS-Store-stub gotcha.

## [2.0.0] — 2026-04-21

### Removed
- `/harness:steer` command + `features/NNN/steering.md`. Mid-build steering collapses into `/harness:amend` (spec change) or the evaluator retry loop (quality).
- `/harness:assumption-test` + `scripts/assumption-test.sh` (287 lines). Never run in practice; manual A/B is a 5-minute task when needed.
- `scripts/progress-poller.sh` + `agents/_progress-protocol.md` + heartbeat sections in all three agents. `claude -p` streams stdout natively; the poller solved a non-problem on Opus 4.7.
- `scripts/phase-guard.sh` + FR-2 spec-file-edit enforcement in `hooks/pre-tool-use.sh`. Prose rule in SKILL.md suffices on Opus 4.7.
- Per-agent model pinning (`config.models.{planner,generator,evaluator}`). Unused, undocumented.
- Global CLAUDE.md installation. Rules now install project-local via `/harness:setup`.

### Changed
- `skills/harness/SKILL.md` promoted to auto-invoked skill (trigger-phrase matching). `/harness:*` slash commands remain as explicit entry points.
- `SessionStart` hook reduced from ~50 lines of state injection to ~15 lines — one-line "harness detected, invoke skill" nudge. State reading moves into the skill.
- Generator BUILD mode references `superpowers:test-driven-development` for RED/GREEN/REFACTOR; BELCORT-specific rules (atomic per-FR commits, reward-hacking prohibition) retained inline.
- `/harness:rewind` simplified from 267 to ~80 lines.
- All template content consolidated to `plugins/harness/templates/`. Root `templates/` deleted.
- Command files rewritten as natural-language procedures. Bash retained only for `claude -p` dispatch, `git worktree`, and hook contents.

### Migration
- Users who installed v1.x rules globally: run `scripts/uninstall-rules.sh` once to remove the legacy `~/.claude/CLAUDE.md` block, then `/harness:setup` in each project to install the new project-local rules.

### Architecture
- ~45% LoC reduction. Pipeline and Anthropic-aligned core unchanged.
- Full rationale: `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md`.

## [1.5.2] — 2026-04-20

**Theme:** Documentation-only release. The pipeline implementation is **unchanged** from v1.5.1 — same agents, same commands, same hooks, same manifest schema, same dispatch pattern. No code behavior changes.

The README was rewritten end-to-end using the v1.5.1 subagent-dispatch pattern (real Generator subagent + independent Evaluator review). The rewrite addresses gaps found in the v1.5.1 README: comprehensive newcomer on-ramp, every non-trivial claim sourced inline, a 19-row command reference grouped by category, explicit file-layout diagram, and a candid limitations section. The Evaluator caught four factual issues during review — all fixed before release:

- **Broken internal link** to `plugins/harness/evaluator/criteria.md` (that path doesn't exist; criteria.md is runtime-generated inside each project). Fixed to point at the template at `plugins/harness/templates/evaluator/criteria.md.txt`.
- **Sprint flow step order** was inverted — README showed `human gate → analyze`, but the canonical [sprint.md](plugins/harness/commands/sprint.md) order (confirmed in [SKILL.md](plugins/harness/skills/harness/SKILL.md) command table) is `analyze → human gate`. Swapped, because analyze-first is the point — the human reviews the consistency report before approving.
- **Fabricated "opacity-at-scale" label** attributed to Trustworthy Agents. The underlying quote ("no longer neatly visible as a single thread of actions") is verbatim from the article, but the compound label was editorial. Reframed: the quote is still there, the invented label is not.
- **Unverified cost figures** ("$9 solo vs $200 harness") previously attributed to Rajasekaran 2026. Replaced with a "read the essay for authoritative numbers" pointer plus our own measured figure from the v1.5.1 real-use test (~$8–10 for a 3-FR CLI, verified).

### Methodology (so this is reproducible)

1. Dispatched Generator subagent with the current README + all internal doc paths + canonical source URLs + an explicit brief listing 17 required sections and 7 quality bars. Output: 508 lines.
2. Dispatched Evaluator subagent with instructions to verify every quote (WebFetch where uncertain), spot-check internal links against real files, and count FR claims against the actual commands directory.
3. Evaluator verdict: `needs-revision` with 2 CRITICAL + 4 MAJOR + 3 minor findings and 7 explicit strengths-to-preserve.
4. Applied surgical fixes to CRITICAL + MAJOR findings directly (faster than dispatching a Generator revision round for small factual fixes).
5. No claims in the README are un-sourceable; every quoted phrase was either taken from the repo's own [docs/anthropic-alignment.md](docs/anthropic-alignment.md) (which maintains its own verification discipline) or WebFetched against the live article URL during the Evaluator's review.

### What changed in this release

- `README.md` — full rewrite, 508 lines, every claim sourced inline
- `plugins/harness/.claude-plugin/plugin.json` — version 1.5.1 → 1.5.2
- `.claude-plugin/marketplace.json` — version 1.5.1 → 1.5.2 (both metadata and plugin entries)
- `CHANGELOG.md` — this entry

### What did NOT change

Everything else. If you are on v1.5.1 and your pipeline is working, upgrading to v1.5.2 is optional — the only reason to upgrade is to pick up the improved README. All `.harness/` manifests, feature contracts, and running pipelines are fully forward-compatible.

---

## [1.5.1] — 2026-04-20

**Theme:** Polish fixes surfaced by a real end-to-end sprint on v1.5.0.

After v1.5.0 shipped, I ran the full pipeline against a real build target (Node.js CLI that SHA-256-hashes a file — 3 FRs, 10 ACs/ECs). The pipeline worked end-to-end (**PASS** verdict from Evaluator, 10/10 tests passing, TDD evidence strong) but surfaced three UX rough edges worth patching before calling v1.5 "done." All three are additive documentation/workflow fixes — no schema changes, no behavioural regressions.

### Fixed

- **FINALIZE-CONTRACT permission-gate regression**: the Generator's FINALIZE-CONTRACT mode in v1.5.0 had a "Step 3: Update manifest" step that tried to edit `manifest.yaml` from inside the subagent. With `--allowedTools "Read,Write"` the subagent lacked the permission claude-code 2.x requires to edit outside the immediate subtree, causing the dispatch to return exit code 2 even though contract.md was written correctly. Fix: removed Step 3 from `agents/generator.md` MODE: FINALIZE-CONTRACT. The orchestrator (sprint.md) now handles the `negotiating → building` phase transition explicitly as an orchestrator-side `sed` after the FINALIZE dispatch returns.

- **Planner chmod paradox**: `agents/planner.md`'s "Also Create:" section instructed the Planner to `chmod +x .harness/init.sh`, but the Planner's allowed-tools intentionally exclude Bash (per Anthropic's trustworthy-agents "tool breadth = attack surface"). The subagent couldn't execute the chmod. Fix: updated planner.md to document that chmod is the orchestrator's responsibility; `sprint.md` now runs `chmod +x .harness/init.sh` automatically after the Planner dispatch returns.

- **Per-FR atomic commits not enforced strongly enough**: the v1.5.0 real-use test produced a Generator that wrote all 3 FRs' implementation in a single commit (`[harness:build] FR-001/002/003: ...`). The constitution mandates atomic per-FR commits; the Evaluator still passed the sprint but flagged the bundled commit as a minor. The anti-pattern was only in §RED FLAGS, not in the main BUILD procedure. Fix: added an **ATOMIC COMMIT RULE** callout at the top of Phase 2 (TDD) in `agents/generator.md` — "commit per FR, never bundle; if you catch yourself writing `FR-001/002/003` in a single commit message, STOP and `git reset` retroactively."

### Meta note on real-use validation

v1.5.0 was the first version where the subagent dispatch pattern actually worked on Claude Code 2.1+. v1.5.1 is the first version where the pipeline also runs *cleanly* (no spurious exit-2 on FINALIZE, no "the Planner can't execute its own instructions" paradox, no bundled-commit TDD evidence gap). The real-use test that surfaced these is documented in the conversation log of the release; a follow-up should be to encode this flow as a self-test canary (F13 from the v1.5 contract — still deferred).

---

## [1.5.0] — 2026-04-20

**Theme:** Trustworthy-Agents deep alignment + Claude Code 2.x compatibility.

Closes six gaps the v1.4 alignment pass did not address — each grounded in a documented Anthropic anti-pattern or a 2026 evolution of BMAD / SpecKit / Superpowers. Also fixes a critical subagent-dispatch bug that made v1.4 and earlier silently non-functional on Claude Code 2.1+.

### Critical compatibility fix (required for Claude Code 2.1+)

- **Subagent dispatch pattern rewritten.** v1.4 and earlier inlined the full ~55KB agent role prompt as the USER message of `claude -p` (`claude -p "$(cat agents/planner.md) ... $ARGUMENTS"`). On Claude Code 2.1+ this produced empty output — the dispatched subagent wrote no files. v1.5 moves the agent role to `--append-system-prompt-file` and frames the user message as an explicit mode prompt with the user request. 14 dispatch sites across 5 command files updated.
- **User messages must not start with `---`.** Claude CLI parses leading `-` as an option. The historical dispatch happened to work because the agent file content came first (starting with `#`). v1.5 user messages begin with prose and only use `---` markers mid-string.

### New features

- **FR-1 — Subagent observability streaming** (Trustworthy Agents §opacity-at-scale). Each subagent emits JSONL milestones to `.harness/features/${FEATURE}/_progress.jsonl`; orchestrator polls every 10s and surfaces `[HH:MM AGENT] phase: msg` lines while the dispatch runs. Configurable via `config.observability` in `manifest.yaml`.
- **FR-2 — Hook-enforced spec-file ownership** (BELCORT defensive depth). The File Ownership Contract is now mechanical: `pre-tool-use.sh` inspects every `Edit` / `Write` tool call and blocks unauthorized orchestrator writes to `.harness/spec/*`, `features/*/contract.md`, and `evaluator/criteria.md`. Authorization is gated by the `state.phase` set by spec-edit commands (`amend`, `clarify`, `edit`, `tune-evaluator`, `retrospective`, `constitution-amend`).
- **FR-3 — Mid-build pause-and-ask** (Trustworthy Agents §calibrated uncertainty). Generator can write `pause-questions.md` when it hits genuine mid-build ambiguity. Mandatory "default if unanswered" per question prevents pause-as-procrastination. Orchestrator detects, surfaces to user, accepts answers, re-dispatches. Max 3 pauses per sprint before escalation to `/harness:rewind negotiating`.
- **FR-4 — Per-FR story files** (BMAD V6 Scrum Master pattern). Planner Pass 2 emits `features/NNN/stories/FR-NNN.md` per FR with persona + ACs + architectural slice + constitution subset + TDD anchor. Generator BUILD reads the current story per cycle. Strict no-paraphrase invariant against the aggregate contract.
- **FR-5 — Component-as-assumption stress test** (Rajasekaran 2026 direct prescription). New `/harness:assumption-test "<component>"` runs a calibrated A/B with and without a named component on a user-supplied canary spec. Verdict: `LOAD-BEARING` / `MARGINAL` / `OBSOLETE`. Mandatory ADR on every run. Quarterly cadence recommended.
- **FR-6 — Constitution amendment governance** (SpecKit explicit pattern). New `/harness:constitution-amend "<reason>"` with five ceremony stages: typed confirmation (`I-AM-AMENDING-THE-CONSTITUTION`), ≥50-char reason, in-progress feature handling, mandatory ADR, and revalidation against every completed feature via Evaluator REVALIDATE mode.

### Bug fixes (caught in audit + sandbox + real-use passes)

- **B1 (template paths)**: `story.md.txt` and `pause-questions.md.txt` moved from top-level `templates/features/` to `plugins/harness/templates/features/` so runtime reads via `${CLAUDE_PLUGIN_ROOT}/templates/...` actually resolve. v1.4 convention implicitly required this for all agent-readable templates.
- **B2 (score extraction)**: `assumption-test.sh extract_score()` now uses `grep -oE '[0-9]+/[0-9]+' | awk -F/` instead of `gsub(/[ \/]/,"")`. The old pattern collapsed `8/10` into `810`, silently corrupting verdicts on marginal-boundary cases (delta=1 misclassified as LOAD-BEARING).
- **B3 (agent_checkins increment)**: `sprint.md` step 3a awk replaced. The old pattern's "exit block" condition fired on `user_interrupts:` (inside the block but matched the regex), so the increment never reached `agent_checkins:`. Calibration-metrics tracking from FR-3 pauses was broken.
- **B4 (hook matcher)**: `hooks.json` PreToolUse matcher was `"Bash"` only, so Claude Code never invoked the hook for `Edit` / `Write` tool calls — FR-2 spec-file enforcement was silently inactive at the hook-config level. Added separate matcher entries for `Edit` and `Write`.
- **B5 (phase guard orphan recovery)**: `phase_set` now defensively runs `phase_restore` if `.phase-prior` exists, preventing spec-edit phase from leaking across crashed commands.
- **B6 (poller stop noise)**: `disown` added after backgrounding the poller so `kill` doesn't trigger the parent shell's "Terminated: 15 ( ... function body ... )" job-control noise.
- **B7 (poller parent-dir)**: `start_progress_poller` now runs `mkdir -p "$(dirname "$progress_file")"` before the truncate. On a fresh project's first sprint, `.harness/` doesn't exist yet (the Planner creates it); without the mkdir the poller silently failed to start.
- **B8 (script perms)**: `chmod +x` on `pre-tool-use.sh`, `session-start.sh`, `install-rules.sh`, `uninstall-rules.sh`. Some were `100644`; hook invocation needs the executable bit.

### Documentation

- **`docs/anthropic-alignment.md`**: new "v1.5 additions to the decision map" sub-table mapping each FR to its source quote (Trustworthy Agents / Rajasekaran / SpecKit / BMAD).
- **`docs/feature-contracts/v1.5-trustworthy-agents-deep-alignment.md`**: canonical feature contract with all 22 ACs.
- **`README.md`**: comprehensive "What's new in v1.5" section, updated Commands table (19 commands, was 10), version history.
- **`plugins/harness/skills/harness/SKILL.md`**: File Ownership Contract gains "Enforcement (FR-2, v1.5+)" subsection; new row for `stories/FR-NNN.md`; constitution.md gains second writer (constitution-amend); dispatch pattern documented.

### Schema changes (backward-compatible)

`templates/manifest.yaml` gains new fields, all with safe defaults so v1.4 manifests load unchanged:
- `harness.last_assumption_test: { date, component, canary, verdict }` (FR-5)
- `config.observability: { heartbeat, poll_interval_seconds, rate_limit_seconds }` (FR-1)
- `constitution.amendments: []` (FR-6)

Phase enum expanded with spec-edit family: `amending | clarifying | editing | tuning | constitution-amending` (in addition to existing pipeline phases).

### Known limitations

- `/harness:assumption-test` full A/B automation is partial. Env-var components (brainstorm, analyze, calibration-examples, reward-hacking-scan) work end-to-end. Prompt-modifying components (red-flags, two-stage-eval, negotiation) require a temporary plugin copy with manual instructions. Full automation is future work.
- No shipped canary corpus yet for `/harness:assumption-test` — bring your own (F13 self-test canary is the natural follow-up).
- No CI self-tests yet (bats-core for hook + scripts would be the next P0).

### Migration from v1.4

1. **Re-run `/harness:setup`** — installs the updated CLAUDE.md snippet (picks up v1.5 rule changes).
2. **Re-run `/harness:doctor`** — verifies new components (existing v1.4 manifests still pass all checks).
3. **Optional**: bump `harness.version: "1.5"` in existing manifests for accurate reporting.
4. **Optional**: add `config.observability: { heartbeat: true }` block to enable FR-1 live progress.

---

## [1.4.0] — 2026-04-20 (pre-release, superseded by 1.5.0)

SpecKit / BMAD alignment pass. 15 FRs covering coverage matrix, two-stage eval, adversarial RED FLAGS in all agents, brainstorm pre-plan, per-agent model pinning, calibration metrics, /quick-vs-/sprint rubric, rewind git semantics, doctor exit-code distinction, snippet sync, tuning-log schema, evaluator REVIEW specificity, manifest migration policy.

See `docs/feature-contracts/v1.4-speckit-bmad-alignment.md` for the full contract.

---

## [1.3.0] — 2026-04-19

Post-plan amendment flow + reward-hacking defenses + file ownership contract + environment preflight + CLAUDE.md context shrink. Introduced `/harness:clarify`, `/harness:amend`, `/harness:steer`, `/harness:rewind`, and the `CLAUDE_SUBAGENT=1` isolation guard.

---

## [1.2.0] — 2026-04-18

Plugin conversion. No design-level changes from 1.0.

---

## [1.0.0] — 2026-04-18

Initial public release.
