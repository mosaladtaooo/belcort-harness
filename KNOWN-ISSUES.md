# Known Issues

Issues found during stress testing that were deliberately **deferred** rather than fixed. Each was triaged against the user model (non-technical solo founder, single-machine macOS, brownfield projects, no adversarial LAN). Items here are real but unlikely to bite that user; they're sediment for future-me when ground-truth use surfaces them.

Rule: don't fix proactively. When real-world use produces a reproducible symptom that maps to one of these, then fix.

---

## Round-3 stress test — deferred (single-agent findings, lower impact)

### Cosmetic / doc drift
- **`commands/design.md:299`** — comment still says `manifest_round >= 5 floor` but round-2 dropped that floor. Stale prose, not a logic bug.
- **`commands/sprint.md:444-445`** — FEATURE_ID halt message says "1-128 chars" but regex actually allows 129. Off-by-one in the message, not the regex.
- **`agents/designer.md:382`** — bash trim idiom comment over-promises; works lucky-correct via downstream regex.
- **`scripts/doctor.sh:353`** — hard-coded `version: 3\.` will WARN/FAIL on impeccable v4 even if v4 is a superset. Forward-compat wall.

### Adversarial-only (zero threat for solo dev)
- **`*.local` mDNS allowlist** — attacker on hostile LAN could register `attacker.local`. Not relevant for solo dev on home Mac.
- **`init.sh` URL injection** — user controls own init.sh.
- **SKILL.md symlink attack** — same.
- **manifest_round = `008` octal bypass** — user is the only one editing manifest. Self-attack.
- **`commands/sprint.md:336-339`** — sed extracts FEATURE_ID with `[^ #"]` exclusion; doesn't reject `/`/`..`/`~`. round-3 added regex validation downstream which catches it; raw extraction stays loose. Defense-in-depth gap, not exploitable.

### Edge-case correctness
- **`scripts/doctor.sh:344`** — `find ... | sort -V | tail -1` on multiple impeccable installs (cache, marketplace, IDE-specific) picks lexically-last path, not Claude's actual SKILL.md. May give wrong v3-detect result if multiple IDE plugins installed.
- **`agents/designer.md:380`** — `head -1` on multiple `design_reroll_round` lines reads first; YAML parsers say last-wins. Inconsistent if manifest has duplicates (which it shouldn't).
- **Reroll N+2 case** — Designer crashes mid-reroll, orchestrator-increment skipped, user re-runs `/harness:design reroll`: file ends N+1, manifest N-1. Tamper detection halts but message says "history truncated" — wrong framing.
- **macOS APFS case-insensitive (default)** — round-3 added a doctor WARN. The catastrophic case is "user creates `design.md` lowercase, harness writes `DESIGN.md`, FS aliases, next write clobbers user data." But for a non-tech founder who lets AI do all file work, AI uses canonical case; trigger is unlikely in practice.

### Designer halt message stranded
- **`commands/sprint.md:530-537`** — when Designer halts (URL allowlist reject, manifest corrupt), sprint's missing-report branch shows generic "Manual investigation required" instead of surfacing the actual halt message from `.last-designer-stdout.txt`. User can't tell init.sh has bad URL vs Designer crashed.

### doctor exit-code gating
- **`scripts/doctor.sh:492-494` + `commands/sprint.md:34-40`** — sprint calls doctor without `--strict`, so RECOMMEND-FAIL (impeccable v3 missing) doesn't gate sprint. Pipeline runs anyway; subagent fails at runtime with skill-not-found. Fix is one line (add `--strict` or change v3 check to CRITICAL); deferred because the runtime error is loud enough that user notices.

### `mkdir` failure in case-sensitivity probe
- **`scripts/doctor.sh:471-474`** — read-only mount makes the probe silently skip without emitting a row. User can't tell if the check ran. Cosmetic hole.

---

## UX stress test (8-lens audit) — deferred TIER 2/3

### Brownfield gaps not closed in ux-r1
- **CLAUDE.md backup before rewrite** — setup strips harness block but doesn't snapshot pre-edit content. ux-r1 added conflict warnings; full backup is round-2 work.
- **`templates/manifest.yaml`** doesn't yet declare `project.src_dir / test_runner / stack_family` as canonical fields. ux-r1 substitutes them at setup time but legacy manifests read empty (consumers fall back to `"src"`/`"main"`).
- **`/harness:quick`** has its own hard-coded `src/` and `git checkout main` references. ux-r1 fixed `/harness:sprint`; quick needs the same sweep.
- **CI / GitHub Actions** never read by harness. Existing commit-lint rules (`feat(scope):`) reject `[harness:build]` commits.
- **Branch naming** still `harness/build/${FEATURE}` regardless of project conventions (`feat/*` etc).

### Multi-project / concurrency
- **Playwright MCP port collision** — 3 projects defaulting to `:3000` collide; Evaluator on tab 1 navigates to project 2's app, scores wrong sprint. **High impact if user runs concurrent sprints; low frequency in practice for solo workflow.**
- **`.worktrees/current/` fixed path** — concurrent sprints in same project: second silently reuses first's worktree.
- **`.last-designer-stdout.txt` singleton** — concurrent audit-gates clobber each other.
- **Mid-flight plugin upgrade** — `/plugin install impeccable@latest` while tab 2 mid-sprint changes prompts mid-flow.

### Resume / abort gaps
- **`git merge --squash` ↔ `git commit` window** — no `state.phase = "merging"` checkpoint. Cmd+C between leaves dirty index, manifest claims retrospective complete.
- **`/harness:abandon`** doesn't exist — `pre-tool-use.sh:115` blocks `rm -rf .harness/` from inside Claude Code, user has to drop to shell.
- **`git reset --hard` after uncommitted `.harness/`** — state wiped; orphan build branch survives; session-start hook silently exits. Recovery requires reading `git branch -a`.

### UX language
- **`agents/evaluator.md` Lens K4 ("does the test verify the goal?")** — most vulnerable to leniency drift. Mechanical defenses (ux-r1 B2.1/2.3) close the easy cases; deep K4 still requires Evaluator judgment.
- **Designer "AUDIT PASS" terminology** — user reads as "everything works" when it only audits design dimensions. Functional pass is Evaluator's job. Rename or add disclaimer in ux-r2.
- **Plan approval gate "approve everything except FR-3"** — partial-approval not supported. ux-r1 added plain-English summary but partial-veto path still requires `/harness:amend`.
- **Negotiate-stuck escalation (`commands/negotiate.md` §4)** — user picks (a) force Generator / (b) force Evaluator. Non-tech user has no basis to choose between two HOW-language positions.

### Realistic-feature scenarios
- **"add a settings page where users can change their email"** — Email-sending OUT-of-scope is buried in PRD; ux-r1 plain-English summary surfaces it but the IN/OUT distinction at PRD authoring time is still Planner's judgment call.
- **"add Stripe checkout"** — Planner picks Checkout vs Elements vs Payment Intents silently when not asked. ux-r1 doesn't force the question.

---

## Round-2 candidates flagged by ux-r1 fix agents

### From Sprint UX agent
- **`config.max_negotiation_rounds` vs literal 3** — retry-counter messages hard-code "round N of 3" but real cap reads from manifest. Lies if user bumped cap.
- **Cost-rate table in manifest comment** is now source-of-truth for token pricing. Anthropic ships new pricing → comment goes stale. Round-2: extract to `templates/cost-rates.yaml`.
- **V0 jargon blocklist** is enforced by Planner reading its own checklist (self-administered). Round-2: mechanical post-Planner grep.
- **`/harness:abort` phase-mapping** assumes `progress/changelog.md` records every phase transition reliably. Some sections have prose advice; not enforced.
- **Intent classifier `aesthetic`/`vibe` keywords** — false-positive risk on phrases like "aesthetic API design". Conservative-by-design mitigates; tighten if needed.

### From Brownfield + Trust agent
- **Evaluator Step 4.4 AC grep** — searches common test directories but no fallback for colocated tests (`app/(features)/foo/foo.test.ts`). Tighter heuristic later.
- **Evaluator Step 4.6 route regex** — strips filesystem-y paths (`/api/`, `/tmp/`). False-negatives on real `/api/users` route mentions in PRD. Document or relax.
- **CLAUDE.md conflict scanner** — fires spuriously on prose like "we deliberately use vitest, NOT jest". Acceptable since warns rather than blocks.

---

## Philosophical / by-design

### M1 — Reroll budget symmetric reset
The reroll budget cap (5 rounds) cannot be enforced against a user who **simultaneously** deletes `## Reroll History` AND resets `state.design_reroll_round: 0`. Both counts agree → tamper detection has no signal. This is information-theoretically true; the only fixes (git-as-ledger, hash chain, project-external state) impose meaningful friction on the legitimate solo-dev workflow.

**Resolution**: budget is a **soft focus heuristic**, not a security control. The user is the only "attacker"; gaming their own budget is self-attack with no external value. Round-2 (`9fceeaf`) hardened against asymmetric tampering (forgetting to update one side); symmetric reset stays open by design. See design loop docs for the philosophy framing.

### Generator silence during BUILD (`agents/generator.md:381`)
Intentional — orchestrator-level cost surface (ux-r1) replaces in-subagent progress signals. Don't add per-tool-use chatter to Generator/Evaluator/Designer.

---

## Rules of engagement

- **Don't proactively close items here.** Each represents a real cost-benefit decision.
- **When ground-truth use surfaces a symptom**, locate it here, then fix. The diff between "what was deferred" and "what we just hit" is calibration data — feed it back to future stress-test pacing.
- **Add new entries here, don't dispatch a stress-test round** unless the rate of unique real-world bugs rises (sign that something fundamental shifted).
- **The harness is a tool.** Goal is shipping products through it, not perfecting it.
