---
description: Post-merge drift analysis — diffs what was specified vs what was built, proposes spec updates to reflect reality.
---

# `/harness:retrospective`

Invoke the BELCORT Harness skill and execute the **`/harness:retrospective`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:retrospective` section. In order:

1. Read all artifacts under `.harness/features/<current>/` (contract, proposal, review, implementation-report, eval-report)
2. Read the source code that was actually shipped
3. Identify drift:
   - **Positive drift**: Generator shipped beyond spec (extra FR, NFR improvement) → propose adding to spec
   - **Negative drift**: Generator skipped spec deliverable → mark as known-issue or update contract
   - **Neutral drift**: implementation chose a path the spec left open → document in decisions.md
4. Write `.harness/features/<current>/retrospective.md`
5. Propose spec updates to the user — wait for approval before applying
6. Append decisions to `.harness/progress/decisions.md`

If run standalone, use the last completed feature from `manifest.features.completed[-1]`, or ask the user which feature to retrospect.
