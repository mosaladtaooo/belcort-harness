---
description: Targeted modification of an existing spec file with downstream reference updates (BMAD tri-modal). Example — change DB stack, edit propagates to architecture, init.sh, and NFRs.
argument-hint: "<what to change>"
---

# `/harness:edit` — Targeted spec edit

For when you want to modify a specific part of the spec without regenerating everything. Requested change: `$ARGUMENTS`. If empty, ask the user what they want to change.

## Procedure

1. Read the user's requested change
2. Identify which files are affected (prd.md? architecture.md? contract?)
3. Apply the change surgically — only modify the affected sections
4. Update downstream references:
   - If a FR changed → update the architecture traceability table
   - If architecture changed → update the contract build order
   - If an AC changed → update the evaluator criteria
5. Re-run validation on modified files only
6. Report what changed and what downstream updates were made

**Example:** `/harness:edit "Change the database from SQLite to PostgreSQL"`
→ Updates architecture.md stack table + component details
→ Updates init.sh for PostgreSQL setup
→ Updates NFRs if performance targets change
→ Contract stays the same (FRs didn't change)
→ Logs the change in decisions.md as an ADR
