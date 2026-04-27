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
mkdir -p .harness/design/audits
```

This is idempotent. If `.harness/` itself doesn't exist (the harness has never been initialized in this project), tell the user "No `.harness/` in this project. Run `/harness:setup` first to initialize the harness." and exit. The Designer can run on a project that hasn't gone through `/harness:sprint` yet (you can explore design before specifying anything), but it does need `.harness/` to write into.

### Step 1: Route to subcommand

Route on the first token of `$ARGUMENTS`:

- `explore "<intent>"` → § Subcommand: explore
- `reroll "<feedback>"` → § Subcommand: reroll
- `teach` → § Subcommand: teach
- `audit` → § Subcommand: audit (full implementation; user-invoked, presentational only)
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

Codifies the validated hi-fi prototype's design language into a reusable `.harness/design/DESIGN.md` artifact. The Planner reads this on subsequent `/harness:sprint` runs to ground its PRD/architecture; the Generator reads it during BUILD to apply tokens to UI components. Single-shot, no human gate (impeccable does the heavy lifting).

### Step 1: Pre-checks

Verify the prototype exists. The Designer cannot codify a design language from nothing:

- If `.harness/design/prototype/prototype.html` does NOT exist, abort with:
  > `/harness:design teach` requires a hi-fi prototype. Run `/harness:design explore "<intent>"` first to generate one.
- If `.harness/design/prototype/prototype-notes.md` does NOT exist, abort with the same message — the prototype-notes file carries the interaction map the Designer needs alongside the visual artifact.

Note (do NOT abort) whether `.harness/design/DESIGN.md` already exists. If it does, this is a re-teach — pass the fact to Designer in the dispatch prompt so it merges rather than overwriting blindly.

### Step 2: Dispatch Designer in TEACH mode

The orchestrator dispatches the Designer via the Agent tool:

- **subagent_type**: `harness:designer`
- **description**: `"TEACH: codify design system from prototype"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> --- MODE: TEACH ---
>
> You are being dispatched in TEACH mode. {{INITIAL_OR_RETEACH_NOTE}}
>
> Working directory contract: your cwd is the project root; never read or write `.worktrees/current/.harness/`.
>
> Read the prototype + prototype-notes per your TEACH Step 1 (`.harness/design/prototype/prototype.html`, `.harness/design/prototype/prototype-notes.md`). Read optional inputs per Step 2 (`.harness/spec/constitution.md`, `.harness/design/extraction/extracted-tokens.md`, prior `.harness/design/DESIGN.md` if re-teach). Construct an impeccable teach prompt per Step 3. Invoke `Skill(impeccable)`. Capture the DESIGN.md content, verify it's ≥2KB and contains the harness-required sections, scan for constitution conflicts. Write `.harness/design/DESIGN.md` per Step 7 (with the Designer header comment block prepended). See your system prompt for the full TEACH procedure.

`{{INITIAL_OR_RETEACH_NOTE}}` is replaced by the orchestrator with one of:
- `"This is the initial teach (no prior DESIGN.md on file)."` if `.harness/design/DESIGN.md` did not exist.
- `"This is a re-teach — prior DESIGN.md exists at .harness/design/DESIGN.md. Merge updates surgically rather than overwriting blindly per K3."` if it did.

### Step 3: After dispatch returns

The Designer subagent writes `.harness/design/DESIGN.md` and exits. The orchestrator:

1. Verifies the file exists and is ≥2KB. If not, surface the failure to the user verbatim (Designer's exit message will explain).
2. Reads the first ~30 lines of DESIGN.md (e.g., `head -30 .harness/design/DESIGN.md` via Bash, or Read with limit=30).
3. Presents to the user:

```
═══════════════════════════════
  Harness — Design Codified
═══════════════════════════════
DESIGN.md written: .harness/design/DESIGN.md
Size: <N> bytes
Sections: ✓ Design Tokens, ✓ Principles, ✓ Anti-patterns, ✓ Motion, ✓ Accessibility
Constitution conflicts: <none | N flagged in ## Constitution Conflicts section>

--- First 30 lines ---
<excerpt>
--- End excerpt ---

Review the full file. If you want to change specific sections, run:
  /harness:edit DESIGN.md
…or just edit the file directly. The next /harness:sprint will pick it up
automatically — Planner reads DESIGN.md as design context, Generator reads
it during BUILD.
═══════════════════════════════
```

If the Designer exited with a `## Constitution Conflicts` warning, replace the success header with a yellow-flag header and surface the conflict count + conflict summaries to the user so they can decide whether to reconcile before the next sprint.

Done.

---

## Subcommand: `audit`

Runs impeccable's 5-dimension design audit against the built application or the validated prototype, cross-checks every finding against `.harness/spec/constitution.md`, and produces a P0–P3 punch list at `.harness/design/audits/audit-<feature-id>-<n>.md`. Useful for: re-auditing without rebuilding, auditing the prototype before any sprint runs, ad-hoc design checks. The user-invoked variant is presentational only — it does NOT auto-loop on P0 (that auto-loop is sprint.md's job after Evaluator PASS). User-invoked audits report findings to the user; the user decides what to do.

The full AUDIT procedure lives in the Designer's system prompt. The orchestrator's job is dispatch + present-after-return.

### Step 1: Pre-checks

Verify at least one criterion file exists, plus one audit target. The Designer cannot audit without something to grade against AND something to grade.

Criterion files (need at least ONE):
- `.harness/design/DESIGN.md` — project-specific design system. Without it the audit grades against impeccable's generic baseline.
- `.harness/design/prototype/prototype.html` — visual contract from `/harness:design explore`. Implicitly carries criteria.

If NEITHER exists, abort with:
> `/harness:design audit` requires either a `DESIGN.md` (run `/harness:design teach` first) or a prototype (run `/harness:design explore` first). Neither found in `.harness/design/`.

Constitution file (REQUIRED — the floor):
- `.harness/spec/constitution.md` — the constitutional floor. AUDIT promotes constitution-clause violations to P0 regardless of impeccable's score.

If `.harness/spec/constitution.md` does NOT exist, abort with:
> `/harness:design audit` requires `.harness/spec/constitution.md` (the constitutional floor). Run `/harness:setup` first.

### Step 2: Determine target

Parse the rest of `$ARGUMENTS` (everything after the leading `audit` token) for a target hint:

- `--target build` (or `--target=build`) → audit the built app. Verify `.harness/init.sh` exists; if not, abort with: *"--target build requested but no `.harness/init.sh` found. Run `/harness:sprint` first to build a feature."*
- `--target prototype` (or `--target=prototype`) → audit the prototype. Verify `.harness/design/prototype/prototype.html` exists; if not, abort with: *"--target prototype requested but no prototype on file. Run `/harness:design explore` first."*
- No `--target` flag → default rule:
  - If a feature has been built — read `.harness/manifest.yaml`, look for `state.phase = "complete"` AND `.harness/init.sh` exists — default to `build`.
  - Otherwise default to `prototype`.

Capture the chosen target as `${AUDIT_TARGET}` (either a URL placeholder or the prototype path) and the rationale (`build (feature complete in manifest)` / `prototype (no build yet)` / `build (--target build)` / `prototype (--target prototype)`) for the dispatch prompt.

### Step 3: Dispatch Designer in AUDIT mode

The orchestrator dispatches the Designer via the Agent tool:

- **subagent_type**: `harness:designer`
- **description**: `"AUDIT: 5-dim design audit + constitution cross-check"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> --- MODE: AUDIT ---
> --- AUDIT TARGET: ${AUDIT_TARGET} ---
>
> You are being dispatched in AUDIT mode by `/harness:design audit` (user-invoked, presentational — no auto-loop on P0). Run impeccable's 5-dimension audit against the target above. Cross-check every finding against `.harness/spec/constitution.md` — constitution-clause violations are auto-promoted to P0 with a `(constitution §N)` tag.
>
> Working directory contract: your cwd is the project root; never read or write `.worktrees/current/.harness/`.
>
> Read inputs per your AUDIT Step 1–2 (target identification + criteria). Construct the impeccable audit prompt per Step 3. Invoke `Skill(impeccable)`. Map output to BELCORT P0–P3 per Step 5. Run constitution cross-check per Step 6. Write the audit report to `.harness/design/audits/audit-<feature-id>-<n>.md` per Step 7. Self-validate per Step 8. Print the parseable exit-message line per Step 9. See your system prompt for the full AUDIT procedure.
>
> Target rationale: ${AUDIT_RATIONALE}

Where `${AUDIT_TARGET}` is either the URL the orchestrator expects `bash .harness/init.sh` to expose (or `<URL from init.sh>` as a placeholder for the Designer to resolve) OR the absolute path to `prototype.html`, and `${AUDIT_RATIONALE}` is the one-line "why this target" string from Step 2.

### Step 4: After dispatch returns

The Designer subagent writes the audit report and prints a parseable exit line. The orchestrator:

1. Parses Designer's stdout for the `AUDIT complete. Verdict: ...` line. Capture P0/P1/P2/P3 counts and the report path.
2. Verifies the audit file exists at the reported path. If not, surface the failure to the user verbatim — the Designer's exit message will explain what went wrong.
3. Reads the P0 section of the audit report (e.g., `head -30` of the `## Punch List` → `### P0` block via Bash, or use Read with limit) for the excerpt below.
4. Presents to the user:

```
═══════════════════════════════
  Harness — Design Audit
═══════════════════════════════
Target: <URL or prototype.html path>
Rationale: <build / prototype / overridden via --target>
Verdict: <PASS | FAIL>

P0 (must fix):  <count>
P1 (should fix): <count>
P2 (nice-to-fix): <count>
P3 (polish):     <count>

Constitution violations: <count> (each promoted to P0)

Report: .harness/design/audits/audit-<feature-id>-<n>.md

--- P0 excerpt (first 30 lines of the P0 punch list) ---
<excerpt>
--- End excerpt ---

This is a user-invoked audit (presentational only — no auto-loop).
If you want findings fixed, run /harness:sprint or /harness:resume — the
sprint flow's auto-audit-gate will re-dispatch BUILD when P0 findings
exist (capped at 2 retries).
═══════════════════════════════
```

If verdict is PASS (no P0), replace the excerpt block with `_No P0 findings — design audit passed._` and the closing line with the simpler "Review the report for P1+ findings if any." Done.

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
- `teach`: Designer writes only `.harness/design/DESIGN.md`. Does NOT touch source code, spec files, or any path outside `.harness/design/`. PRODUCT.md is intentionally deferred — if impeccable's teach flow tries to leak a PRODUCT.md to project root, the Designer removes it.
- `audit` subcommand: Designer writes only `.harness/design/audits/audit-<feature-id>-<n>.md`. NEVER touches source code, spec files, or anything outside `.harness/design/audits/`. The user-invoked variant is presentational — it does NOT auto-loop on P0 (that auto-loop lives in `/harness:sprint`'s post-Evaluator-PASS path); the user-invoked variant just reports findings.

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

teach                Codify prototype into .harness/design/DESIGN.md (tokens +
                     principles + anti-patterns + motion + accessibility) so
                     /harness:sprint can ground specs in the design language.
                     Requires a prior explore round.

audit [--target build|prototype]
                     Run impeccable's 5-dim audit (Accessibility / Performance
                     / Theming / Responsive / Anti-Patterns) on the built app
                     or prototype, cross-check constitution, write a P0–P3
                     punch list to .harness/design/audits/. User-invoked:
                     presentational, no auto-loop. /harness:sprint runs the
                     same audit automatically after Evaluator PASS and loops
                     BUILD on P0 (capped at 2 retries).
                     Examples:
                       /harness:design audit
                       /harness:design audit --target prototype

extract              Extract tokens from brownfield.   [Step 4 — not yet shipped]

All design artifacts land under .harness/design/. Source code is never touched.
═══════════════════════════════
```
