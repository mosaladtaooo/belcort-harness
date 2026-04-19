---
description: Install BELCORT Harness behavioral rules into ~/.claude/CLAUDE.md (idempotent, upgradable, removable). Run this once after installing the plugin.
---

# `/harness:setup`

One-time installer. Patches `~/.claude/CLAUDE.md` with the BELCORT Harness behavioral rules (the "1% rule", trigger-word detection, session-start behavior, pipeline docs). Rules load globally in every Claude Code session after install — CLAUDE.md-authority, survives context compaction.

Idempotent: running multiple times is safe. Upgrades in place when the plugin version changes.

## Procedure

### Step 1 — Install the behavioral rules

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-rules.sh"
```

Report the script's output to the user.

### Step 2 — Run the doctor (environment preflight)

Immediately after installing rules, audit the environment so the user knows what else is needed before they can actually run a sprint. Missing MCPs or an old Node will show up here — not at 3am mid-build.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

- If doctor exits `0`: tell the user "Environment ready. You can run `/harness:sprint \"<your prompt>\"` now."
- If doctor exits non-zero: show the full report (it already includes the suggested install commands). Tell the user: "Fix the items above, then run `/harness:doctor` to re-verify before your first sprint."

See [doctor.md](doctor.md).

### Step 3 — Confirm to the user

1. Rules now live in `~/.claude/CLAUDE.md` wrapped in `<!-- BELCORT-HARNESS BEGIN v1.2 --> ... <!-- BELCORT-HARNESS END -->` markers.
2. A fresh Claude Code session will pick them up automatically (no restart of existing sessions required, but they won't retroactively apply until reload).
3. To re-check the environment any time: `/harness:doctor`
4. To uninstall the rules later (keeping the plugin): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-rules.sh"`
5. To remove the plugin entirely: `/plugin disable harness` then `/plugin uninstall harness`.

## Notes

- This command does NOT auto-run on plugin install. Claude Code plugins can't inject into CLAUDE.md directly, which is why this explicit step exists.
- The patch is idempotent and wrapped in markers, so it coexists safely with any existing content in your CLAUDE.md.
- If you customize the snippet content locally, re-running setup will overwrite your customizations. Fork the plugin or edit the snippet in the plugin repo before installing.
