---
description: Install BELCORT Harness behavioral rules into ~/.claude/CLAUDE.md (idempotent, upgradable, removable). Run this once after installing the plugin.
---

# `/harness:setup`

One-time installer. Patches `~/.claude/CLAUDE.md` with the BELCORT Harness behavioral rules (the "1% rule", trigger-word detection, session-start behavior, pipeline docs). Rules load globally in every Claude Code session after install — CLAUDE.md-authority, survives context compaction.

Idempotent: running multiple times is safe. Upgrades in place when the plugin version changes.

## Procedure

Execute the installer:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-rules.sh"
```

Report the script's output to the user. Then confirm:

1. Rules now live in `~/.claude/CLAUDE.md` wrapped in `<!-- BELCORT-HARNESS BEGIN v1.2 --> ... <!-- BELCORT-HARNESS END -->` markers.
2. A fresh Claude Code session will pick them up automatically (no restart of existing sessions required, but they won't retroactively apply until reload).
3. To uninstall the rules later (keeping the plugin): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-rules.sh"`
4. To remove the plugin entirely: `/plugin disable harness` then `/plugin uninstall harness`.

## Notes

- This command does NOT auto-run on plugin install. Claude Code plugins can't inject into CLAUDE.md directly, which is why this explicit step exists.
- The patch is idempotent and wrapped in markers, so it coexists safely with any existing content in your CLAUDE.md.
- If you customize the snippet content locally, re-running setup will overwrite your customizations. Fork the plugin or edit the snippet in the plugin repo before installing.
