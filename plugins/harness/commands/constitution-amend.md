---
description: High-ceremony constitution amendment (FR-6). Constitution is immutable post-init by default — this command is the ONE authorized path. Requires typed confirmation, ≥50-char reason, in-progress feature handling, mandatory ADR, AND a re-validation pass against every completed feature.
argument-hint: "<reason for the amendment, ≥50 chars>"
---

# `/harness:constitution-amend` — High-ceremony constitution change

The constitution (`spec/constitution.md`) is the architectural DNA of the project. The default is `immutable post-init` because casual amendments cascade into drift across every shipped feature. This command is the ONE authorized path. The friction IS the feature.

## The five ceremony gates

1. **≥50-char reason** — becomes the ADR.
2. **Typed confirmation** — deliberate intent.
3. **In-progress handling** — surfaces the cost (current feature halts or ships under old rules).
4. **Re-validation** against every completed feature — catches past-work non-compliance.
5. **Final apply confirmation** — last chance to back out.

A mandatory ADR and an amendments log complete the audit trail.

## Procedure

### Step 1: Gates 1 + 2 — reason length, typed confirmation

Orchestrator examines `$ARGUMENTS`. If under 50 characters, reject with "Amendment reason must be ≥50 chars — explain WHY, not just WHAT" and exit. Otherwise, print the ceremony banner + the reason, then ask the user to type EXACTLY `I-AM-AMENDING-THE-CONSTITUTION`. On mismatch, abort.

### Step 2: Gate 3 — in-progress feature handling

Orchestrator reads `.harness/manifest.yaml`. If `features.in_progress` is non-empty (`${IN_PROGRESS}`), present three choices:

1. Finish `${IN_PROGRESS}` under the OLD constitution, then amend + re-validate (recommended).
2. Halt now, amend + re-validate, restart feature against the NEW constitution.
3. Abandon the amendment.

On `1` or `3`: exit with appropriate message. On `2`: require a second typed confirmation `PROCEED-ANYWAY` before continuing.

### Step 3: Dispatch Planner in CONSTITUTION-AMEND mode

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Amend constitution: <short summary of $ARGUMENTS>"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in CONSTITUTION-AMEND mode. Read .harness/spec/constitution.md, prd.md, architecture.md, and (via Read tool) sampled completed features' contract.md files.
>
> Amendment reason from user:
> $ARGUMENTS
>
> Produce structured patches to .harness/constitution-amend-patches.md per your CONSTITUTION-AMEND mode procedure. Do NOT apply. Do NOT renumber principles (§-numbers are stable references).

### Step 4: Present patches + conflict check

Orchestrator reads `.harness/constitution-amend-patches.md` and shows:

```
═══════════════════════════════
  Harness — Constitution Amendment Preview
═══════════════════════════════
Reason: ${ARGUMENTS}
Planner's interpretation: [1-3 sentence summary]
Principle amended: §N — [added | changed | removed]
Impact: affects principles [§s], completed [N features]
Conflicts flagged: [list or "none"]
Patches (no §-renumbering): [1] spec/constitution.md § N — [summary]

Proceed to re-validation / Cancel?
```

On cancel: exit; patches remain on disk.

### Step 5: Apply patches to a TEMP proposed file

Orchestrator copies `.harness/spec/constitution.md` to `.harness/spec/constitution.md.proposed` and applies the patches to the TEMP via `Edit` tool. Revalidation runs against the proposed state; the real constitution stays untouched until Step 10.

### Step 6: Analyze the NEW constitution against the current spec

REVALIDATE (Step 7) checks the new constitution against previously-shipped features. It does NOT check the new constitution against the CURRENT `prd.md` / `architecture.md` / in-progress `contract.md`. That's this step's job. If the new principle implicitly invalidates part of the current spec (e.g., new principle "all user data MUST be server-side only" contradicts an existing FR "user preferences stored in localStorage"), this gate catches it before the amendment ships.

Procedure:

1. Orchestrator runs `/harness:analyze` with an override: instead of reading `.harness/spec/constitution.md`, it reads `.harness/spec/constitution.md.proposed` (the Step-5 TEMP). All other spec files (prd.md, architecture.md, current feature's contract.md if any, evaluator/criteria.md) are read as-is.
2. Analyze produces `.harness/features/${FEATURE:-_global}/analysis-report.md` with findings.
3. Review findings:
   - **No CRITICAL findings** → proceed to Step 7.
   - **CRITICAL findings** → the proposed constitution contradicts the current spec. Present findings to user with three options:
     - **Revise amendment** — abort now, user narrows the amendment reason and re-runs `/harness:constitution-amend`.
     - **Edit current spec first** — user runs `/harness:edit` to bring prd.md/architecture.md into compliance with the proposed constitution, then re-runs this command.
     - **Proceed anyway** — accept the contradiction knowingly (rare — typed confirmation `CONTRADICTION-ACKNOWLEDGED` required); the contradiction gets flagged in the final ADR as a known debt.

Why this comes before REVALIDATE: catching contradictions with the current spec is cheaper (no subagent dispatches per feature) and usually resolves by narrowing the amendment, which avoids expensive revalidation work that would have been wasted.

### Step 7: Gate 4 — re-validation per completed feature

Orchestrator reads `features.completed[]` (sample up to 10 most recent). Picks timestamp `${TS}` (YYYYMMDDHHMMSS); output goes to `.harness/.revalidation-${TS}/`. For EACH sampled feature `${FEATURE_N}`, the orchestrator dispatches the Evaluator via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Revalidate ${FEATURE_N} vs proposed constitution"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in REVALIDATE mode for a constitution amendment.
>
> Audit the completed feature ${FEATURE_N} against the proposed new constitution. Per-principle compliance report: PASS / FAIL / N/A with audit method + finding. Do NOT run Playwright — static audit only. Write to .harness/.revalidation-${TS}/${FEATURE_N}.md.

The Evaluator reads `.harness/spec/constitution.md.proposed`, the feature's contract + eval-report + source.

### Step 8: Summarise revalidation, collect per-feature decisions

After all revalidation subagents return, orchestrator reads each per-feature report and summarises:

```
Completed features evaluated: [N]
  PASS — FEATURE-001 — fully compliant
  WARN — FEATURE-002 — 1 principle FAIL: [§N]
  FAIL — FEATURE-003 — 3 principle FAILs: [list]
Totals: compliant [N] / backport [N] / grandfather [N]

For each non-compliant feature:
  - Backport     → adds task to ROADMAP.md under "Constitutional debt"
  - Grandfather  → adds explicit exception to progress/decisions.md
Per-feature decision (1=backport, 2=grandfather, 3=re-evaluate):
```

Collect decisions. Choice `3` re-runs Step 7 (REVALIDATE dispatch) for that feature only.

### Step 9: Gate 5 — final apply confirmation

Orchestrator presents the full apply summary and requires `APPLY-AMENDMENT` typed confirmation. On mismatch, exit (patches + proposed temp file retained for recovery).

### Step 10: Apply, wire backports/grandfathers, log everything

Orchestrator applies each patch from `constitution-amend-patches.md` to `.harness/spec/constitution.md` via `Edit` (mechanical — Planner authored the strings). Then via `Edit` tool:

- **Per backport feature** → append a task to `ROADMAP.md` under `Constitutional debt` (feature + failing principle(s)).
- **Per grandfather feature** → append a follow-up ADR to `progress/decisions.md` documenting the exception.
- **manifest.yaml** → append under `constitution.amendments` an entry with `date`, `reason`, `principles_affected`, `adr`, `revalidation_dir`, `backport_needed[]`, `grandfathered[]`.
- **progress/decisions.md** → append the mandatory parent ADR (title, date, Accepted status, Context = `${ARGUMENTS}`, Decision = principle §N added/changed/removed with before/after quotes, Consequences = future features build against new constitution, revalidation dir, backport tasks added, grandfathered list, in-progress policy chosen at gate 3).
- **progress/changelog.md** → append `## YYYY-MM-DD — Global — Constitution amended` with reason/ADR/principles/re-validation totals.

Finally delete `.harness/spec/constitution.md.proposed` and the per-feature analysis-report.md if it was written to `_global`.

## Anti-patterns

- **Ceremony as obstacle**: the ceremony IS the feature. Annoyance signals you may be amending too casually.
- **Skipping re-validation** "because the change is small": even a small principle change can invalidate past features.
- **Grandfathering everything** to dodge backport work: routine grandfathering hollows out the constitution.
- **Amending to match what was already built**: that's a retrospective concern. Use `/harness:retrospective` first.
- **Loosening principles casually**: loosening should require a higher bar of justification.

## Files written

| File | Writer |
|---|---|
| `.harness/constitution-amend-patches.md` | Planner CONSTITUTION-AMEND mode |
| `.harness/spec/constitution.md.proposed` | Orchestrator TEMP copy (deleted at Step 10) |
| `.harness/features/${FEATURE:-_global}/analysis-report.md` | Orchestrator (Step 6 — new-constitution vs current-spec analyze) |
| `.harness/.revalidation-${TS}/${FEATURE}.md` | Evaluator REVALIDATE mode (one per sampled feature) |
| `spec/constitution.md` | Orchestrator applies patches (Step 10) |
| `ROADMAP.md` | Orchestrator appends backport tasks |
| `manifest.yaml → constitution.amendments` | Orchestrator appends entry |
| `progress/decisions.md` | Orchestrator appends ADR + per-feature follow-ups |
| `progress/changelog.md` | Orchestrator appends |

This command is the authorized SECOND writer of `spec/constitution.md` — the original Planner Pass 1 is the only other writer per SKILL.md File Ownership Contract. The write-blocking hook recognises this command by the active phase marker.
