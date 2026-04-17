---
description: Targeted modification of an existing spec file with downstream reference updates (e.g., change a constitution rule and propagate implications to affected contracts).
argument-hint: "<what to change>"
---

# `/harness:edit`

Invoke the BELCORT Harness skill and execute the **`/harness:edit`** procedure with the requested change: `$ARGUMENTS`

Read `skills/harness/SKILL.md` and follow the `/harness:edit "<change>"` section. In order:

1. Parse the user's change request — identify which spec file(s) are primary targets
2. Locate and read the target file(s)
3. Propose the specific edit to the user — wait for approval
4. Apply the edit
5. Scan for downstream references (other spec files, feature contracts) that the change affects
6. Propose downstream updates — wait for approval per group
7. Append an entry to `.harness/progress/decisions.md` documenting the change

If `$ARGUMENTS` is empty, ask the user what they want to change.
