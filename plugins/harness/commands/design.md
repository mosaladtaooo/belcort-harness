---
description: Designer subagent orchestration — visual exploration, hi-fi prototype, design tokens, audit, extract. v1 Step 1 ships explore + reroll; teach/audit/extract land in Steps 2–4. Writes only to .harness/design/, never to source.
argument-hint: "<subcommand> [args]"
---

# `/harness:design` — Designer orchestration

Wraps the `harness:designer` subagent (which itself wraps `huashu-design` and later `impeccable`). Subcommands route to Designer modes via `--- MODE: X ---` markers and handle the human-gate flow when a mode produces artifacts the user has to react to (e.g., picking one of three directions).

The orchestrator NEVER authors design content — it only dispatches the Designer subagent, presents Designer's output to the user at the gate, and re-dispatches with the user's pick or feedback. The Designer subagent owns all writes under `.harness/design/`. The orchestrator does NOT modify source code, spec files, or feature contracts in any subcommand here.

The user's request is `$ARGUMENTS`. Parse the first whitespace-separated token as the subcommand; everything after the first token is the arg payload (intent text, feedback text, etc.). If `$ARGUMENTS` is empty, show the usage block at the bottom and exit.

---

## Procedure

### Step 0: Verify or create the design directory

Before any subcommand, the orchestrator runs:

```bash
mkdir -p .harness/design
mkdir -p .harness/design/directions
mkdir -p .harness/design/prototype
```

This is idempotent. If `.harness/` itself doesn't exist (the harness has never been initialized in this project), tell the user "No `.harness/` in this project. Run `/harness:setup` first to initialize the harness." and exit. The Designer can run on a project that hasn't gone through `/harness:sprint` yet (you can explore design before specifying anything), but it does need `.harness/` to write into.

### Step 1: Route to subcommand

Route on the first token of `$ARGUMENTS`:

- `explore "<intent>"` → § Subcommand: explore
- `reroll "<feedback>"` → § Subcommand: reroll
- `teach` → § Subcommand: teach (stub for Step 2)
- `audit` → § Subcommand: audit (stub for Step 3)
- `extract` → § Subcommand: extract (stub for Step 4)
- anything else → show usage block, exit

---

## Subcommand: `explore "<intent>"`

Generates 3 visual directions, halts at user-pick gate, then on user pick re-dispatches Designer to produce a hi-fi prototype.

### Step 1: Validate intent

Strip the leading `explore` token from `$ARGUMENTS`; the remainder is the user's intent (typically wrapped in quotes — strip them). If empty (`/harness:design explore` with no payload), tell the user:

> Intent is required. Example: `/harness:design explore "Modern dashboard for a small SaaS team"`. Run again with an intent string.

…and exit.

### Step 2: Brownfield gate (advisory)

If `.harness/design/extraction/extracted-tokens.md` does NOT exist AND the project has UI source (look for any of: `package.json` with React/Vue/Svelte deps, files matching `src/**/*.{tsx,jsx,vue,svelte}`, `app/**/*.{tsx,jsx}`):

Show the user an advisory:

```
═══════════════════════════════
  Harness — Design Explore
═══════════════════════════════
Heads-up: this project looks brownfield (UI source detected) and no
extracted design tokens are on file at .harness/design/extraction/
extracted-tokens.md.

The Designer will halt with a recommendation to run `/harness:design extract`
first if it determines the existing design language matters here.

Continue anyway / cancel?
═══════════════════════════════
```

If the user cancels, exit. Otherwise, proceed — the Designer subagent applies the actual brownfield-gate per its EXPLORE Step 1 logic; the orchestrator's advisory is a courtesy.

### Step 3: Dispatch Designer in EXPLORE mode (round 1: directions)

The orchestrator dispatches the Designer via the Agent tool:

- **subagent_type**: `harness:designer`
- **description**: `"Explore visual directions for: <one-line of intent>"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> --- MODE: EXPLORE ---
>
> You are being dispatched in EXPLORE mode (round 1 — direction generation). Read inputs per your EXPLORE Step 1 (`.harness/spec/constitution.md`, `.harness/design/PRODUCT.md`, `.harness/design/DESIGN.md`, `.harness/design/extraction/extracted-tokens.md` if they exist). Construct a huashu-design prompt per your EXPLORE Step 2. Invoke `Skill(huashu-design)` once for direction generation. Write 3 differentiated HTML samples to `.harness/design/directions/direction-{1,2,3}.html` plus `directions-summary.md`. Halt at the user-pick gate per your EXPLORE Step 7.
>
> Working directory contract: your cwd is the project root; never read or write `.worktrees/current/.harness/`.
>
> User intent:
> <intent string from arguments>

### Step 4: Present directions to user (human gate)

After Designer returns, the orchestrator reads `.harness/design/directions/directions-summary.md` and presents:

```
═══════════════════════════════
  Harness — Visual Directions
═══════════════════════════════
3 directions generated. Open each HTML in a browser and click around.

Direction 1: <name>
  Philosophy: <name (流派) — one-line>
  Intent: <one-line intent>
  Sample: .harness/design/directions/direction-1.html

Direction 2: <name>
  Philosophy: <name (流派) — one-line>
  Intent: <one-line intent>
  Sample: .harness/design/directions/direction-2.html

Direction 3: <name>
  Philosophy: <name (流派) — one-line>
  Intent: <one-line intent>
  Sample: .harness/design/directions/direction-3.html

(Full summary at .harness/design/directions/directions-summary.md)

Reply with:
  • "I pick direction-1" (or 2 or 3) → proceed to hi-fi prototype
  • /harness:design reroll "<feedback>" → regenerate 3 with feedback
  • cancel → stop here
═══════════════════════════════
```

**Do NOT proceed until the user explicitly picks.** This is the human gate. Pick parsing is loose: accept `1`, `direction-1`, `I pick 1`, `picking direction 2`, etc. — extract the integer 1/2/3.

### Step 5: Re-dispatch Designer in EXPLORE mode (round 2: hi-fi)

After user picks direction N, the orchestrator dispatches the Designer again:

- **subagent_type**: `harness:designer`
- **description**: `"Hi-fi prototype for direction-<N>"`
- **prompt**: (passed verbatim):

> --- MODE: EXPLORE ---
> --- PICK: direction-<N> ---
>
> You are being re-dispatched in EXPLORE mode for the hi-fi prototype pass per your EXPLORE Step 8. Read `.harness/design/directions/direction-<N>.html` and `directions-summary.md` to recover the chosen direction's philosophy and intent. Construct a hi-fi huashu-design prompt. Invoke `Skill(huashu-design)`. Confirm Playwright validation ran. Write `.harness/design/prototype/prototype.html` (single self-contained HTML) and `.harness/design/prototype/prototype-notes.md`. Exit.
>
> Working directory contract: your cwd is the project root; never read or write `.worktrees/current/.harness/`.
>
> Original user intent:
> <intent string from arguments>

### Step 6: Present hi-fi prototype to user

After Designer returns, the orchestrator reads `.harness/design/prototype/prototype-notes.md` and presents:

```
═══════════════════════════════
  Harness — Hi-Fi Prototype
═══════════════════════════════
Direction: <chosen direction name>
Prototype: .harness/design/prototype/prototype.html
Notes:     .harness/design/prototype/prototype-notes.md

Screens covered: <list>
Interactions:    <one-line summary>
Declared gaps:   <count>
Validation:      <pass / pass-with-warnings / fail>

Open prototype.html in a browser to demo. When ready to build, run:
  /harness:sprint "<feature description>"
The sprint flow will read the prototype as design context.
═══════════════════════════════
```

Done.

---

## Subcommand: `reroll "<feedback>"`

Re-runs direction generation with user feedback as additional constraint. Requires a prior EXPLORE round to have written `directions-summary.md`.

### Step 1: Validate feedback + precondition

Strip the leading `reroll` token from `$ARGUMENTS`; the remainder is the feedback (strip surrounding quotes). If empty, tell the user:

> Feedback is required. Example: `/harness:design reroll "all three felt corporate, push more experimental"`. Run again with feedback.

…and exit.

Verify `.harness/design/directions/directions-summary.md` exists. If not, tell the user:

> No prior directions on file at `.harness/design/directions/directions-summary.md`. Run `/harness:design explore "<intent>"` first, then reroll if needed.

…and exit.

### Step 2: Dispatch Designer in REROLL mode

The orchestrator dispatches the Designer via the Agent tool:

- **subagent_type**: `harness:designer`
- **description**: `"Reroll directions with feedback"`
- **prompt**: (passed verbatim):

> --- MODE: REROLL ---
> --- FEEDBACK: <feedback text> ---
>
> You are being dispatched in REROLL mode. Read inputs per your REROLL Step 1 (same as EXPLORE plus prior `directions-summary.md`). Parse the FEEDBACK marker per your REROLL Step 2. Construct a feedback-injected huashu-design prompt per your REROLL Step 3. Invoke `Skill(huashu-design)`. Write 3 NEW differentiated HTML samples (avoiding prior round's philosophies) to `.harness/design/directions/direction-{1,2,3}.html` (overwriting prior) plus a new `directions-summary.md`. Halt at the user-pick gate.

### Step 3: Present + gate (same as explore Steps 4–6)

The user-pick UX after a REROLL is identical to after an EXPLORE round:

- Step 4 (Present): same panel as `explore` Step 4, with a header line noting this is a REROLL round and quoting the feedback that shaped it.
- Step 5 (Re-dispatch on pick): same as `explore` Step 5 (hi-fi pass).
- Step 6 (Present prototype): same as `explore` Step 6.

If the user is not satisfied with the REROLL round either, they can run `/harness:design reroll "<new feedback>"` again. There is no hard cap on reroll rounds in v1, but Designer's REROLL anti-patterns flag pure-vague feedback explicitly so the user gets a recommendation rather than infinite churn.

---

## Subcommand: `teach`

Implemented in Step 2 of v1. When teach lands, this subcommand will dispatch Designer in TEACH mode to apply chosen design tokens to existing source code via `impeccable`.

For now: tell the user

> `/harness:design teach` is implemented in Step 2 of the v1 design loop. Not yet available on this branch. Use `/harness:design explore` for visual direction work today.

…and exit.

---

## Subcommand: `audit`

Implemented in Step 3 of v1. When audit lands, this subcommand will dispatch Designer in AUDIT mode to review existing UI against `impeccable` principles and file findings.

For now: tell the user

> `/harness:design audit` is implemented in Step 3 of the v1 design loop. Not yet available on this branch.

…and exit.

---

## Subcommand: `extract`

Implemented in Step 4 of v1. When extract lands, this subcommand will dispatch Designer in EXTRACT mode to read a brownfield project's UI source and produce `extracted-tokens.md`.

For now: tell the user

> `/harness:design extract` is implemented in Step 4 of the v1 design loop. Not yet available on this branch. If you have a brownfield design language to honor, document it manually in `.harness/design/DESIGN.md` for now and the Designer will respect it during EXPLORE.

…and exit.

---

## Constraints

- The orchestrator does NOT edit `.harness/spec/*`, `.harness/features/*`, `.harness/evaluator/*`, `.harness/progress/*`, or any source code under `src/`, `app/`, etc. ALL design writes are via the Designer subagent into `.harness/design/`.
- The orchestrator does NOT call `huashu-design` or `impeccable` directly — the Designer subagent owns those Skill invocations. The orchestrator's job is dispatch + human-gate UX + re-dispatch.
- The orchestrator does NOT dispatch Planner / Generator / Evaluator from `/harness:design`. Design is a separate axis from build; cross-axis interaction happens at the user's discretion (the user runs `/harness:sprint` after the design loop completes if they want to build).
- The orchestrator does NOT auto-progress past human gates. The user-pick gate after EXPLORE/REROLL Step 4 is the only place humans steer the design loop; respect it.

---

## Usage block (shown when `$ARGUMENTS` is empty or unrecognised)

```
═══════════════════════════════
  /harness:design — Subcommands
═══════════════════════════════
explore "<intent>"   Generate 3 visual directions, pick, then hi-fi prototype.
                     Example: /harness:design explore "Modern SaaS dashboard"

reroll "<feedback>"  Regenerate 3 directions with feedback. Requires a prior
                     explore round on file.
                     Example: /harness:design reroll "all three felt corporate"

teach                Apply chosen tokens to source.    [Step 2 — not yet shipped]
audit                Review existing UI vs impeccable. [Step 3 — not yet shipped]
extract              Extract tokens from brownfield.   [Step 4 — not yet shipped]

All design artifacts land under .harness/design/. Source code is never touched.
═══════════════════════════════
```
