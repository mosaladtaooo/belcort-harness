# BELCORT Harness

An opinionated harness for Claude Code that implements a **Planner → Generator → Evaluator** pipeline, inspired by Anthropic's published research on long-running agent harness design.

Built for Claude Opus 4.6+. Tuned for TypeScript/Node.js full-stack projects but adaptable.

## What this is

A set of Skills, agent prompts, and hooks that plug into Claude Code to enable autonomous multi-agent software development. You give Claude a 1–4 sentence prompt and the harness orchestrates planning, contract negotiation, test-driven implementation, adversarial QA, and retrospective drift analysis — all file-based, all auditable via git.

This is NOT a framework or a library. It's a set of markdown files that shape how Claude Code behaves when working on substantial projects.

## Origin

Based on Anthropic Labs' engineering work:
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Rajasekaran, 2026) — the GAN-inspired three-agent architecture
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — the predecessor essay
- [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents) (2026) — calibrated uncertainty, opacity-at-scale, multi-layer defenses, approval-fatigue

…cross-pollinated with three open-source traditions:
- **GitHub SpecKit** — constitutional priority, /clarify, /analyze patterns
- **BMAD-METHOD V6** — Scrum Master agent + hyper-detailed story files
- **Superpowers (obra)** — adversarial 1% rule, brainstorming-as-mandatory, TDD discipline

See [docs/anthropic-alignment.md](docs/anthropic-alignment.md) for a point-by-point mapping between design decisions in this harness and the source material — including the v1.5 sub-table tying each new FR to its source quote.

---

## What's new in v1.5 — Trustworthy-Agents deep alignment

This release closes six gaps the v1.4 alignment pass did not address. Each is grounded in either a documented Anthropic anti-pattern, a direct prescription from Rajasekaran 2026, or a 2026 evolution of one of the three open-source traditions above.

The six FRs are summarized below; full technical detail is in [docs/feature-contracts/v1.5-trustworthy-agents-deep-alignment.md](docs/feature-contracts/v1.5-trustworthy-agents-deep-alignment.md).

### FR-1 — Subagent observability streaming
**Problem.** The orchestrator dispatches Generator/Evaluator with `claude -p` and blocks until exit. A 20-minute Generator BUILD was a black box to the human. Trustworthy Agents calls this out by name as the *opacity-at-scale* anti-pattern: *"Subagent workflows become no longer neatly visible as a single thread."*

**What v1.5 ships.** A lightweight heartbeat. Each subagent appends one structured JSONL milestone per boundary event (mode start, TDD phase boundary, FR/AC tested, blockers) to `.harness/features/${FEATURE}/_progress.jsonl`. The orchestrator polls every 10s during dispatch and prints compact `[HH:MM AGENT] phase: msg` lines so the human can follow along.

**Files added.**
- `plugins/harness/agents/_progress-protocol.md` — shared protocol (schema, when-to-emit by agent, when-NOT-to-emit anti-patterns, rate limit, emission/poller reference code)
- `plugins/harness/scripts/progress-poller.sh` — `start_progress_poller` / `stop_progress_poller` helpers, jq-or-fallback formatting, respects `manifest.config.observability.heartbeat` toggle

**Files updated.**
- `agents/{planner,generator,evaluator}.md` — each gains a §Progress Logging section pointing to the protocol, with agent-specific milestone events
- `commands/sprint.md` — wraps all 6 dispatches (Planner + 3 negotiate + BUILD + EVALUATE) with start/stop calls
- `templates/manifest.yaml` — new `config.observability` block (`heartbeat`, `poll_interval_seconds`, `rate_limit_seconds`)

**How to use.** Heartbeat is on by default in v1.5+ manifests. Set `config.observability.heartbeat: false` for fully silent runs (e.g., CI batch jobs where no human is watching).

### FR-2 — Hook-enforced spec-file ownership
**Problem.** v1.3 introduced the [File Ownership Contract](plugins/harness/skills/harness/SKILL.md) — "the orchestrator does NOT edit spec files; only fresh subagents do." But this rule was prose-only. A future Claude could violate it by Edit-ing `.harness/spec/*` directly from the orchestrator's fat-context session, leaking conversational noise into spec files. That's the exact failure mode subagent isolation exists to prevent.

**What v1.5 ships.** The `pre-tool-use.sh` hook now inspects every `Edit` and `Write` tool call (it was Bash-only before). Writes to `.harness/spec/*`, `.harness/features/*/contract.md`, and `.harness/evaluator/criteria.md` are blocked when:
- `CLAUDE_SUBAGENT≠1` (orchestrator is invoking, not a dispatched subagent), AND
- `state.phase` in `manifest.yaml` is NOT in the authorized set: `amending | clarifying | editing | tuning | retrospective | constitution-amending`

**Files added.**
- `plugins/harness/scripts/phase-guard.sh` — `phase_set` / `phase_restore` helpers, portable BSD/GNU sed handling, idempotent restore

**Files updated.**
- `plugins/harness/hooks/pre-tool-use.sh` — adds Edit/Write inspection block ahead of the existing Bash-only checks; blocks with a copy-pasteable list of correct commands
- 5 spec-edit commands gain `Step 0: Phase guard` (set "<phase>") + `Step Final: Restore phase`: `amend.md`, `clarify.md`, `edit.md`, `tune-evaluator.md`, `retrospective.md`
- `SKILL.md` — File Ownership Contract gains an "Enforcement (FR-2, v1.5+)" subsection
- `templates/manifest.yaml` — phase enum documentation expands to two families (pipeline + spec-edit)

**How to use.** Nothing new at the user level. The dedicated spec-edit commands handle the phase wrapping automatically. If you (somehow) try to use raw `Edit` on a spec file from the orchestrator, the hook now stops you and tells you which command to use instead.

### FR-3 — Mid-build pause-and-ask
**Problem.** Generator hits genuine ambiguity in BUILD (e.g., contract says "user can sort bookmarks" — sort by what?). Pre-v1.5 options:
- Guess silently → likely fails Evaluator
- Mark `partial` → costs a retry round
- Stop the build → user manually intervenes via rewind/amend

Trustworthy Agents emphasizes calibrated uncertainty by name: *"reinforce Claude's choice to pause."* The Planner had `AskUserQuestions`; the Generator did not, precisely where the cost of guessing is highest.

**What v1.5 ships.** A file-based pause matching the existing comm pattern. When the Generator hits an ambiguity it cannot reasonably guess past, it writes `.harness/features/${FEATURE}/pause-questions.md` with structured Qs. Each Q MUST include a `default if unanswered` fallback — that anti-procrastination clause forces the Generator to commit to a choice even while asking. The orchestrator detects the file, surfaces it to the user with the same UX as `/harness:clarify`, accepts answers, then re-dispatches a fresh Generator with the answers as additional context.

**Files added.**
- `plugins/harness/templates/features/pause-questions.md.txt` — structured template with self-documenting comments (lives in plugin runtime path so Generator can read it via `${CLAUDE_PLUGIN_ROOT}/templates/...`)

**Files updated.**
- `agents/generator.md` — new §Pause Protocol section under MODE: BUILD with 4 RED FLAGS calling out the rationalizations Claude will use to mis-pause (risk-aversion, API uncertainty, refactor style, time-budget questions)
- `commands/sprint.md` — Step 3a wraps post-BUILD detection: pause-loop with `MAX_PAUSES=3` per sprint and explicit `/harness:rewind negotiating` escalation when exceeded; archives pauses to `paused-history/`; increments `agent_checkins` calibration metric per pause

**How to use.** Nothing to invoke directly — pauses happen organically when Generator finds genuine ambiguity. You'll see the questions surface, answer in chat or by editing the file, and the build resumes. Repeat-pausing >3 times on the same sprint signals an under-determined contract and the orchestrator suggests a rewind.

### FR-4 — Per-FR story files (BMAD V6)
**Problem.** The aggregate `contract.md` bundles all FRs in one file. Generator BUILD reads the whole contract before each TDD cycle. As FR count grows, context budget for *the FR being worked on* shrinks. Recovery granularity is also coarse — `state.current_task: FR-005` requires re-reading the full contract on resume.

BMAD V6's Scrum Master agent solves this with per-story files: *"hyper-detailed development stories that contain everything the Dev agent needs — full context, implementation details, and architectural guidance embedded directly in story files."*

**What v1.5 ships.** Planner Pass 2 now emits ONE story per FR alongside the aggregate contract:

```
.harness/features/001-bookmarks/
├── contract.md          # Aggregate (Evaluator's source of truth, unchanged)
├── stories/
│   ├── FR-001.md        # Self-contained per-FR story
│   ├── FR-002.md
│   └── FR-003.md
└── …
```

Each story contains: the FR text + ACs + ECs (verbatim from contract — never paraphrased), persona snippet (only the personas referenced by this FR), architectural slice (only the ADRs that apply), constitution principles that bind here (subset of the 17), dev guidance from negotiation, and a TDD anchor (the observable behavior to test FIRST).

Generator BUILD reads `stories/FR-${current_task}.md` at the START of each TDD cycle. Aggregate contract is consulted only for cross-FR concerns.

**Critical invariant.** Stories MUST reference contract sections by ID — NEVER paraphrase. Drift between story and aggregate contract is a build failure (Evaluator hash-checks).

**Files added.**
- `plugins/harness/templates/features/story.md.txt` — template with the no-paraphrase invariant + authoring rules embedded as comments (lives in plugin runtime path so Planner Pass 2 can read it via `${CLAUDE_PLUGIN_ROOT}/templates/...`)

**Files updated.**
- `agents/planner.md` Pass 2 — emits `stories/` after writing the aggregate contract; authoring rules + folder layout documented; "Dev guidance" section is `{{populated by negotiate phase}}` placeholder until negotiation backfills
- `agents/generator.md` BUILD Phase 2 — reads `stories/${CURRENT_FR}.md` per TDD cycle as canonical context; falls back to aggregate contract for legacy features without `stories/` (graceful degradation)
- `commands/sprint.md` — BUILD dispatch context includes a STORY INDEX section pointing the Generator at the stories/ directory
- `SKILL.md` File Ownership Contract — new row: `features/NNN/stories/FR-NNN.md` writer = Planner Pass 2 (init) + Generator BUILD (refinements)

**How to use.** Automatic for new features in v1.5+ projects. Existing v1.4 features without `stories/` continue to work — Generator reads the aggregate contract as before.

### FR-5 — Component-as-assumption stress test
**Problem.** Direct quote from Rajasekaran 2026 — never previously implemented in any harness:

> *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing... removing one component at a time and reviewing what impact it had."*

As Claude improves (Opus 4.7, future versions), some harness components silently become dead weight; others may grow more important. Without periodic stress-testing, the harness accumulates obsolete machinery.

**What v1.5 ships.** A new command `/harness:assumption-test "<component>"` that runs a calibrated A/B with and without a named component on a user-supplied canary spec. The script computes per-criterion deltas, counts CRITICAL/MAJOR finding changes, and classifies the verdict:
- `LOAD-BEARING` — any criterion drops ≥2 points OR critical findings increase
- `MARGINAL` — criterion drops by 1 OR major findings increase
- `OBSOLETE` — no degradation; component is no longer earning its keep

Every run produces a mandatory ADR in `progress/decisions.md`.

**Initial set of testable components (7):** `brainstorm`, `negotiation`, `two-stage-eval`, `red-flags`, `calibration-examples`, `reward-hacking-scan`, `analyze`.

**Files added.**
- `plugins/harness/commands/assumption-test.md` — full procedure, supported component matrix, verdict thresholds, anti-patterns
- `plugins/harness/scripts/assumption-test.sh` — two modes: `--setup` prints the disable strategy per component (env-var auto for 4, manual plugin-copy for 3); `--compare` parses two eval-reports, computes deltas, emits JSON verdict

**Files updated.**
- `templates/manifest.yaml` — `harness.last_assumption_test` field (date, component, canary, verdict) — surfaced by `/harness:audit` for retest reminders
- `harness.version` bumped 1.4 → 1.5

**How to use.**
```bash
/harness:assumption-test "negotiation"
# → orchestrator asks for canary path
# → runs sprint with negotiation active (baseline)
# → runs sprint with negotiation skipped (without)
# → script computes verdict, you decide whether to keep or remove
```

**Cadence.** Quarterly per component. Each test runs a sprint twice — expensive. Don't run it ad-hoc.

**v1.5 limitation explicit.** Full A/B automation is partial in v1.5: env-var-driven components (`brainstorm`, `analyze`, `calibration-examples`, `reward-hacking-scan`) work end-to-end via the script. Prompt-modifying components (`red-flags`, `two-stage-eval`, `negotiation`) require a temporary plugin copy with manual instructions printed. Full automation is future work.

### FR-6 — Constitution amendment governance
**Problem.** The constitution (`spec/constitution.md`) is the project's architectural DNA. v1.0–v1.4 made it "immutable post-init" — strong but rigid. Real projects sometimes need to amend (post-incident security rule, regulatory change, scope drift). The pre-v1.5 workaround was to manually edit the file, violating both file-ownership AND immutability rules.

SpecKit handles this with explicit constitutional governance. v1.5 adopts the pattern with high ceremony — the friction is the feature, not the bug.

**What v1.5 ships.** A new command `/harness:constitution-amend "<reason>"` with FIVE ceremony stages:

1. **Typed confirmation** — must type `I-AM-AMENDING-THE-CONSTITUTION` verbatim (forces deliberate intent)
2. **≥50-char reason** — forces explanation that becomes the ADR
3. **In-progress feature handling** — surfaces the cost (current feature halts or ships under old rules)
4. **Mandatory ADR** in `progress/decisions.md` — leaves an audit trail
5. **Re-validation pass** against every completed feature — catches the case where past work no longer complies

**Files added.**
- `plugins/harness/commands/constitution-amend.md` — full procedure with all 5 ceremony stages, anti-patterns, why-so-much-ceremony rationale

**Files updated.**
- `agents/planner.md` — new MODE: CONSTITUTION-AMEND that structurally mirrors AMEND mode; identifies principle add/change/remove, drafts patches, flags conflicts, refuses non-testable principles, refuses §-renumbering
- `agents/evaluator.md` — new MODE: REVALIDATE for STATIC constitutional audit (no Playwright, no test runs); per-principle PASS/FAIL/N/A report with backport-vs-grandfather recommendations
- `SKILL.md` File Ownership Contract — `constitution.md` gains a SECOND writer (`/harness:constitution-amend`, behind the ceremony gates)
- `templates/manifest.yaml` — `constitution.amendments` append-only history with full schema documented inline
- The FR-2 hook already supports `constitution-amending` phase — wires together cleanly

**How to use.** Don't use it casually. The ceremony exists because constitutional change cascades into every prior feature. When you do use it:

```bash
/harness:constitution-amend "Add §17: all PII fields MUST be encrypted at rest. Reason: Q2 incident IR-2026-04 found unencrypted email addresses in audit logs."
# → typed confirmation prompt
# → in-progress feature handling
# → Planner drafts patches → you review
# → Evaluator REVALIDATEs each completed feature → you decide backport vs grandfather
# → patches applied → ADR written → manifest history updated
```

---

## v1.5 design choices worth knowing

- **Phase enum splits two families.** Pipeline phases (`planning|analyzing|negotiating|building|evaluating|retrospective|complete`) describe normal sprint flow. Spec-edit phases (`amending|clarifying|editing|tuning|constitution-amending`) authorize the FR-2 hook to permit orchestrator-side spec writes. The `retrospective` phase is in both families. See `templates/manifest.yaml` for inline documentation.

- **No breaking schema changes.** All new manifest fields have safe defaults. v1.4 manifests load without modification; new fields read as their documented defaults. The `harness.version` bump 1.4 → 1.5 is informational, not blocking.

- **Backward-compatible degradations.** v1.5 features fall back gracefully on legacy state:
  - FR-1 heartbeat is opt-out via `config.observability.heartbeat: false`
  - FR-2 hook fails open if jq/python3 missing (existing pattern)
  - FR-4 Generator uses aggregate contract when `stories/` is missing
  - FR-5 manifest field defaults to empty (no test ever run)

- **All shell scripts pass `bash -n`.** Verified at build time. Hook + helpers are portable across BSD (macOS) and GNU (Linux) sed/awk via runtime detection.

---

## Migrating from v1.4

For existing projects:

1. **Re-run `/harness:setup`** — re-installs the global CLAUDE.md snippet, picks up any v1.5 rule changes
2. **Re-run `/harness:doctor`** — verifies new components install correctly; existing v1.4 manifests still pass all checks
3. **Optional: bump manifest** — change `harness.version: "1.4"` → `harness.version: "1.5"` for accurate reporting. Existing values for `config.calibration_metrics`, `tuning_debt`, etc. carry over unchanged.
4. **Optional: enable observability** — add `config.observability: { heartbeat: true }` block to manifest if you want the FR-1 live progress lines. Default is on for v1.5+ manifests.

For new projects, the v1.5 plugin install handles everything — `/harness:sprint` Just Works.

## Core design decisions (and their Anthropic-article basis)

| Decision | Source |
|---|---|
| Three agents (Planner / Generator / Evaluator) as separate subagents | GAN-inspired architecture described in the Anthropic post |
| Evaluator MUST have separate context from Generator | "Separating the agent doing the work from the agent judging it proves to be a strong lever" |
| Planner outputs high-level direction only, NOT file paths or components | "stay focused on product context and high level technical design rather than detailed technical implementation" |
| Generator and Evaluator negotiate a sprint contract BEFORE any code is written | "Before each sprint, the generator and evaluator negotiated a sprint contract... before any code was written" |
| File-based agent communication | "Communication was handled via files: one agent would write a file, another agent would read it..." |
| Evaluator grades against 4 hard-threshold criteria | "Each criterion had a hard threshold, and if any one fell below it, the sprint failed" |
| Few-shot calibration examples for Evaluator scoring | "I calibrated the evaluator using few-shot examples with detailed score breakdowns" |
| Tuning loop: capture human-Evaluator divergence, refine over time | "The tuning loop was to read the evaluator's logs, find examples where its judgment diverged from mine..." |
| Criteria weighting emphasizes model's weak dimensions | "by weighting design and originality more heavily it pushed the model toward more aesthetic risk-taking" |
| Criteria wording deliberately chosen (shapes Generator output, not just Evaluator scoring) | "The wording of the criteria steered the generator in ways I didn't fully anticipate" |

## Installation

Requires Claude Code installed and working.

### Option A — Plugin install (recommended)

```
/plugin marketplace add mosaladtaooo/belcort-harness
/plugin install harness@belcort-harness
/harness:setup
```

That's it. The plugin auto-registers the skill, three agents, ten slash commands, two hooks (SessionStart + PreToolUse), and two MCP servers (context7 + playwright). The one-time `/harness:setup` command patches `~/.claude/CLAUDE.md` with the harness behavioral rules so they apply globally and survive context compaction. The patch is idempotent, version-aware, and removable (`scripts/uninstall-rules.sh`).

### Option B — Manual install (legacy)

```bash
git clone https://github.com/mosaladtaooo/belcort-harness.git
cd belcort-harness
./install/install.sh
```

Complete the two manual steps the installer prints (append CLAUDE.md snippet, register hooks in `~/.claude/settings.json`).

Verify either install:

```bash
./install/verify.sh
```

## Quick start

Once installed, in any project directory:

```bash
# Start Claude Code, then:
/harness:sprint "Build a minimal bookmark manager with tags and search"
```

The harness will orchestrate planning, negotiation, build, and evaluation across the session. Your feedback gets captured into the Evaluator tuning loop for next time.

## Commands

| Command | What it does |
|---|---|
| `/harness:sprint "<prompt>"` | Full pipeline: plan → analyze → negotiate → build → evaluate → tune → retrospect → merge |
| `/harness:quick "<prompt>"` | Skip planning. Minimal contract. Single build + QA pass |
| `/harness:resume` | Continue an interrupted pipeline from the last checkpoint |
| `/harness:validate` | Audit existing spec files against the 16-point quality checklist |
| `/harness:edit "<change>"` | Targeted spec modification with downstream reference updates |
| `/harness:analyze` | Cross-artifact consistency check (PRD vs architecture vs contract) |
| `/harness:negotiate` | Generator ↔ Evaluator contract negotiation before build |
| `/harness:retrospective` | Post-merge drift analysis — sync spec with what was built |
| `/harness:tune-evaluator` | Review Evaluator divergence patterns; propose calibration improvements |
| `/harness:audit` | Verification debt scan — find deferred issues |
| `/harness:assumption-test "<component>"` (v1.5) | Component-as-assumption stress test — A/B a harness component on a canary spec, classify LOAD-BEARING/MARGINAL/OBSOLETE. Quarterly cadence. |
| `/harness:constitution-amend "<reason>"` (v1.5) | High-ceremony constitution change — typed confirmation + ≥50-char reason + revalidation against every completed feature. The ONLY authorized path to amend `spec/constitution.md` after Planner Pass 1. |

## What it produces

A `.harness/` directory in your project, git-tracked and append-only:

```
.harness/
├── manifest.yaml
├── ROADMAP.md
├── spec/          # PRD, architecture, constitution, evaluator notes
├── features/      # Per-feature folders with contract/proposal/review/reports
├── evaluator/     # Criteria, few-shot examples, tuning log
└── progress/      # Changelog, ADRs, known issues
```

## Non-goals

- **Not a general agent framework.** Use LangGraph or CrewAI for that.
- **Not a replacement for human review.** The human gate after planning is mandatory.
- **Not optimized for trivial tasks.** For <15 minute work, `/harness:quick` or no harness at all.

## Status

This harness is actively used for BELCORT AI Consulting's internal projects. It is opinionated and evolves frequently. Breaking changes are documented in CHANGELOG.md.

**Current branch.** This is the `harness/v1.5-trustworthy-agents-deep-alignment` branch — the v1.5 release candidate. See [What's new in v1.5](#whats-new-in-v15--trustworthy-agents-deep-alignment) above for the FR-by-FR breakdown. The release candidate is open for review against `release/v1.4`.

**Released versions.**
- v1.5 (this branch) — Trustworthy-Agents deep alignment: subagent observability, hook-enforced spec ownership, mid-build pause, per-FR story files, component-as-assumption test, constitution amendment governance
- v1.4 — SpecKit/BMAD alignment: coverage matrix, two-stage eval, RED FLAGS in all agents, brainstorm pre-plan, per-agent model pinning, calibration metrics
- v1.3 — Post-plan amendment flow, reward-hacking defenses, file ownership contract, environment preflight
- v1.2 — Plugin conversion
- v1.0 — Initial public release

Not affiliated with Anthropic.

## License

[MIT](LICENSE) — see the LICENSE file.

## Acknowledgements

- The Anthropic Labs team, particularly Prithvi Rajasekaran, for publishing the underlying research
- The Claude Code engineering team for the Agent SDK and the MCP protocol
