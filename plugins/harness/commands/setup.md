---
description: Initialize BELCORT Harness in the current project. Creates .harness/ with templates and installs project-local activation rules into ./CLAUDE.md. Idempotent; safe to re-run.
---

# `/harness:setup`

One-time per-project installer. Scaffolds `.harness/` from the bundled templates and writes a project-local `./CLAUDE.md` with the harness activation rules.

As of v2.0.0, installation is PROJECT-LOCAL. There is no longer a global `~/.claude/CLAUDE.md` write. This keeps harness-specific context out of unrelated projects.

## Procedure

### Step 1: Run the setup script

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
```

The script:
1. Creates `.harness/` with `spec/`, `evaluator/`, `features/`, `progress/` subdirectories.
2. Copies baseline templates (manifest, ROADMAP, progress files, evaluator criteria + examples + tuning-log) into `.harness/`. Never overwrites existing user-customised files.
3. Writes the project-local activation snippet into `./CLAUDE.md` (appending to existing content inside `<!-- BELCORT-HARNESS BEGIN v2 -->` … `<!-- BELCORT-HARNESS END -->` markers).
4. Warns if a legacy global `~/.claude/CLAUDE.md` block from v1.x is detected — suggests the cleanup command.

### Step 2: Run the doctor

After setup, verify the environment:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

- On exit `0`: tell the user "Environment ready. Run `/harness:sprint \"<prompt>\"`."
- On non-zero: show the doctor's full report (includes copy-paste fix commands) and stop. Tell the user: "Fix the items above, then run `/harness:doctor` to re-verify before your first sprint."

### Step 3: Tell the user what happened

Summarise: files created in `.harness/`, project CLAUDE.md patched, any legacy global block detected. Give the exact next-step command.

## Notes

- Setup is per-project. If you work in multiple harness projects, run setup in each.
- Re-running setup is safe: existing files in `.harness/` are preserved; only the `./CLAUDE.md` BELCORT-HARNESS block is refreshed.
- To migrate from v1.x global install: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-rules.sh"` once to drop the legacy global block. Then `/harness:setup` in each project.
- To uninstall from a project: remove `.harness/` and the BELCORT-HARNESS block from `./CLAUDE.md`. The plugin remains installed; other projects are unaffected.
