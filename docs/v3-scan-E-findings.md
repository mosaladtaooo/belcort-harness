# Scan E — Command-set redundancy review

**Date:** 2026-05-07
**Result:** NULL — no merge candidates

## Methodology

Inventoried every file under `plugins/harness/commands/` (16 confirmed via Glob `*.md`). For each command, read the YAML frontmatter `description:` line plus enough of the procedure body to verify that the description matches the actual behaviour. Grouped commands into the five clusters spec § 6 Scan E specified (Lifecycle, Spec-edit, Audit family, Tuning, Management) and confirmed all 16 fit. Within each cluster, asked: "do any two commands answer the same question?" Probed the two low-confidence merge candidates the spec explicitly flagged: `/harness:analyze` + `/harness:validate`, and `/harness:audit` + `/harness:retrospective`. Cross-referenced against the existing audit-family mnemonic in `plugins/harness/skills/harness/SKILL.md` § Audit Commands (lines 331–360), which already justifies the separation explicitly.

## Inventory (16 commands)

| Command | Question it answers |
|---------|---------------------|
| `/harness:sprint` | "Run the full plan→analyze→gate→negotiate→build→simulate→evaluate→retrospect→merge pipeline for a substantial feature." |
| `/harness:quick` | "Run a fast single-pass Generator↔Evaluator path for a small (<30 min) task that doesn't need a Planner." |
| `/harness:resume` | "Continue an interrupted pipeline by reading manifest+changelog+git log and dispatching the right subagent for the current phase." |
| `/harness:brainstorm` | "Pre-plan exploration for a vague request — interview the user, surface assumptions, write `brainstorm-current.md` so the next `/sprint` has a concrete prompt." |
| `/harness:clarify` | "Surface ambiguities the Planner found, collect user answers in `clarifications.md`, dispatch a fresh Planner to apply them as surgical patches." |
| `/harness:amend` | "Apply a single targeted spec change (typically one file) via a fresh Planner subagent producing before→after patches." |
| `/harness:edit` | "Apply a cross-file cascade-aware spec change (architecture+init.sh+NFRs+contract) via a fresh Planner that propagates the change coordinately." |
| `/harness:constitution-amend` | "High-ceremony constitution change with five gates (typed confirm, ≥50-char reason, in-progress handling, ADR, REVALIDATE every completed feature)." |
| `/harness:analyze` | "Cross-artifact consistency: does PRD ↔ architecture ↔ contract align (FR coverage, AC coverage, NFR realism, constitution compliance, dependency order)?" |
| `/harness:validate` | "Per-spec-file completeness: run the Planner's 18-point V1–V18 checklist against `.harness/spec/` files. Each file self-sufficient?" |
| `/harness:audit` | "Verification debt across features over time: deferred Major/Minor findings, stale known-issues, silent skips, deleted-test reward-hacking, calibration metric trends." |
| `/harness:retrospective` | "Reality alignment for the current feature: does the shipped code match the contract? Classify positive/negative/neutral drift, propose spec updates." |
| `/harness:tune-evaluator` | "Review accumulated `tuning-log.md` divergences and propose calibration improvements (prefer few-shot examples over prompt edits)." |
| `/harness:rewind` | "Archive-based reset of the current feature to an earlier phase (planning/analyzing/negotiating/building/simulating/evaluating). Files move to `.archive/`, not deleted." |
| `/harness:setup` | "First-run installer: scaffold `.harness/` from templates and write project-local `./CLAUDE.md` activation rules. Idempotent." |
| `/harness:doctor` | "Environment preflight: audit Claude Code CLI, git, Node 20+, Context7 MCP, Playwright MCP, writable `.harness/`. Block pipeline on CRITICAL failures." |

Count: 16. Matches the spec.

## Per-cluster analysis

### Lifecycle — `/sprint`, `/quick`, `/resume`, `/brainstorm`

Each answers a distinct lifecycle question: substantial feature pipeline (`/sprint`), trivial-scope fast path (`/quick`), recover-after-interrupt (`/resume`), pre-plan-when-prompt-vague (`/brainstorm`). `/sprint` and `/quick` look superficially similar but the When-to-use table inside `quick.md` (Scope/Novel-decisions/Test-strategy/Time/AC-clarity/Constitution-impact/Bug-fix axes) makes the boundary mechanical, not vibes-based — and `/quick` auto-promotes to `/sprint` on PARTIAL self-eval, so the two are complementary, not redundant. `/brainstorm` is strictly upstream of `/sprint` and explicitly disclaims "writing specs (that's the Planner's job)". `/resume` is recovery, orthogonal to the others.

### Spec-edit — `/clarify`, `/amend`, `/edit`, `/constitution-amend`

Each answers a distinct spec-edit question, separated by intent and ceremony level. `/clarify` resolves Planner-flagged ambiguities via a structured Q&A file flow (clarifications never travel through orchestrator chat). `/amend` is single-target wording change (one file usually). `/edit` is cross-file cascade (3+ files coordinated). `/constitution-amend` is the one authorized path for the deliberately-immutable constitution and ships with five gates plus mandatory REVALIDATE. The "When NOT to use" sections in each command file cross-reference the others, confirming the authors have already de-duplicated the boundaries.

### Audit family — `/analyze`, `/validate`, `/audit`, `/retrospective` (+ Evaluator REVALIDATE mode)

This is the cluster spec § 6 Scan E flagged as the most plausible merge candidate. The harness already has an authoritative answer in `SKILL.md` § Audit Commands lines 331–360 with an explicit five-line mnemonic:

> - **analyze** = consistency (files talking to each other)
> - **validate** = completeness (each file self-sufficient)
> - **audit** = debt (stale/deferred things accumulating over time)
> - **REVALIDATE** = backward compatibility (old features vs new constitution)
> - **retrospective** = reality alignment (spec vs what-was-built)

Five orthogonal questions. The SKILL.md examples make the orthogonality concrete (a spec can pass analyze but fail validate; pass both but accumulate audit debt; pass all three but the code drifted from it; etc.). Probed both low-confidence pairs below — both reject.

### Tuning — `/tune-evaluator`

Singleton cluster. Reviews Evaluator divergence patterns and proposes calibration adjustments to `examples.md` (preferred) or the criteria prompt (only when systematic). No overlap with any audit-family command — those audit *spec or feature* state; this audits *Evaluator behaviour*.

### Management — `/rewind`, `/setup`, `/doctor`

Three distinct management questions: rollback-the-current-feature (`/rewind`), first-time-install (`/setup`), check-environment-health (`/doctor`). `/setup` and `/doctor` border on each other — `/setup` even calls `doctor.sh` as Step 2 — but `/setup` mutates state (creates `.harness/`, writes `CLAUDE.md`) while `/doctor` is read-only and is auto-invoked at every `/sprint` and `/quick` start. Different cadence, different side-effects, no merge candidate.

## Probed merge candidates

### `/harness:analyze` + `/harness:validate`

- `/analyze` runs across PRD ↔ architecture ↔ contract and asks "are these three documents internally consistent?" (FR coverage matrix, AC coverage matrix, NFR realism, dependency ordering). It writes `features/NNN/analysis-report.md` and CRITICAL findings halt the pipeline.
- `/validate` runs against `.harness/spec/*` files and asks "does each spec file individually pass the 18-point V1–V18 quality checklist?" (SMART NFRs, traceability, wording does work, etc.). It is per-file, completeness-focused, no consistency cross-checks.

A spec can be consistent yet incomplete (analyze passes, validate catches missing ACs in a single file). A spec can be complete yet inconsistent (validate passes file-by-file, analyze catches a contract AC that doesn't appear in the PRD). The SKILL.md examples encode this exactly. **Distinct questions — reject merge.**

### `/harness:audit` + `/harness:retrospective`

- `/audit` is cross-feature historical: scans `manifest.yaml verification_debt`, every `features/*/eval-report.md` deferred-finding, `progress/known-issues.md` for >30-day-old items, every `features/*/retrospective.md` for unresolved drift, plus a reward-hacking sweep against the current codebase (missing test files, `.skip()` markers, deleted test files without ADR), plus calibration-metrics trend analysis. Output goes to screen only — diagnostic, not authoritative.
- `/retrospective` is current-feature post-build: reconciles the just-shipped contract against actually-built code, classifies drift into positive/negative/neutral, and proposes specific PRD/architecture updates that the user approves and the orchestrator applies. Output is `features/NNN/retrospective.md` plus spec patches.

`/audit` is "what's accumulating across all features?", `/retrospective` is "did the latest feature drift from its contract?" Different temporal scope (cross-feature historical vs single-feature post-build), different output (screen-only diagnostic vs file-writing reconciliation), different cadence (manual weekly/monthly vs automatic post-PASS in `/sprint`). **Distinct questions — reject merge.**

## Conclusion

NULL result. All 16 commands answer distinct questions. The audit family in particular (analyze/validate/audit/retrospective + Evaluator REVALIDATE mode) is already explicitly justified by the SKILL.md mnemonic and the orthogonal-question-failure examples that follow it; that justification matches what the command files actually do. The Lifecycle, Spec-edit, Tuning, and Management clusters all separate cleanly with cross-referenced "When NOT to use" sections in the command files. No merge candidates surface.

The audit confirms the spec § 6 Scan E prediction (likely null result). v2.2 already trimmed `/harness:negotiate` as a separate command; the remaining 16 are at the Pareto frontier of single-purpose / non-overlapping coverage.
