---
description: Resume an interrupted harness pipeline from the last checkpoint (reads .harness/manifest.yaml and changelog.md to recover state).
---

# `/harness:resume`

Invoke the BELCORT Harness skill and execute the **`/harness:resume`** procedure.

Read `skills/harness/SKILL.md` and follow the `/harness:resume` section. In order:

1. Read `.harness/manifest.yaml` — identify `state.phase`, `current_feature`, `current_task`, `retry_count`, `negotiation_round`
2. Read `.harness/progress/changelog.md` tail for last actions
3. Read the current feature's folder (`.harness/features/NNN-name/`) to see which artifacts exist
4. Print recovery summary to the user and wait for confirmation before continuing
5. Resume from the identified phase (planning, analyzing, negotiating, building, evaluating, retrospective)

If no `.harness/manifest.yaml` exists in this directory, tell the user there's no active harness here and suggest `/harness:sprint` to start one.
