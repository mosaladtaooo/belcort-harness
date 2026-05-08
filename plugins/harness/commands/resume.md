---
description: Continue an interrupted harness pipeline from the last checkpoint. Reads manifest.yaml + changelog + git log, then dispatches the appropriate subagent for the current phase.
---

# `/harness:resume`

**Invoke from project root, not from `.worktrees/current/`** (v2.1.8). `/harness:resume` reads `.harness/manifest.yaml` to determine current phase. If invoked from inside `.worktrees/current/`, it would read the stale frozen snapshot copy at `.worktrees/current/.harness/manifest.yaml` and misidentify the pipeline state. See SKILL.md § File Ownership Contract → Working directory and `.harness/` location.

Run the Recovery procedure documented in the harness skill: see SKILL.md § Recovery.

The procedure:
1. Reads `.harness/manifest.yaml`, `.harness/progress/changelog.md`, and `git log --oneline | grep 'harness:'`.
2. Runs `bash .harness/init.sh` (creating it from `@templates/init.sh.txt` if missing, then `chmod +x`).
3. Prints a status report (project, feature, phase, current_task, retries, recent commits, recent changelog entries).
4. Dispatches the correct subagent based on current phase — see SKILL.md § Recovery step 4 for the full phase-by-phase decision table.

If state files disagree (e.g., git says FR-005 committed but changelog says FR-003 was last), the orchestrator prints the conflict and asks the user which source to trust. Never silently proceeds with conflicting state.
