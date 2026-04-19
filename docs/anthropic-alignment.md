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
