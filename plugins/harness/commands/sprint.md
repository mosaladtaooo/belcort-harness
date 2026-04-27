---
description: Full harness pipeline — plan (2-pass) → analyze → human gate → negotiate → build (TDD) → evaluate → tuning check → retry/retrospective → merge. Use for substantial features (>15 min of work).
argument-hint: "<what to build, 1-4 sentences>"
---

# `/harness:sprint` — Full Pipeline

Runs: doctor → (brainstorm check) → Planner → analyze → human gate → Generator ↔ Evaluator negotiate → Generator BUILD → Evaluator EVALUATE → retry-or-retrospective → merge. The user's request is `$ARGUMENTS`. If empty, ask them to describe what to build before dispatching anything.

---

## 0a. Brainstorm check — ambiguity gate (optional)

Before touching the environment, scan the prompt for vagueness signals:

- Prompt ≤2 sentences AND no concrete verbs (build, implement, create, fix, migrate, refactor).
- Uncertainty words: `maybe`, `not sure`, `I think`, `figure out`, `help me decide`.
- Multiple plausible interpretations (e.g., "a dashboard").
- Unfamiliar domain with no prior features in `manifest.yaml`.

If ANY signal hits, offer the user: run `/harness:brainstorm` first (recommended), proceed anyway (Planner will use AskUserQuestions to clarify), or cancel.

If NO signal hits, skip this step silently.

If `.harness/brainstorm-current.md` exists from a prior brainstorm session, treat its content as additional context for the Planner dispatch in Step 1. After Planner creates the feature folder in Step 1, the orchestrator moves `brainstorm-current.md` into the feature folder as `brainstorm.md`.

---

## 0. Doctor — environment preflight (mandatory, blocking)

Before dispatching any subagent, run the doctor:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
DOCTOR_EXIT=$?
```

- `DOCTOR_EXIT = 0`: environment ready, proceed.
- `DOCTOR_EXIT = 1`: CRITICAL failure. Show the doctor's report (with fix suggestions) and STOP. Tell the user: "Fix the items above, then re-run `/harness:sprint \"$ARGUMENTS\"`."
- `DOCTOR_EXIT = 2`: doctor itself errored. Hard stop. Show stderr. Tell the user to run the doctor manually and investigate.

See [doctor.md](doctor.md) for what it checks.

---

## 1. Plan — dispatch Planner subagent (two-pass)

The Planner works in two passes:
- Pass 1: PRD + constitution (the WHAT and WHY).
- Pass 2: Architecture + criteria + contract (the HOW — informed by Pass 1).

Dispatch pattern (v2.1.0+): the Planner is a plugin-shipped subagent type declared in `plugin.json` via `"agents": "./agents/"`. Its system prompt, allowed tools, and identity come from `agents/planner.md` frontmatter — the orchestrator invokes it through Claude Code's native Agent tool.

If a brainstorm file exists, the orchestrator includes its content in the Planner dispatch as additional context.

**Design context injection (v1 design loop integration):** before dispatching the Planner, the orchestrator constructs a `DESIGN_CONTEXT` string that is appended to the Planner dispatch prompt if (and only if) a hi-fi prototype exists from a prior `/harness:design explore` run. This injection is fully conditional — when no `.harness/design/prototype/` exists, sprint.md behaviour is unchanged from v2.2.

```bash
# Load design context if a prototype exists from /harness:design explore
DESIGN_CONTEXT=""
if [ -f ".harness/design/prototype/prototype.html" ]; then
  DESIGN_CONTEXT="
--- DESIGN CONTEXT (from /harness:design explore + teach) ---

A hi-fi prototype was created and validated by the user before this sprint. Read these files in addition to the spec:

- \`.harness/design/prototype/prototype.html\` — visual contract for what the user expects to see
- \`.harness/design/prototype/prototype-notes.md\` — interaction map: what's clickable, what's mock vs functional, declared gaps"

  if [ -f ".harness/design/DESIGN.md" ]; then
    DESIGN_CONTEXT="${DESIGN_CONTEXT}
- \`.harness/design/DESIGN.md\` — design system (tokens, principles, anti-patterns, motion, accessibility) the build must respect"
  fi

  if [ -f ".harness/design/PRODUCT.md" ]; then
    DESIGN_CONTEXT="${DESIGN_CONTEXT}
- \`.harness/design/PRODUCT.md\` — product-level intent (users, brand, tone, anti-references) that informs the architecture"
  fi

  DESIGN_CONTEXT="${DESIGN_CONTEXT}

When writing PRD, treat the prototype as visual contract — don't redesign the UX, transcribe what the prototype shows into FRs/UJs/ACs. When writing architecture, derive component breakdown that mirrors the prototype's structure. The prototype is INPUT (supplement) not REPLACEMENT — your negotiate phase still runs and can refine HOW.
--- END DESIGN CONTEXT ---"
fi
```

If `DESIGN_CONTEXT` is non-empty, the orchestrator appends it (verbatim) to the end of the Planner dispatch prompt below — after `$ARGUMENTS` and after the brainstorm block (if any).

The orchestrator dispatches the Planner via the Agent tool:

- **subagent_type**: `harness:planner`
- **description**: `"Plan feature: <one-line summary of $ARGUMENTS>"`
- **prompt**: the following block (pass as the Agent tool's `prompt` parameter verbatim):

> You are being dispatched in PLAN mode (see your system prompt for the full role and 2-pass procedure).
>
> Produce the full specification per PASS 1 + PASS 2. Write only the files your output sections list: spec/*, evaluator/criteria.md, features/NNN-name/contract.md, per-FR story files under features/NNN-name/stories/, init.sh, manifest.yaml, ROADMAP.md, progress/*. DO NOT write source code or implementation files — those are for the Generator. Run your 16-point self-validation before exiting and report the pass count.
>
> User request:
> $ARGUMENTS
>
> [If `.harness/brainstorm-current.md` exists, the orchestrator appends its full content here under a `--- BRAINSTORM CONTEXT ---` marker before invoking the Agent tool.]
>
> [If `.harness/design/prototype/prototype.html` exists, the orchestrator appends `${DESIGN_CONTEXT}` (constructed above) here. When no prototype exists, this append is a no-op and the dispatch proceeds unchanged.]

**After Planner returns, the orchestrator (not a subagent) performs these housekeeping steps using the Bash/Edit tools. These are natural-language instructions — not a shell script:**

1. Verify the Planner actually wrote the expected files (spec/, evaluator/criteria.md, features/NNN-name/contract.md, stories/, init.sh, manifest.yaml, ROADMAP.md). If any is missing, halt and ask the user.
2. If `.harness/brainstorm-current.md` still exists and the feature folder now exists, move the brainstorm file into the feature folder as `brainstorm.md`.
3. Make `.harness/init.sh` executable. The Planner has no Bash tool, so it cannot chmod its own output.

Then wait for the human gate in Step 2.

---

## 2. Human gate — present summary, wait for approval

Summarise what was planned:

```
═══════════════════════════════
  Harness — Planning Complete
═══════════════════════════════
Project: [name]
Complexity: [small/medium/large] ([N] FRs)
Stack: [framework + db]

PRD: [N] personas, [N] journeys, [N] FRs, [N] NFRs, [N] risks.
Architecture: [N] components, Context7 verified.
Contract: [strategy], [N] deliverables, [N] ACs.
Files: ✓ spec/prd.md, ✓ spec/constitution.md, ✓ spec/architecture.md,
       ✓ evaluator/criteria.md, ✓ features/NNN/contract.md, ✓ init.sh.
Planner self-validation: [N/16 passed].

Next:
  • approved               → negotiate + build
  • /harness:clarify       → surface ambiguities, answer, auto-patch
  • /harness:amend "<X>"   → targeted tweak
  • /harness:edit "<X>"    → multi-file spec edit
  • /harness:rewind planning → fundamental re-plan
═══════════════════════════════
```

**Do NOT proceed until the user explicitly approves.** This is the only mandatory human gate.

If the user wants changes, route through a command — never edit spec files from this orchestrator's context (see SKILL.md § File Ownership Contract).

**Auto-suggest `/harness:clarify`** if: Planner self-validation mentioned ≥3 silent defaults, OR user's approval text contains uncertainty words ("maybe", "not sure", "probably").

---

## 2b. Analyze — cross-artifact consistency (automatic)

Run the [`/harness:analyze`](analyze.md) procedure. CRITICAL findings halt; warnings pass through.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "negotiating"` (Edit tool).

---

## 2c. Negotiate — Generator ↔ Evaluator agree on sprint contract (automatic)

Three dispatches in sequence. The orchestrator reads `state.current_feature` from manifest.yaml before each dispatch to get the `${FEATURE}` value.

**Round 1: Generator writes proposal.md** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Negotiate proposal for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in NEGOTIATE mode (see your system prompt's MODE ROUTING table).
>
> Do NOT write code in this mode. Read the draft contract, architecture direction, constitution, and criteria via Read tool. Write your implementation proposal to .harness/features/${FEATURE}/proposal.md per the template at @templates/features/proposal.md.txt.

**Round 2: Evaluator reviews the proposal** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Review generator proposal for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in REVIEW-PROPOSAL mode (see your system prompt's MODE ROUTING table).
>
> Do NOT run Playwright — there is no app yet. Read (all via Read tool):
> - `.harness/evaluator/criteria.md` — grading rubric
> - `.harness/features/${FEATURE}/contract.md` — Planner's draft contract
> - `.harness/features/${FEATURE}/proposal.md` — Generator's proposed HOW
> - `.harness/spec/constitution.md` — use it to judge test-strategy adequacy + HOW-level coding-standard compliance (v2.1.3+)
> - `.harness/spec/architecture.md` — use it to verify the proposal's component/directory/data-model choices align with the declared architectural style (v2.1.3+)
>
> PRD is NOT needed at this stage — the contract already contains the NFR targets. Write your review to `.harness/features/${FEATURE}/review.md` per the canonical template at `@templates/features/review.md.txt` with a VERDICT line (agreed | needs-revision).

**Iterate**: if verdict is `needs-revision`, re-dispatch Generator via the Agent tool (same `harness:generator` subagent_type, NEGOTIATE mode prompt) to revise proposal.md; then Evaluator reviews again. Max 3 rounds (per `config.max_negotiation_rounds` in manifest). If no agreement at round 3, escalate to human.

**Final: Generator writes the negotiated contract** — the orchestrator dispatches via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Finalize contract for ${FEATURE}"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in FINALIZE-CONTRACT mode. Merge proposal.md + review.md into the final contract. Overwrite .harness/features/${FEATURE}/contract.md with the final version (MUST include **Negotiated**: marker). Do NOT update manifest.yaml — the orchestrator handles phase transitions.

**After FINALIZE returns**: orchestrator updates `.harness/manifest.yaml` → `state.phase = "building"` using the Edit tool.

See [negotiate.md](negotiate.md) for the standalone variant.

---

## 3. Build — dispatch Generator subagent

Create the worktree:

```bash
git worktree add .worktrees/current -b "harness/build/${FEATURE}" 2>/dev/null || true
```

**Note on the worktree's stale `.harness/`:** the checkout includes a frozen snapshot of `.harness/` at `.worktrees/current/.harness/` as a git-worktree side-effect. It is stale and must not be read or written by any agent or orchestrator step. The live `.harness/` is at project root. See SKILL.md § File Ownership Contract → Working directory and `.harness/` location. The dispatch prompt below restates this rule inline so the Generator has it in its fresh context.

Assemble the dispatch context. The Generator reads most files via its own Read tool — the inline file list in the prompt is a hint, not authoritative. Prefer per-FR story reads per TDD cycle over the full aggregate contract.

If `.harness/features/${FEATURE}/eval-report.md` exists (this is a retry), the orchestrator reads its content and appends it to the Agent prompt under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before the user-request block.

**Design system injection into BUILD context (v1 design loop integration):** before dispatching the Generator, the orchestrator constructs a `DESIGN_BUILD_CONTEXT` string that is appended to the Generator BUILD dispatch prompt if (and only if) `.harness/design/DESIGN.md` exists from a prior `/harness:design teach` run. Fully conditional — no DESIGN.md, no append, behaviour unchanged.

```bash
# Inject design system into Generator BUILD context if it exists
DESIGN_BUILD_CONTEXT=""
if [ -f ".harness/design/DESIGN.md" ]; then
  DESIGN_BUILD_CONTEXT="
--- DESIGN SYSTEM CONTEXT (from /harness:design teach) ---

Read \`.harness/design/DESIGN.md\` before implementing UI components. Apply the design tokens (colors, typography, spacing, elevation) it specifies. Cross-check rendered output against \`.harness/design/prototype/prototype.html\` if you can — components should look like that prototype, not your own design taste.

If DESIGN.md and constitution conflict, constitution wins (per the existing constitution-vs-DESIGN priority rule).
--- END DESIGN SYSTEM CONTEXT ---"
fi
```

If `DESIGN_BUILD_CONTEXT` is non-empty, the orchestrator appends it (verbatim) to the end of the Generator BUILD dispatch prompt below — after the key-files list and after the evaluator-feedback block (if any).

The orchestrator dispatches the Generator via the Agent tool:

- **subagent_type**: `harness:generator`
- **description**: `"Build ${FEATURE} via TDD"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in BUILD mode (see your system prompt's MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root. All `.harness/...` paths below resolve from project root. The `.worktrees/current/.harness/` folder exists (git-worktree side-effect) but is a stale frozen snapshot — never read or write it. Source code goes into `.worktrees/current/src/...`; spec and report files stay under project-root `.harness/`. If you `cd .worktrees/current` for a Bash command, `cd` back before any `.harness/` Read/Write, or use `$CLAUDE_PROJECT_DIR/.harness/...` absolute paths.
>
> Implement the negotiated contract via TDD (use superpowers:test-driven-development for the RED → GREEN → REFACTOR cycle; see your Phase 2 instructions). Read per-FR stories at .harness/features/${FEATURE}/stories/FR-NNN.md per cycle — that's your canonical per-cycle context.
>
> Key files (read via Read tool as needed, always from project-root `.harness/`):
> - .harness/spec/constitution.md
> - .harness/spec/architecture.md
> - .harness/features/${FEATURE}/contract.md (final, negotiated)
> - .harness/features/${FEATURE}/stories/*.md
> - .harness/evaluator/criteria.md
>
> [If `.harness/features/${FEATURE}/eval-report.md` exists, the orchestrator appends its full content here under a `--- EVALUATOR FEEDBACK (fix these) ---` marker before invoking the Agent tool.]
>
> [If `.harness/design/DESIGN.md` exists, the orchestrator appends `${DESIGN_BUILD_CONTEXT}` (constructed above) here. When no DESIGN.md exists, this append is a no-op and the dispatch proceeds unchanged.]

---

## 3a. Pause check — Generator may have requested user input mid-build

If `.harness/features/${FEATURE}/pause-questions.md` exists after the Generator dispatch returns, the Generator paused and needs answers.

Loop (up to `MAX_PAUSES = 3`):
1. Read pause-questions.md; present each question to the user with its "default if unanswered" fallback.
2. Collect answers. Each answer is either a user response, "accept default", or "skip" (marks FR partial).
3. Archive the pause file: move to `.harness/features/${FEATURE}/paused-history/pause-N-TIMESTAMP.md`.
4. Orchestrator increments `manifest.yaml → config.calibration_metrics.agent_checkins` by 1 using the Edit tool.
5. Re-dispatch Generator BUILD via the Agent tool (same `subagent_type: harness:generator`, same BUILD-mode prompt from Step 3), with the collected answers appended to the end of the prompt under a `--- PAUSE ANSWERS ---` marker.
6. If a new `pause-questions.md` appears after the re-dispatch, loop again.

After `MAX_PAUSES`, escalate: "Generator has paused N times on this sprint — the contract is likely under-determined. Recommend `/harness:rewind negotiating` to re-spec the affected FR(s) before continuing." Halt the sprint.

Orchestrator updates `.harness/manifest.yaml` → `state.phase = "evaluating"` after the Generator dispatch completes successfully.

---

## 4. Evaluate — dispatch Evaluator subagent (FRESH context, SEPARATE from Generator)

**4a. Setup-required gate (v2.1.9+).** Before dispatching the Evaluator, the orchestrator reads `.harness/features/${FEATURE}/implementation-report.md` → `## Setup required` section. If it lists required files that the user must create (e.g., `.env.local`) OR other user-completable steps (database migrations with user credentials, external service config), the orchestrator:

1. Checks whether each required file exists at the project-root path.
2. If all required files exist AND the report doesn't flag remaining user steps, proceed to 4b (Evaluator dispatch).
3. Otherwise: present the Setup section to the user verbatim, with a message like *"Generator finished building. Before I dispatch the Evaluator, complete this setup: [list]. Type 'continue' when ready."* Wait for confirmation. Do NOT auto-retry or skip — an Evaluator run against an app that can't start produces a false FAIL that wastes retry budget.

This gate exists because the app under test often needs secrets (DB URLs, API keys, signing keys) that the Generator cannot write (AgentLint's `no-env-commit` + `no-secrets` rules are unsuppressible errors, by design). The two-file convention `.env.example` (Generator) + `.env.local` (user) hands off cleanly at this gate.

**4b. Evaluator dispatch.** The orchestrator dispatches the Evaluator via the Agent tool:

- **subagent_type**: `harness:evaluator`
- **description**: `"Evaluate ${FEATURE} via Playwright"`
- **prompt**: (passed verbatim to the Agent tool's `prompt` parameter):

> You are being dispatched in EVALUATE mode (see your system prompt's MODE ROUTING table).
>
> **Working directory contract (v2.1.8):** your cwd is the project root. All `.harness/...` paths (`eval-report.md`, `criteria.md`, `examples.md`, `evaluator-notes.md`, `contract.md`, `proposal.md`, `review.md`, `constitution.md`, `prd.md`, `init.sh`) resolve from project root. The `.worktrees/current/.harness/` folder is a stale frozen snapshot — never read or write it. Source code to exercise lives in `.worktrees/current/src/...`; if `init.sh` needs to `cd` there to start the app, that's fine for launching the app, but always come back to project root for `.harness/...` writes like `eval-report.md`.
>
> Test the running application via Playwright MCP, grade against the four criteria with hard thresholds, run the reward-hacking scan (Step 4.5), and write your verdict to .harness/features/${FEATURE}/eval-report.md per the template at @templates/features/eval-report.md.txt.
>
> Calibration-mandatory reads BEFORE scoring (all from project-root `.harness/`):
> - .harness/evaluator/examples.md (few-shot anchors)
> - .harness/spec/evaluator-notes.md (if exists)
> - .harness/evaluator/criteria.md
>
> Then: read implementation-report.md, contract.md, proposal.md, review.md, constitution.md, prd.md (via Read tool — all from project-root `.harness/`). Start the app with bash .harness/init.sh (also project-root). Exercise via Playwright.

---

## 5. Result — read evaluator report and decide

Orchestrator reads `.harness/features/${FEATURE}/eval-report.md`, extracts the `**Result: PASS / FAIL**` line, and reads `state.retry_count` vs `config.max_retries` from manifest.yaml.

### If PASS

**5-pre-audit. Auto-audit-gate (v1 design loop integration) — conditional, only fires when `.harness/design/` exists**

After the Evaluator's functional PASS but BEFORE the tuning check (5a-pre), the orchestrator dispatches Designer in AUDIT mode to run impeccable's 5-dimension design audit + constitution cross-check on the just-built feature. If the audit reports **P0 findings**, the orchestrator re-dispatches BUILD (Step 3) with the audit findings as feedback, capped at `AUDIT_MAX_RETRIES = 2` audit-retries. If only P1+ findings are reported, the audit results are surfaced to the user but the loop continues to merge.

This gate is **fully conditional** — it fires ONLY when `.harness/design/` exists with at least `DESIGN.md` or `prototype.html` AND `.harness/spec/constitution.md` exists. Sprints without design context (no `/harness:design teach` ever ran, no prototype) skip this entire section and proceed directly to `5a-pre` unchanged from v2.2 behaviour.

The audit-retry counter (`AUDIT_RETRY_COUNT`) is **separate** from the functional retry counter (`state.retry_count` in manifest.yaml). A feature that hits functional FAIL 3 times AND audit FAIL 2 times does NOT double-count — they are independent budgets. `AUDIT_RETRY_COUNT` is bash-local (ephemeral); the audit-retry record persists via the audit files in `.harness/design/audits/audit-<feature-id>-N.md` (count of attempts = max(N) for the feature).

```bash
# Auto-audit-gate — only fires when a design context exists.
AUDIT_RETRY_COUNT=0
AUDIT_MAX_RETRIES=2

# Read the feature-id from the manifest. The orchestrator already has ${FEATURE}
# from Step 3 (negotiate / build); re-extract here for clarity in this self-
# contained block. The sed pattern strips the surrounding quotes and ignores
# any inline "# e.g., ..." YAML comment that follows the value.
FEATURE_ID=$(sed -n 's/^  current_feature: *"\([^"]*\)".*/\1/p' .harness/manifest.yaml)
if [ -z "$FEATURE_ID" ]; then
  # Fallback: handle unquoted-value case (some manifests may not quote).
  FEATURE_ID=$(sed -n 's/^  current_feature: *\([^ #"]*\).*/\1/p' .harness/manifest.yaml)
fi

# Path-confinement helper (Agent 5 round-2 finding): the size-gate inputs
# below (constitution.md, DESIGN.md, prototype.html), the audit report
# (LATEST_AUDIT), and the Designer stdout capture (.last-designer-stdout.txt)
# are all read by this gate. `wc -c < $FILE`, `grep`, `cat`, etc. silently
# follow symlinks — a symlinked leaf OR a symlinked parent directory could
# point any of these reads at /etc/passwd, ~/.ssh/id_rsa, or an attacker-
# controlled blob outside the project. macOS-specific gotcha: /tmp and
# $TMPDIR are themselves symlinks on darwin (→ /private/tmp/...), so a
# substring check like `case $RESOLVED in /tmp/*) reject ;;` mis-fires on
# innocent setups. The right check is canonicalize-and-confine: resolve
# every read path through realpath and require the result to live under
# the canonical project root's `.harness/`.
PROJECT_ROOT_CANON="$(pwd -P)"
_canonicalize() {
  # Print the canonical (symlink-resolved) absolute path of $1, or empty
  # string on failure. Tries python3 first (real interpreter test, mirrors
  # the JSON_PARSER pattern in plugins/harness/hooks/pre-tool-use.sh), then
  # readlink -f (macOS Sonoma+ / GNU coreutils). Either is sufficient on
  # darwin 24.6.0; both being absent means the host is too minimal to run
  # the harness anyway.
  if command -v python3 >/dev/null 2>&1 && python3 -c 'print(1)' >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$1" 2>/dev/null
  else
    echo ""
  fi
}
_confined_to_harness() {
  # Returns 0 (success) iff $1 canonicalizes to a path under
  # $PROJECT_ROOT_CANON/.harness/. Use this as a guard before every read
  # of a file the audit-gate trusts.
  local _resolved
  _resolved="$(_canonicalize "$1")"
  case "$_resolved" in
    "$PROJECT_ROOT_CANON"/.harness/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Gate: design context must exist AND constitution.md must be substantive.
# Content-size check (Agent 4 CR-5): a stub DESIGN.md (empty or near-empty) or a
# stub prototype.html shouldn't fire the gate — we'd dispatch Designer to audit
# against criteria that don't exist yet, wasting a full Designer + impeccable
# round and confusing the user. Require constitution.md > 200 bytes (the smallest
# meaningful constitution has at least a couple of clauses), AND require either
# DESIGN.md ≥ 2KB (the size below which TEACH self-validation fails) or
# prototype.html ≥ 1KB (the size below which a real prototype can't fit even
# a single component).
#
# Each `wc -c < $FILE` below is preceded by a confinement check — if the
# file (or any parent component) resolves outside .harness/, treat it as
# absent rather than reading attacker-controlled content into a size test.
DESIGN_PRESENT=0
if [ -d ".harness/design" ] && _confined_to_harness ".harness/spec/constitution.md" \
   && [ -s ".harness/spec/constitution.md" ] \
   && [ "$(wc -c < .harness/spec/constitution.md 2>/dev/null)" -gt 200 ]; then
  if { _confined_to_harness ".harness/design/DESIGN.md" \
       && [ -s ".harness/design/DESIGN.md" ] \
       && [ "$(wc -c < .harness/design/DESIGN.md)" -ge 2048 ]; } \
     || { _confined_to_harness ".harness/design/prototype/prototype.html" \
          && [ -s ".harness/design/prototype/prototype.html" ] \
          && [ "$(wc -c < .harness/design/prototype/prototype.html)" -ge 1024 ]; }; then
    DESIGN_PRESENT=1
  else
    echo "Skipping audit-gate: design files exist but appear to be stubs (DESIGN.md < 2KB or prototype < 1KB), or resolve outside .harness/."
  fi
fi

if [ "$DESIGN_PRESENT" = "1" ]; then
  mkdir -p .harness/design/audits

  # Empty-FEATURE_ID guard (Agent 2 + 3 finding): the manifest default for
  # state.current_feature is "" — both sed fallbacks above return empty in
  # that case, and a downstream glob like audit-${FEATURE_ID}-*.md would
  # become audit--*.md, never matching the audit file Designer writes
  # ("audit-unknown-1.md"). Without this guard the gate writes a report,
  # the parser misses it, and the gate falsely reports "Manual investigation
  # required" after a successful build. Halt the gate cleanly instead.
  if [ -z "$FEATURE_ID" ] || [ "$FEATURE_ID" = '""' ]; then
    echo "Auto-audit-gate: state.current_feature is empty in manifest. Skipping audit gate (no feature in progress)."
    DESIGN_PRESENT=0  # short-circuit gate — falls through to skip block below
  fi
fi

if [ "$DESIGN_PRESENT" = "1" ]; then
  # Audit-target resolution (Agent 4 MA-5): pick ONE target before dispatch
  # rather than passing a literal "URL OR prototype.html" string in the
  # marker. The Designer never executes init.sh (Agent 4 CR-3 — see
  # designer.md AUDIT Step 1.2 for the read-only resolution rule); the
  # orchestrator picks the target by inspecting whether init.sh is present
  # and executable, and otherwise falls back to the prototype.
  if [ -f ".harness/init.sh" ] && [ -x ".harness/init.sh" ]; then
    AUDIT_TARGET="(see Designer Step 1.2 — resolve URL via init.sh inspection)"
  else
    AUDIT_TARGET=".harness/design/prototype/prototype.html"
  fi

  while [ "$AUDIT_RETRY_COUNT" -le "$AUDIT_MAX_RETRIES" ]; do
    # ─── Step A: Dispatch Designer in AUDIT mode ───────────────────────────
    # The orchestrator (NOT this bash block) dispatches the Designer subagent
    # via the Agent tool with subagent_type: harness:designer, description:
    # "AUDIT: 5-dim design audit + constitution cross-check (sprint auto-gate)",
    # and a prompt containing:
    #
    #   --- MODE: AUDIT ---
    #   --- AUDIT TARGET: ${AUDIT_TARGET} ---
    #
    #   You are being dispatched by /harness:sprint's auto-audit-gate after
    #   Evaluator PASS. Run the full AUDIT procedure per your system prompt
    #   (Steps 1-9). Print the parseable exit-message line. Note: this is
    #   the auto-loop dispatch — P0 findings will trigger a BUILD retry.
    #
    #   Working directory contract: cwd is project root; never read or
    #   write .worktrees/current/.harness/.
    #
    # ─── stdout-capture contract (mandatory, two halves) ─────────────────
    # The orchestrator MUST perform BOTH of these Write-tool calls every
    # iteration of this loop, around the Designer dispatch:
    #
    #   (A) BEFORE dispatching Designer: Write
    #       `.harness/design/audits/.last-designer-stdout.txt` with empty
    #       content (truncate). This guarantees that if Designer crashes
    #       or its return is unrecoverable, Step B's grep does NOT pick up
    #       a stale "AUDIT complete." line from a prior round (which would
    #       wedge the loop on an old verdict — `grep -m1` returns the
    #       OLDEST match, so a leftover round-1 line would override a
    #       fresh round-2 verdict). Truncate is non-negotiable: even on
    #       the first iteration when the file likely doesn't exist, the
    #       Write call is the only thing that distinguishes "fresh run,
    #       no Designer dispatched yet" from "Designer dispatched and we
    #       forgot to capture" — and the post-dispatch missing-file check
    #       below relies on that distinction.
    #
    #   (B) AFTER the Agent tool returns from the Designer dispatch: Write
    #       `.harness/design/audits/.last-designer-stdout.txt` with the
    #       Designer's final-message text from the Agent tool's structured
    #       return value (the field that carries the subagent's terminal
    #       output — typically the last assistant message of the subagent
    #       transcript; whatever the Agent tool surfaces in this codebase
    #       as the subagent's stdout-equivalent). Truncate, do NOT append.
    #       Designer's exit-line invariant (designer.md AUDIT Step 9)
    #       guarantees the parseable "AUDIT complete. ..." line is present
    #       in that final message.
    #
    # This contract makes Step B's exit-line parse the authoritative path
    # (Agent 2 + 3 + 4 severity-laundering fix). File-grep on the audit
    # body is a fallback for the case where Designer's exit line is
    # malformed (drift), NOT for the case where the orchestrator forgot
    # to capture stdout — that case is a contract violation and Step B
    # halts the loop instead of silently falling back.
    #
    # The Designer writes the audit report to:
    #   .harness/design/audits/audit-${FEATURE_ID}-<n>.md
    # where <n> is the attempt count it computes from the highest existing N.
    #
    # On return, the Designer prints exactly (per designer.md:760 invariant):
    #   AUDIT complete. Verdict: <PASS|FAIL>. P0=<n>, P1=<n>, P2=<n>, P3=<n>. Report: .harness/design/audits/audit-<feature-id>-<n>.md

    # ─── Step B: Parse the latest audit file for P0/P1 counts ─────────────
    # Version-sort by N (Agent 4 CR-1) instead of mtime — avoids races when
    # the user edits an old audit file, when /harness:design audit runs
    # concurrently, or on network filesystems with clock skew. The audit
    # filenames are guaranteed numeric; sort -V gives correct ordering.
    LATEST_AUDIT=$(ls .harness/design/audits/audit-"${FEATURE_ID}"-*.md 2>/dev/null | sort -V | tail -1)
    if [ -z "$LATEST_AUDIT" ] || [ ! -f "$LATEST_AUDIT" ]; then
      # Designer dispatch failed to produce a report. Surface to user; do
      # NOT silently treat as PASS — that bypasses the gate.
      echo "Design audit dispatch did not produce a report. Manual investigation required."
      echo "Options: re-run /harness:design audit manually, OR proceed with merge by typing 'force-merge'."
      break
    fi

    # Symlink defense (Agent 5 round-2 hardening): refuse to read/parse an
    # audit file whose canonical path resolves outside the project's
    # `.harness/` tree. The previous `[ -L "$LATEST_AUDIT" ]` check only
    # caught a symlinked LEAF; it missed (a) a symlinked PARENT directory
    # (e.g., `.harness/design/audits/` itself swapped to `/tmp/attacker/`
    # which then contains a regular `audit-foo-1.md`), (b) macOS's
    # /tmp → /private/tmp redirect that would false-positive a substring
    # check, and (c) the symmetric exposure on `.last-designer-stdout.txt`
    # added by the round-2 stdout-capture contract. Canonicalize via
    # realpath and require the result to live under
    # $PROJECT_ROOT_CANON/.harness/. Both an audit file symlinked to
    # /etc/passwd AND `.harness/design/audits/` symlinked to /tmp/x/
    # (with a regular file inside) are rejected.
    if ! _confined_to_harness "$LATEST_AUDIT"; then
      echo "Audit file resolves outside the project .harness/ tree — refusing to read for security."
      echo "Resolved: $(_canonicalize "$LATEST_AUDIT")"
      echo "Rerun /harness:design audit (after removing any symlinks under .harness/design/audits/) to write a fresh report."
      break
    fi

    # ─── Severity-laundering defense (Agents 2 + 3 + 4) ──────────────────
    # Designer's exit line is the contractual authoritative count
    # (designer.md AUDIT Step 9). The orchestrator captured it to
    # .last-designer-stdout.txt during the post-dispatch Write (Step A
    # half B above). Parse that first.
    #
    # Missing-file branch: at THIS point in the loop body the orchestrator
    # has just returned from a Designer dispatch and (per the Step A
    # contract) MUST have written the final-message text to the stdout
    # capture file. A missing file here means the orchestrator skipped its
    # own contract — distinct from the legitimate "fresh-run, no Designer
    # dispatched yet" state which occurs only BEFORE the first iteration
    # of this loop, never inside it. Halt with a clear contract-violation
    # message instead of silently falling back to file-grep (the silent
    # fallback was masking the bug that round-2 stress testing flagged).
    if [ ! -f .harness/design/audits/.last-designer-stdout.txt ]; then
      echo "Audit-gate contract violation: .harness/design/audits/.last-designer-stdout.txt is missing AFTER Designer dispatch." >&2
      echo "The orchestrator must Write the Designer's final-message text to that path post-dispatch (Step A half B)." >&2
      echo "Halting the audit-loop. Latest audit report (if any): ${LATEST_AUDIT}" >&2
      break
    fi
    # Same realpath-confinement guard as for $LATEST_AUDIT — the stdout
    # capture file is read by `grep` below and must live under
    # $PROJECT_ROOT_CANON/.harness/. A symlink-replacement attack here
    # would let an attacker forge an "AUDIT complete. Verdict: PASS" line
    # to bypass the gate.
    if ! _confined_to_harness ".harness/design/audits/.last-designer-stdout.txt"; then
      echo "Designer stdout capture resolves outside the project .harness/ tree — refusing to read for security." >&2
      echo "Resolved: $(_canonicalize ".harness/design/audits/.last-designer-stdout.txt")" >&2
      break
    fi
    EXIT_LINE=$(grep -m1 '^AUDIT complete\.' .harness/design/audits/.last-designer-stdout.txt 2>/dev/null)
    if [[ "$EXIT_LINE" =~ Verdict:\ (PASS|FAIL).*P0=([0-9]+).*P1=([0-9]+).*P2=([0-9]+) ]]; then
      AUDIT_VERDICT="${BASH_REMATCH[1]}"
      P0_COUNT="${BASH_REMATCH[2]}"
      P1_COUNT="${BASH_REMATCH[3]}"
      P2_COUNT="${BASH_REMATCH[4]}"
      # P3 captured separately (it may or may not be present in older
      # exit lines; default 0 if absent).
      if [[ "$EXIT_LINE" =~ P3=([0-9]+) ]]; then
        P3_COUNT="${BASH_REMATCH[1]}"
      else
        P3_COUNT=0
      fi
    else
      echo "WARNING: Designer exit line malformed or missing; falling back to file-grep."
      # NOTE: grep -c returns exit 1 when zero matches in an existing file (POSIX),
      # which would trigger `|| echo "0"` and produce multi-line output ("0\n0").
      # Use ${VAR:-0} parameter expansion instead — defaults only when grep printed
      # nothing (file missing; already guarded above). For zero matches in an
      # existing file, grep prints "0" alone and the integer test passes.
      P0_COUNT=$(grep -c '^- \*\*\[P0\]' "$LATEST_AUDIT" 2>/dev/null); P0_COUNT=${P0_COUNT:-0}
      P1_COUNT=$(grep -c '^- \*\*\[P1\]' "$LATEST_AUDIT" 2>/dev/null); P1_COUNT=${P1_COUNT:-0}
      P2_COUNT=$(grep -c '^- \*\*\[P2\]' "$LATEST_AUDIT" 2>/dev/null); P2_COUNT=${P2_COUNT:-0}
      P3_COUNT=$(grep -c '^- \*\*\[P3\]' "$LATEST_AUDIT" 2>/dev/null); P3_COUNT=${P3_COUNT:-0}
      AUDIT_VERDICT=$([ "$P0_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")
    fi

    # Severity-laundering defense: if Designer reports PASS but file-body
    # grep finds any P0 entry, treat as FAIL. Catches a Designer that
    # downgrades silently OR an exit-line that's structurally valid but
    # semantically lies (e.g., "P0=0" emitted while the punch list still
    # contains [P0] entries — the human-readable section the Generator
    # would consume on retry would still show them).
    if [ "$AUDIT_VERDICT" = "PASS" ]; then
      P0_GREP_COUNT=$(grep -c '^- \*\*\[P0\]' "$LATEST_AUDIT" 2>/dev/null); P0_GREP_COUNT=${P0_GREP_COUNT:-0}
      if [ "$P0_GREP_COUNT" -gt 0 ]; then
        echo "Severity-laundering defense: Designer reported PASS but file-grep found P0=${P0_GREP_COUNT}. Treating as FAIL."
        AUDIT_VERDICT="FAIL"
        P0_COUNT="$P0_GREP_COUNT"
      fi
    fi

    # ─── Step C: PASS branch — no P0, exit the loop and proceed to merge ──
    if [ "$AUDIT_VERDICT" = "PASS" ] && [ "$P0_COUNT" -eq 0 ]; then
      echo "Design audit passed (no P0). P1=${P1_COUNT}, P2=${P2_COUNT}, P3=${P3_COUNT} logged for review."
      # Surface P1+ to the user before tuning check (presentational only;
      # the loop has finished, control falls through to 5a-pre).
      break
    fi

    # ─── Step D: Cap reached — escalate to user, do not loop further ─────
    if [ "$AUDIT_RETRY_COUNT" -ge "$AUDIT_MAX_RETRIES" ]; then
      echo "Design audit found ${P0_COUNT} P0 finding(s) after ${AUDIT_RETRY_COUNT} retr(ies). Audit cap (${AUDIT_MAX_RETRIES}) reached."
      echo "Latest report: $LATEST_AUDIT"
      echo "Options for the user:"
      echo "  1. Force-merge with known P0 issues (the audit report stays on disk as the record)"
      echo "  2. /harness:edit DESIGN.md to soften the criteria the audit grades against, then re-run /harness:design audit manually"
      echo "  3. Manually fix the P0 findings and re-run /harness:resume (will pick up from evaluating phase)"
      echo "  4. Abandon this sprint"
      # Halt the auto-loop. The orchestrator surfaces the options above to the
      # user via the user-gate UI; the user picks one explicitly. Do NOT
      # auto-merge with open P0 — that defeats the gate.
      break
    fi

    # ─── Step E: P0 found, retries available — re-dispatch BUILD ─────────
    AUDIT_RETRY_COUNT=$((AUDIT_RETRY_COUNT + 1))
    echo "Design audit found ${P0_COUNT} P0 finding(s). Retrying BUILD (attempt ${AUDIT_RETRY_COUNT}/${AUDIT_MAX_RETRIES})."

    # Construct AUDIT_FEEDBACK to append to the BUILD dispatch prompt.
    # This mirrors the existing eval-report.md feedback pattern (Step 3's
    # --- EVALUATOR FEEDBACK --- block) — the Generator already knows how to
    # consume a "fix these findings" feedback block.
    AUDIT_FEEDBACK="
--- DESIGN AUDIT FEEDBACK (FIX P0 findings, audit-retry ${AUDIT_RETRY_COUNT} of ${AUDIT_MAX_RETRIES}) ---

The design audit found ${P0_COUNT} P0 (must-fix) finding(s) in your build. The Evaluator's functional checks PASSED, so this retry is design-driven only — focus on the P0 findings below; do not regress the functional behaviour the Evaluator already approved.

The full audit report is at: ${LATEST_AUDIT}

Inline content of the report (read this and act on EACH P0):

$(cat "${LATEST_AUDIT}")

Fix every P0 listed above. Each P0 entry has a 'Where:' location and a 'Fix:' instruction — apply the Fix at the Where. P0s tagged with (constitution §N) are constitutional violations and MUST be fixed; constitution wins over DESIGN.md and over functional convenience.

After this BUILD pass, the audit will re-run automatically. If P0 findings persist for the audit-retry cap (${AUDIT_MAX_RETRIES}), the orchestrator will escalate to the user.
--- END DESIGN AUDIT FEEDBACK ---"

    # ─── Step F: Re-dispatch Generator BUILD with audit feedback ─────────
    # The orchestrator re-dispatches the Generator via the Agent tool with the
    # SAME BUILD-mode prompt from Step 3 (subagent_type: harness:generator,
    # BUILD mode), with ${AUDIT_FEEDBACK} appended to the dispatch prompt
    # AFTER the existing eval-report-feedback block (if any) and AFTER the
    # design-build-context block. The Generator treats audit findings as a
    # feedback channel separate from Evaluator feedback — both can be
    # present on the same retry.
    #
    # Note: state.retry_count in manifest.yaml is NOT incremented here.
    # Audit-retries use AUDIT_RETRY_COUNT (this loop's counter only).
    # Functional retries (state.retry_count vs config.max_retries) remain
    # the Evaluator's domain.

    # ─── Step G: Re-dispatch Evaluator (functional check on the rebuilt) ─
    # The orchestrator re-dispatches the Evaluator via the Agent tool with
    # the SAME EVALUATE-mode prompt from Step 4 (subagent_type:
    # harness:evaluator, EVALUATE mode). The audit-driven re-build must
    # still pass the functional checks — if Evaluator returns FAIL on the
    # audit-retry, that is a functional regression and goes through the
    # existing FAIL branch (5b/5c with state.retry_count). Audit-retries
    # do NOT bypass the functional gate.
    #
    # If Evaluator returns PASS again, the loop continues at the top
    # (re-audit), checking whether the P0 findings were actually fixed.
    # If Evaluator returns FAIL, exit this audit-loop (the FAIL branch
    # below handles it; the audit gate doesn't fire again until functional
    # PASS).

    # ─── Step H: Explicit Evaluator-FAIL exit ────────────────────────────
    # After the Evaluator re-dispatch above writes eval-report.md, parse
    # the verdict and break out of the audit-loop on FAIL. The existing
    # functional FAIL branch (5b/5c) downstream of this loop handles
    # state.retry_count and the user-gate. Without this explicit check,
    # the loop would re-enter Step A (AUDIT) on a functionally regressed
    # build, which is not what we want — the audit gate only fires after
    # a clean functional PASS.
    EVAL_VERDICT=$(grep -m1 '^\*\*Result:' .harness/features/${FEATURE}/eval-report.md 2>/dev/null | grep -oE 'PASS|FAIL')
    if [ "$EVAL_VERDICT" = "FAIL" ]; then
      echo "Audit-driven re-build regressed functionally (Evaluator FAIL on retry ${AUDIT_RETRY_COUNT}). Exiting audit-loop; existing functional FAIL branch will handle via state.retry_count."
      break
    fi

    # End of loop body — control returns to the `while` condition above.
    # On the next iteration: dispatch AUDIT again (Step A), re-parse counts,
    # decide.
  done
else
  # Audit gate skipped — design context not present. The skip is fine for
  # greenfield projects (no /harness:design ever ran) but worth a one-line
  # log on brownfield so the user sees why audit didn't fire and how to
  # enable it. Heuristic for brownfield: source code present (src/, app/,
  # pages/, or components/ has content; OR package.json lists a UI framework).
  if { [ -d "src" ] && [ -n "$(ls -A src 2>/dev/null)" ]; } \
     || { [ -d "app" ] && [ -n "$(ls -A app 2>/dev/null)" ]; } \
     || { [ -d "pages" ] && [ -n "$(ls -A pages 2>/dev/null)" ]; } \
     || { [ -d "components" ] && [ -n "$(ls -A components 2>/dev/null)" ]; } \
     || [ -f "package.json" ]; then
    if [ ! -f ".harness/design/DESIGN.md" ]; then
      echo "Skipping audit-gate: no .harness/design/DESIGN.md (run /harness:design extract + teach to enable design audit on this brownfield project)."
    fi
    # If DESIGN.md exists but constitution.md doesn't, the gate would have
    # required constitution.md anyway — don't second-guess that here.
  fi
  # Greenfield case (no source dirs, no package.json): silent skip — the
  # user hasn't started building anything yet, so a missing design audit
  # is the expected state.
fi
```

**Outside the bash block (orchestrator behaviour in prose):**

- The bash block above is illustrative — it shows the control flow and the parsing patterns. The orchestrator implements each step using the Agent tool (for AUDIT / BUILD / EVALUATE re-dispatches) and Bash + Read tools (for the parsing). Treat the bash as pseudocode for the loop shape; the actual dispatches go through the Agent tool the same way the rest of sprint.md does.
- Step A (dispatch AUDIT): use the same Agent-tool pattern as the user-invoked `/harness:design audit` subcommand, with one extra line in the dispatch prompt noting "this is the sprint auto-gate, the loop will retry BUILD on P0".
- Step F (re-dispatch BUILD): reuse the existing BUILD dispatch from Step 3. Append `${AUDIT_FEEDBACK}` (constructed in Step E) to the end of the dispatch prompt — AFTER the existing `--- EVALUATOR FEEDBACK ---` block (if any from a prior functional retry; usually absent in the post-PASS path) and AFTER the `${DESIGN_BUILD_CONTEXT}` block. The Generator already handles a feedback block at the prompt tail; the AUDIT feedback is structurally identical to the EVALUATOR feedback pattern.
- Step G (re-dispatch EVALUATE): reuse the existing EVALUATE dispatch from Step 4. The audit-retry's functional PASS becomes the gate for the next AUDIT iteration. If the audit-driven re-build regresses functionally (Evaluator FAIL), the existing FAIL branch (5b — retries < max OR 5c — retries ≥ max) handles it; the audit-loop does NOT consume `state.retry_count` itself, but the BUILD it triggers uses the regular Evaluator path and that path may consume `state.retry_count` if it FAILs.

**Why a separate counter (AUDIT_RETRY_COUNT)**: functional retries (`state.retry_count`, capped by `config.max_retries`, default 3) cover the Evaluator's functional FAIL → fix → re-evaluate cycle. Audit retries (`AUDIT_RETRY_COUNT`, capped at 2) cover the audit's design-violation → fix → re-audit cycle. Mixing the counters would let a feature that's functionally fine but design-broken consume the functional-retry budget (or vice versa). Keeping them separate means the user sees two distinct failure modes with two distinct remediation paths.

**No persistent manifest field**: `AUDIT_RETRY_COUNT` is ephemeral (lives in this bash loop only). The persistent record of audit attempts is the file count at `.harness/design/audits/audit-${FEATURE_ID}-N.md` (max(N) = total attempts ever for this feature, including failed retries). This avoids adding a new manifest schema field per the v1 Step 3 constraint.

**If the auto-loop exits with cap-reached and user picks "force-merge"**: proceed to 5a-pre (tuning check) and onward to merge. The audit report stays on disk under `.harness/design/audits/` as the permanent record; the merge happens with known P0s.

**If the auto-loop exits with cap-reached and user picks "manually fix and resume"**: halt the sprint. The user fixes manually, then runs `/harness:resume` which picks up from the evaluating phase (existing resume behaviour); on next functional PASS the auto-loop re-fires. (The audit-retry counter starts at 0 in the new sprint dispatch — it's per-dispatch ephemeral.)

After the auto-loop exits cleanly (P0 = 0) OR with cap+force-merge, control falls through to **5a-pre. Tuning check** below.

---

**5a-pre. Tuning check — capture human-Evaluator divergence (automatic)**

This implements the Anthropic-documented tuning loop. Present the Evaluator's judgment to the user:

```
═══════════════════════════════
  Harness — Evaluator Judgment Check
═══════════════════════════════
Verdict: PASS
Scores: F:X/10  Q:X/10  T:X/10  P:X/10
Critical findings: [N]  (titles)
Major findings: [N]   (titles)

Do you agree with this evaluation?
  1. Agree — proceed
  2. Disagree — flag specific divergences
  3. Partial — some findings right, some wrong
═══════════════════════════════
```

- **Agree** → skip to retrospective.
- **Disagree/Partial** → enter divergence capture: for each divergence, record what Evaluator said, what the user thinks, and why. Append to `.harness/evaluator/tuning-log.md`. Ask if this should become a calibration example → if yes, append to `.harness/evaluator/examples.md`; if project-specific, append to `.harness/spec/evaluator-notes.md`.
- Check for pattern emergence: if any divergence category has ≥3 entries in tuning-log.md, tell the user: "Pattern detected: [category] has diverged [N] times. Consider `/harness:tune-evaluator`."
- Proceed to retrospective regardless.

**5a. Retrospective — drift analysis (MANDATORY)**

Run `/harness:retrospective` (see retrospective.md). Writes `.harness/features/${FEATURE}/retrospective.md`. Present drift findings to user. On approval, update spec files + ADR.

If the retrospective itself fails (subagent errors, malformed output), do NOT silently skip. Block merge, write a stub retrospective.md noting the failure, ask the user to retry / run manually / merge-without-retro with explicit confirmation.

**5b. Merge**

```bash
git checkout main
git merge --squash "harness/build/${FEATURE}"
git commit -m "[harness:merge] ${FEATURE}: [one-line summary]"
git worktree remove .worktrees/current 2>/dev/null
```

Then the orchestrator (via Edit tool) updates:
- `ROADMAP.md` — move feature to "✅ Shipped".
- `.harness/manifest.yaml` — `features.completed` append, `features.in_progress = ""`, `state.current_feature = ""` (Agent 3 M3: clear current_feature on merge so the next sprint's audit gate doesn't reuse the just-merged feature-id), `state.phase = "complete"`, `state.retry_count = 0`, `state.design_reroll_round = 0` (TIER A5: reset reroll counter — a new sprint starts fresh).

Print scores + completion message. If the auto-audit-gate ran (i.e., `.harness/design/` was present), the completion message also surfaces: total audit attempts (max(N) of `audit-${FEATURE_ID}-N.md`), final audit verdict (PASS / FAIL — force-merged), and any P1+ findings that were logged for later. If the gate did not run (no `.harness/design/`), the completion message is unchanged from v2.2.

### If FAIL and retries < max

Orchestrator updates `manifest.yaml` → `state.retry_count += 1`, `state.phase = "building"`. Prints failing scores + critical findings. Auto-loops back to Step 3 (BUILD dispatch).

Before retry: run the same tuning check from 5a-pre, but with the reversed framing: "Do you agree the Evaluator should have failed this?" Log divergences. Proceed to retry regardless.

### If FAIL and retries ≥ max

Present the user with options:
1. Force merge with known issues.
2. Manually fix and re-run `/harness:resume` (picks up from evaluating phase).
3. Increase `config.max_retries` and continue.
4. Abandon.

---

## Constraints

- Evaluator MUST be a separate subagent from Generator (GAN isolation).
- All artifacts go in `.harness/features/NNN-name/`.
- Atomic commits on the build branch: `[harness:<phase>] <description>`.
- Subagents are workers, not managers — they NEVER re-invoke the harness pipeline.
- Orchestrator does NOT edit spec files directly (see SKILL.md § File Ownership Contract). Use `/harness:amend`, `/harness:edit`, `/harness:clarify`, or `/harness:constitution-amend`.
