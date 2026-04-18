---
description: Post-merge drift analysis & spec sync — diffs what was specified vs what was built, proposes spec updates, keeps PRD and architecture in sync with reality across sprints.
---

# `/harness:retrospective` — Post-merge drift analysis & spec sync

Runs AFTER the Evaluator returns PASS and BEFORE the final merge + archive. Reconciles what was actually built against what the spec said would be built. Keeps the PRD and architecture in sync with reality over multiple sprints.

**When it runs automatically:**
In the full [sprint.md](sprint.md) flow, `/harness:retrospective` runs automatically after Evaluator PASS, before the ROADMAP update.

## Why it matters

Over many features, specs drift. The Generator might add a helper not mentioned in architecture. An AC might be satisfied differently than specified. The PRD might describe an out-of-scope flow that got built anyway. Without periodic reconciliation, the spec becomes fiction and future features build on lies.

## Procedure

1. Read the completed feature's artifacts:
   - `.harness/features/{current-feature}/contract.md` (what was planned)
   - `.harness/features/{current-feature}/implementation-report.md` (what Generator says was built)
   - `.harness/features/{current-feature}/eval-report.md` (PASS — what was verified)
2. Scan the source code to identify what actually exists
3. Identify drift in three categories:
   - **Positive drift**: implementation is better than spec'd (new helpers, better structure). Propose adding to spec.
   - **Negative drift**: implementation is worse than spec'd (shortcuts, stubs that passed eval anyway). Propose tightening spec or adding to known-issues.
   - **Neutral drift**: different path to same outcome. Propose updating architecture to reflect reality.
4. Write findings to `.harness/features/{current-feature}/retrospective.md`:
   ```
   ═══════════════════════════════
     Harness — Retrospective
   ═══════════════════════════════
   Feature: {current-feature}
   Spec adherence: [score]/10

   Positive drift (consider adding to spec):
     - [new component in src/lib/validator.ts — not in architecture]
     - [additional AC satisfied beyond contract: fuzzy search for tags]

   Negative drift (consider tightening spec):
     - [FR-003 technically passed but edge case EC-003-2 is handled by a stub]

   Neutral drift (update architecture to reflect reality):
     - [Planner said "Redis for caching" but implementation uses in-memory Map]

   Proposed spec updates:
     - [specific change 1 with file + section]
     - [specific change 2 with file + section]
   ═══════════════════════════════
   ```
5. **Present to human** — drift proposals require human approval before applying
6. On approval: apply the updates to `spec/prd.md`, `spec/architecture.md`, log each change as an ADR in `progress/decisions.md`
7. Update `ROADMAP.md`:
   - Move the feature from "🚧 In Progress" to "✅ Shipped"
   - Add scores, retry count, merge date
   - If retrospective revealed new feature ideas, add them to "💭 Considered"
8. Update `manifest.yaml`:
   - `features.completed`: append the feature folder name
   - `features.in_progress`: empty
   - `state.phase`: "complete"

**On decline:** retrospective findings stay in `retrospective.md` as a record but specs aren't modified. User can revisit later.

If run standalone, use the last completed feature from `manifest.features.completed[-1]`, or ask the user which feature to retrospect.
