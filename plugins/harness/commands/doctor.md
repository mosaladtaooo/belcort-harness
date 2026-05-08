---
description: Audit the local environment against every dependency the harness pipeline needs (Claude Code CLI, git, Node 20+, context7 MCP, playwright MCP, writable .harness/, optional plugins). Blocks the pipeline on CRITICAL failures and prints copy-paste install commands. Auto-runs at the start of /harness:sprint and /harness:quick.
---

# `/harness:doctor` — Environment preflight

The pipeline assumes a specific toolchain. When it's missing, agents fail in strange ways — a Generator writes code but the Evaluator's Playwright MCP returns nothing, the Planner's Context7 calls silently 404, or the whole sprint crashes halfway through. Doctor catches these *before* the first subagent is dispatched.

**This is meant to be brainless.** You should never have to remember which MCP to install or what Node version Context7 needs. Doctor tells you, gives you the exact command, and refuses to start the pipeline until you're ready.

## Procedure

Run the script and report its output:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

Exit codes:
- `0` — all critical checks passed, pipeline may proceed (recommended items may still be missing — those are informational)
- `1` — one or more CRITICAL failures — pipeline MUST NOT proceed until resolved
- `2` — doctor itself errored (unreadable config)

**If exit is 0:** summarize "Environment ready" and let the caller continue.

**If exit is non-zero:** show the full report (including the suggested fixes block at the bottom) and stop. Do NOT dispatch any subagent. Tell the user: "Fix the items above and re-run `/harness:doctor`, then retry your command."

## When this runs automatically

- **`/harness:sprint`** — first step, before Planner dispatch (see [sprint.md](sprint.md))
- **`/harness:quick`** — first step, before Generator dispatch (see [quick.md](quick.md))
- **`/harness:setup`** — after rules installation, so you immediately see what else you need (see [setup.md](setup.md))

## When to invoke manually

- Before starting work for the day (verify MCPs didn't break overnight)
- After upgrading Claude Code, Node, or the harness plugin
- After installing/uninstalling plugins referenced by the recommended section
- When a sprint failed in a way that looked environmental rather than agent-logic

## Flags

- `--strict` — treat RECOMMENDED misses as failures too (use in CI or when you want a hard gate)
- `--json` — machine-readable output (used when agents need to parse results)
- `--quiet` — print nothing on success, full report on failure

## What it checks

**CRITICAL** (blocks pipeline):
- `claude` CLI on PATH (used by all subagent dispatches)
- `git` on PATH (atomic commits + worktrees)
- Node ≥ 20 (MCP servers require modern Node)
- `npx` on PATH (launches MCP servers)
- `jq` or `python3` available (pre-tool-use.sh needs one to parse tool input — without either, the safety hook silently fails open and force-push / `.harness/` deletion / test-file deletion guards do not fire)
- `context7` MCP registered (Planner + Generator use for live docs)
- `playwright` MCP registered (Evaluator uses for browser-driven QA — **this is the one that burned us last time**)
- Harness plugin present (SKILL.md findable)
- Global harness rules installed in `~/.claude/CLAUDE.md`
- Project directory writable (so `.harness/` can be created)

**RECOMMENDED** (warns, doesn't block):
- Git working tree clean
- Inside a git repository
- `frontend-design`, `security-guidance`, `agentlint` plugins

Every failure prints the exact install command to copy-paste. No googling.
