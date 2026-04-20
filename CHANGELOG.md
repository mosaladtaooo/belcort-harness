# Changelog

All notable changes to BELCORT Harness are documented here. Versions follow [Semantic Versioning](https://semver.org/).

The canonical source for the *why* behind each release is [docs/feature-contracts/](docs/feature-contracts/), one file per release. This file is the user-facing summary.

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
