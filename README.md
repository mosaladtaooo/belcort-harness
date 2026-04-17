# BELCORT Harness

An opinionated harness for Claude Code that implements a **Planner → Generator → Evaluator** pipeline, inspired by Anthropic's published research on long-running agent harness design.

Built for Claude Opus 4.6+. Tuned for TypeScript/Node.js full-stack projects but adaptable.

## What this is

A set of Skills, agent prompts, and hooks that plug into Claude Code to enable autonomous multi-agent software development. You give Claude a 1–4 sentence prompt and the harness orchestrates planning, contract negotiation, test-driven implementation, adversarial QA, and retrospective drift analysis — all file-based, all auditable via git.

This is NOT a framework or a library. It's a set of markdown files that shape how Claude Code behaves when working on substantial projects.

## Origin

Based on Anthropic Labs' engineering blog post [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Rajasekaran, 2026) and its predecessor [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

See [docs/anthropic-alignment.md](docs/anthropic-alignment.md) for a point-by-point mapping between design decisions in this harness and the source material.

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

Requires Claude Code (claude.ai/code) installed and working.

```bash
git clone https://github.com/<you>/belcort-harness.git
cd belcort-harness
./install/install.sh
```

Then complete the two manual steps the installer prints (append CLAUDE.md snippet, register hooks in settings.json).

Verify:

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

Not affiliated with Anthropic.

## License

[Your choice — MIT or Apache 2.0 recommended]

## Acknowledgements

- The Anthropic Labs team, particularly Prithvi Rajasekaran, for publishing the underlying research
- The Claude Code engineering team for the Agent SDK and the MCP protocol
