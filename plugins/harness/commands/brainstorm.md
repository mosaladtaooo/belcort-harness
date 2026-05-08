---
description: Pre-plan exploration for vague/ambiguous requests (Superpowers-inspired). Interviews the user, surfaces silent assumptions, explores alternatives, writes .harness/brainstorm-current.md so the subsequent /harness:sprint has a concrete prompt. Use when the request is <2 sentences, mentions "maybe"/"not sure"/"help me figure out", or touches an unfamiliar problem space.
argument-hint: "<vague idea or half-formed request, 1–3 sentences>"
---

# `/harness:brainstorm` — Pre-plan exploration

Runs BEFORE the planner, for requests where the user's idea isn't ready to hand to the Planner yet. The Planner assumes it's been given a tractable prompt; brainstorm makes sure that's true. Adapted from the Superpowers "brainstorming-is-mandatory" pattern, tuned for cases where it's actually needed rather than as a universal gate.

## When to invoke

**Good fits:**
- User prompt is ≤ 2 sentences or uses uncertainty words ("maybe", "not sure", "I think", "figure out")
- Unfamiliar problem space (first feature in a new domain, novel integration)
- User is exploring options before committing to one
- Multiple reasonable interpretations of the request exist
- Adjacent decisions (tech stack, target platform, scope) are unresolved

**Bad fits (skip brainstorm, go straight to `/harness:sprint`):**
- User has already written a detailed prompt
- Follow-up feature in an established codebase (constitution + architecture already pin most choices)
- Bug fixes, small enhancements, clear single-deliverable work
- User explicitly says "I know what I want, just build X"

**Auto-suggest rule**: if the user invokes `/harness:sprint` with a prompt matching any "good fit" criterion above, the orchestrator proposes `/harness:brainstorm` first. User can override by saying "no, proceed".

## What brainstorm does NOT do

- Write specs (that's the Planner's job)
- Commit to a tech stack
- Produce acceptance criteria
- Create a feature folder (that happens during `/harness:sprint`)

It produces ONE file: `.harness/brainstorm-current.md`. The next `/harness:sprint` reads it as additional context and deletes it after the feature folder is created.

## Procedure

### Step 1: Read the prompt

```bash
IDEA="$ARGUMENTS"
[ -z "$IDEA" ] && { echo "Usage: /harness:brainstorm \"<your idea>\""; exit 1; }
```

### Step 2: Conduct a structured interview

Run through these categories IN ORDER, asking the user 1-3 questions per category via `AskUserQuestions`. You are NOT the Planner — do not try to produce a spec. You are a thinking partner trying to surface the assumptions the Planner would otherwise silently make.

**Category A — Who is this for?**
- Who's the primary user? What's their context?
- Is there a secondary user or stakeholder?
- What changes about their life when this works?

**Category B — What problem does it solve?**
- What happens today without this? (reveals whether the problem is real)
- Who else has solved this? What did they build?
- What's the 1-sentence elevator pitch?

**Category C — Scope signals**
- What would the smallest useful version look like? (not MVP — *useful*)
- What's explicitly OUT of scope for v1?
- What's the hardest part, intuitively?

**Category D — Constraints you can't wish away**
- Budget/time hard limits?
- Compliance / legal / data-sovereignty requirements?
- Existing systems to integrate with?
- Must-have tech choices (e.g., "team knows Python")?

**Category E — Directions to rule out**
- What's the most obvious approach you want to explicitly REJECT?
- What pattern, if you saw it in the result, would tell you it went wrong?

Don't push through all 5 categories if the user has already answered something upstream — skip to the next unexplored category. Target 8-12 questions total. More is annoying; fewer leaves silent assumptions.

### Step 3: Synthesize

After the interview, produce `.harness/brainstorm-current.md`:

```markdown
# Brainstorm — <short title derived from idea>

**Date**: [ISO date]
**Original prompt**: <verbatim user input>

## Summary

<2-3 sentences — the refined version of the idea, ready for the Planner>

## Personas (draft)

- **<name>**: <role, context, what they want>
- (optional secondary)

## Problem statement (draft)

<1 paragraph: what problem, what happens today, why now>

## Scope signals

- **Smallest useful version**: <user's answer>
- **Out of v1**: <list>
- **Hardest part (user's intuition)**: <answer>

## Constraints

- <each constraint, verbatim or paraphrased>

## Rejected directions

- **<approach>** — rejected because <reason>
- (add as many as surfaced)

## Open questions for the Planner

Things the interview raised that still don't have a clear answer. The Planner's Pass 1 should pick these up via `AskUserQuestions` or `/harness:clarify`:

- <question>
- <question>

## Suggested next step

Run: `/harness:sprint "<refined 2-3 sentence prompt synthesizing the above>"`
```

### Step 4: Show the user, confirm

Print the full brainstorm-current.md to the user. Ask:

> "Does this capture your intent? Options:
>   1. Yes — proceed to /harness:sprint with the refined prompt above
>   2. Edit — what's wrong, and I'll rewrite the relevant section
>   3. Abandon — delete the brainstorm file, don't continue"

On (1): print the suggested `/harness:sprint` invocation ready to copy. Do not auto-run sprint — the user should see the refined prompt before committing.

On (2): ask what needs changing, revise, re-show. Max 2 edit cycles then push back to the user ("if the idea still isn't gelling, it may need more thought offline — the brainstorm file is saved, you can revisit").

On (3): `rm .harness/brainstorm-current.md`, exit silently.

### Step 5: Integration with /harness:sprint

`/harness:sprint` automatically reads `.harness/brainstorm-current.md` if present, passes its contents as additional context to the Planner in PLAN mode (appended after the user's prompt under `--- BRAINSTORM CONTEXT ---`), then moves the file to `.harness/features/NNN-<feature>/brainstorm.md` when the feature folder is created.

If no brainstorm file exists, sprint proceeds normally.

## Anti-patterns

- **Turning brainstorm into Planner-lite**: you're not producing a PRD. Categories A–E are the ceiling. If you catch yourself writing acceptance criteria or picking a framework, stop — that's the Planner's job.
- **Skipping the interview and inferring**: the whole point is to surface user-side assumptions. Silent inference defeats it.
- **>15 questions in one session**: interview fatigue produces bad data. Fewer, sharper questions beat an interrogation.
- **Running on clear prompts**: brainstorm has overhead; a 4-sentence prompt with concrete verbs doesn't need it. Use judgment.

## Files written

| File | Lifetime |
|------|----------|
| `.harness/brainstorm-current.md` | Until next `/harness:sprint` runs, then moved to feature folder as `brainstorm.md` |
