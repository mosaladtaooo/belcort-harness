# Anthropic-alignment map

A point-by-point trace from BELCORT Harness design decisions back to the Anthropic engineering articles that motivate them. Updated as the harness evolves.

## Primary sources

1. **[Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps)** — Prithvi Rajasekaran, Anthropic Labs, 2026. Henceforth **Rajasekaran 2026**.
2. **[Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)** — the predecessor to Rajasekaran 2026. Henceforth **Effective Harnesses**.
3. **[Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents)** — Anthropic, 2026. Henceforth **Trustworthy Agents**.

## Decision map

| BELCORT design decision | Source | Specific quote or principle |
|---|---|---|
| Three agents (Planner, Generator, Evaluator) each as a fresh subagent | Rajasekaran 2026 | GAN-inspired architecture: generator produces, evaluator grades; separation of roles. |
| Evaluator MUST have separate context from Generator | Rajasekaran 2026 | *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* |
| Planner outputs high-level direction only — no file paths or component details | Rajasekaran 2026 | *"Stay focused on product context and high level technical design rather than detailed technical implementation."* |
| Generator and Evaluator negotiate a sprint contract BEFORE any code is written | Rajasekaran 2026 | *"Before each sprint, the generator and evaluator negotiated a sprint contract… before any code was written."* |
| File-based agent communication | Rajasekaran 2026 | *"Communication was handled via files: one agent would write a file, another agent would read it."* |
| Evaluator grades against 4 hard-threshold criteria | Rajasekaran 2026 | *"Each criterion had a hard threshold, and if any one fell below it, the sprint failed."* |
| Few-shot calibration examples for Evaluator scoring | Rajasekaran 2026 | *"I calibrated the evaluator using few-shot examples with detailed score breakdowns."* |
| Tuning loop: capture human-evaluator divergence, refine over time | Rajasekaran 2026 | *"The tuning loop was to read the evaluator's logs, find examples where its judgment diverged from mine… It took several rounds before the evaluator was grading in a way that I found reasonable."* |
| Criteria weighting emphasises the model's weak dimensions | Rajasekaran 2026 | *"By weighting design and originality more heavily it pushed the model toward more aesthetic risk-taking."* |
| Criteria wording deliberately chosen (shapes Generator output, not just Evaluator scoring) | Rajasekaran 2026 | *"The wording of the criteria steered the generator in ways I didn't fully anticipate."* |
| Context strategy is fresh-subagent, not compaction | Rajasekaran 2026 | *"Context resets superior for models exhibiting context anxiety."* (Opus 4.6 largely eliminates this; harness still prefers fresh subagents for isolation.) |
| Structured handoff artifacts between agents | Rajasekaran 2026 | *"Use structured files to carry previous agent state and next steps across context boundaries."* |
| Explicit Evaluator skepticism (ANTI-LENIENCY PROTOCOL) | Rajasekaran 2026 | *"Evaluators identify legitimate issues, then talk themselves into deciding they weren't a big deal and approve the work anyway."* |
| Playwright MCP for Evaluator browser-driven QA | Rajasekaran 2026 | *"Evaluator navigates live application using Playwright MCP (screenshot-based assessment)."* |
| Specific bug findings preferred over vague assessments | Rajasekaran 2026 | *"Tool only places tiles at drag start/end points instead of filling region"* is a good example; vague assessments are the anti-pattern. |
| Sprint-based decomposition for large projects | Rajasekaran 2026 | *"Break complex builds into discrete chunks (sprints with Opus 4.5; continuous with Opus 4.6)."* |
| Iterative refinement with 5–15 iterations per generation | Rajasekaran 2026 | *"Run 5–15 iterations per generation with feedback incorporation."* |
| Simplest-solution-first principle | Rajasekaran 2026 | *"Find the simplest solution possible, and only increase complexity when needed."* |
| Human-in-the-loop gate after planning | Trustworthy Agents + Rajasekaran 2026 | Trustworthy Agents' Plan Mode: *"Claude displays its intended plan of action up-front for user review before execution."* |
| Uncertainty recognition — agents pause when ambiguous | Trustworthy Agents | *"Models are trained through scenarios that place Claude in ambiguous situations, and then reinforce Claude's choice to pause."* Operationalised in `/harness:clarify`. |
| Multi-layer safety defenses | Trustworthy Agents | *"Multi-layer defenses: train the model, monitor production, red-team battle test."* Applied in the reward-hacking defenses (hook + prompt + scan + audit). |
| File-based amendment flow (v1.3) | Rajasekaran 2026 + BMAD issue #927 | File-first communication extended to post-plan amendments: `/harness:clarify`, `/harness:amend`, `/harness:steer` all author via files, never via orchestrator chat. |
| Subagent env-var isolation guard (v1.3) | Rajasekaran 2026 | Operationalises *"keeps each subagent's context clean"* by deterministically gating state injection via `CLAUDE_SUBAGENT=1`. |
| Reward-hacking defenses (v1.3) | Trustworthy Agents | Explicit counter-measures for the documented generator-evaluator gaming risk. |
| Environment preflight doctor (v1.3) | Rajasekaran 2026 (operational reliability) | If the surrounding tools (MCPs) aren't responding, the whole generator-evaluator loop degrades silently. Preflight detects this before any tokens are spent. |
| Archive-based rewind instead of destructive reset (v1.3) | Trustworthy Agents | *"Checkpoints let you undo file changes."* Extended to phase-level granularity. |
| Stale-assumption pruning of per-FR story files (v2.2) | Rajasekaran 2026 | *"Every component in a harness encodes an assumption… those assumptions are worth stress testing… can quickly go stale as models improve."* The BMAD-V6 per-FR scoping assumption staled on Opus 4.7[1m]; story files removed. |
| Soft-only Planner feature-size gate (v2.2) | Rajasekaran 2026 | *"With Opus 4.6 I dropped context resets from this harness entirely."* Same logic applied to the historical hard-gate intent: trust the more-capable model; signal-only at the Planner stage. |
| Planner mode collapse (v2.2) | Rajasekaran 2026 | *"Find the simplest solution possible, and only increase complexity when needed."* Single source of truth per mode constraint via dispatch-prompt markers. |
| Generator pause-time state snapshot (v2.2) | Rajasekaran 2026 | *"Use structured files to carry previous agent state and next steps across context boundaries."* File-based state at the boundary, not state inferred from a globally-mutable file. |
| `/harness:negotiate` standalone removed (v2.2) | Rajasekaran 2026 | *"Stripping away pieces that are no longer load-bearing."* Auto-invoked + recoverable via `/harness:resume`; standalone front door was unused. |
| 1M-context confirmation banner (v2.2) | Rajasekaran 2026 (operational reliability) | If the active model isn't the [1m] variant, the conditions for context-budget truncation re-emerge. Confirmation gate, not mechanical detection (Claude Code doesn't expose `--model` to plugins). |

## Deviations from the source material

These are places where BELCORT intentionally diverges from or extends beyond Rajasekaran 2026:

- **Constitution as immutable post-init** — not in the source; adopted from [GitHub Spec Kit's constitutional priority principle](https://github.com/github/spec-kit).
- **TDD discipline (RED → GREEN → REFACTOR → COMMIT)** — not emphasised in the source as strongly as in BELCORT; inspired by [Superpowers' TDD skill](https://github.com/obra/superpowers).
- **File ownership contract** — not in the source; BELCORT-specific codification to prevent orchestrator-authored spec edits.
- **Retrospective drift analysis** — not in the source in this exact form; BELCORT synthesises it from typical software-engineering retrospective practice.
- **/harness:clarify and /harness:amend** — patterned after [SpecKit's /speckit.clarify](https://github.com/github/spec-kit) but with surgical patches instead of whole-file regeneration (avoiding [SpecKit issue #1391](https://github.com/github/spec-kit/issues/1391)).
- **/harness:rewind archive mechanism** — BELCORT-specific; partially inspired by Claude Code's checkpoint feature, extended to phase granularity.

## Version provenance

This document is maintained alongside the harness. When a design decision changes, update the corresponding row here along with the change. The harness's value as an implementation of Anthropic's published research depends on this traceability being accurate.

- v1.0 — initial public release (baseline)
- v1.2 — plugin conversion; no design-level changes
- v1.3 — post-plan amendment flow (`clarify`, `amend`, `steer`, `rewind`), evaluator reward-hacking defenses, file ownership contract, subagent env-var isolation, environment preflight, CLAUDE.md context shrink
- v1.4 — speckit-bmad alignment pass (FR-1 through FR-15): coverage matrix, doctor parser check, adversarial RED FLAGS in Planner+Generator, two-stage eval (Part A binary gates Part B numeric), artifact templates, brainstorm pre-plan, per-agent model pinning, calibration metrics counter, /quick-vs-/sprint rubric, rewind git semantics, doctor exit-code distinction, snippet sync, tuning-log schema, evaluator REVIEW specificity, manifest migration policy
- v1.5 — trustworthy-agents deep alignment pass: subagent observability streaming (heartbeat + poller), hook-enforced spec-file ownership (behavioral → mechanical), mid-build pause-and-ask (Generator gains calibrated-uncertainty path), per-FR story files (BMAD V6 hyper-detailed pattern), component-as-assumption stress test (operationalises Rajasekaran 2026 quote), constitution amendment governance (SpecKit pattern with high ceremony)
- v2.0 — minimalist refactor, directly motivated by Rajasekaran 2026's quote: *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."* Removed components whose underlying assumption went stale on Opus 4.7: progress-poller + heartbeat (stdout streaming is native), phase-guard + FR-2 hook (instruction-following on prose constraints is reliable), `/harness:assumption-test` command (meta-tool never run in practice), `/harness:steer` (retry loop + amend cover its cases), per-agent model pinning (undocumented, unused), global CLAUDE.md install (scoping violation). Preserved: every Anthropic-aligned core capability (GAN isolation, file-based comm, negotiation, Playwright evaluation, few-shot calibration, two-stage grading, tuning loop, pause protocol). ~45% LoC reduction. Full plan: `docs/superpowers/plans/2026-04-21-belcort-v2-minimalist-refactor.md`. Full spec: `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md`.
- v2.2 — stale-assumption pruning + operational hardening: per-FR story files removed (Anthropic *"every component encodes an assumption that may go stale"*), Planner mode collapse (4 post-PLAN modes → unified EDIT, single source of truth via dispatch markers), `/harness:negotiate` standalone removed, Generator pause snapshot (file-based state at boundaries), 1M-context confirmation banner (operational), soft-only Planner feature-size gate. Trust-the-model stance documented as conditional on 1M-context launch. ~300 LoC reduction. Full plan: `docs/superpowers/plans/2026-04-28-belcort-audit-and-refine.md`. Full spec: `docs/superpowers/specs/2026-04-28-belcort-audit-and-refine-design.md`.

## v1.5 additions to the decision map

| BELCORT design decision | Source | Specific quote or principle |
|---|---|---|
| Subagent observability streaming via heartbeat (FR-1) | Trustworthy Agents §opacity-at-scale | *"Subagent workflows become no longer neatly visible as a single thread."* Closed by per-subagent JSONL milestone emission + orchestrator polling during dispatch. |
| Hook-enforced spec-file ownership (FR-2) | BELCORT-specific (defensive depth on the v1.3 File Ownership Contract) | The v1.3 contract was prose-only. v1.5 promotes it to a `pre-tool-use.sh` Edit/Write check gated on `state.phase` ∈ allowed set. Behavioral → mechanical. |
| Mid-build pause-and-ask protocol (FR-3) | Trustworthy Agents §calibrated-uncertainty | *"Models are trained through scenarios that place Claude in ambiguous situations, and then reinforce Claude's choice to pause."* Planner had AskUserQuestions; Generator now has file-based pause-questions.md with mandatory "default if unanswered" anti-procrastination clause. |
| Per-FR story files — BMAD V6 hyper-detailed pattern (FR-4) | BMAD V6 Scrum Master agent | BMAD V6 ships per-story files containing "everything the Dev agent needs — full context, implementation details, and architectural guidance embedded directly in story files." Adopted as `features/NNN/stories/FR-NNN.md`, with strict no-paraphrase invariant against the aggregate contract. |
| Component-as-assumption stress test (FR-5) | Rajasekaran 2026 (direct, previously-unimplemented prescription) | *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing... removing one component at a time and reviewing what impact it had."* Operationalised as `/harness:assumption-test` with calibrated A/B + LOAD-BEARING/MARGINAL/OBSOLETE verdict + mandatory ADR. |
| Constitution amendment governance (FR-6) | SpecKit constitutional governance pattern | SpecKit calls the constitution *"the architectural DNA of the system, ensuring every generated implementation maintains consistency, simplicity, and quality."* v1.5 adds the ONE authorized path to amend it: 5 ceremony stages including typed confirmation, ≥50-char reason, in-progress feature handling, mandatory ADR, and revalidation pass against every completed feature via Evaluator REVALIDATE mode. |
