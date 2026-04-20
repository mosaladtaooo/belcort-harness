---
description: High-ceremony constitution amendment (FR-6). Constitution is immutable post-init by default — this command is the ONE authorized path to change it. Requires typed confirmation, ≥50-char reason, in-progress feature handling, mandatory ADR, AND a re-validation pass against every completed feature. Use when a real need arises (post-incident security rule, scope drift, regulatory change). Adopted from SpecKit's explicit constitutional governance pattern.
argument-hint: "<reason for the amendment, ≥50 chars>"
---

# `/harness:constitution-amend` — High-ceremony constitution change

The constitution (`spec/constitution.md`) is the architectural DNA of the project — every Generator decision, every Evaluator score, every refactor traces back to it. The harness's default is `immutable post-init` because casual amendments cascade into spec drift across every feature ever shipped.

But "immutable" is too rigid for real projects. Sometimes you need to:
- Add a security principle after a real incident (e.g., "all PII fields MUST be encrypted at rest")
- Adjust to a regulatory change (e.g., "all data exports MUST log the requesting user")
- Resolve a scope drift the original constitution couldn't anticipate (e.g., constitution forbade websockets but PRD now requires real-time)

This command is the ONE authorized path. It's deliberately ceremonious — the friction is the feature, not the bug. Every gate exists to make sure you're amending for a real reason and propagating the change correctly.

## Why so much ceremony

SpecKit calls the constitution *"the architectural DNA of the system, ensuring that every generated implementation maintains consistency, simplicity, and quality."* Casual edits break that property. The five ceremony stages exist because:

1. **Typed confirmation** — forces deliberate intent (no auto-pilot)
2. **≥50-char reason** — forces explanation that becomes the ADR
3. **In-progress handling** — surfaces the cost (current feature halts or ships under old rules)
4. **Mandatory ADR** — leaves an audit trail; future contributors can read why
5. **Re-validation against completed features** — catches the case where past work no longer complies

Without all five, the constitution becomes prose-immutable but practically mutable, which is the worst of both worlds.

## Procedure

### Step 0: Pre-flight gates (CEREMONY)

```bash
REASON="$ARGUMENTS"

# Gate 1: reason length (forces explanation)
if [ ${#REASON} -lt 50 ]; then
  echo "❌ Amendment reason must be ≥50 chars (got ${#REASON})."
  echo "   The reason becomes the ADR — it must explain *why*, not just *what*."
  echo "   Try again with: /harness:constitution-amend \"<longer explanation of why>\""
  exit 1
fi

# Gate 2: typed confirmation (forces deliberate intent)
echo ""
echo "═══════════════════════════════"
echo "  CONSTITUTION AMENDMENT — high ceremony"
echo "═══════════════════════════════"
echo ""
echo "You are about to amend .harness/spec/constitution.md — the architectural"
echo "DNA of this project. Every prior feature was built against the current"
echo "constitution. Amending it requires re-validating each completed feature."
echo ""
echo "Reason (will become the ADR):"
echo "  ${REASON}"
echo ""
echo "To proceed, type the following EXACTLY (case-sensitive):"
echo ""
echo "  I-AM-AMENDING-THE-CONSTITUTION"
echo ""
read -r CONFIRM
if [ "$CONFIRM" != "I-AM-AMENDING-THE-CONSTITUTION" ]; then
  echo "❌ Confirmation string did not match. Aborted."
  exit 1
fi

# Gate 3: in-progress feature handling
IN_PROGRESS=$(grep -A1 '^features:' .harness/manifest.yaml | grep 'in_progress:' | awk -F: '{print $2}' | tr -d '" ')
if [ -n "$IN_PROGRESS" ]; then
  echo ""
  echo "⚠ Feature in progress: ${IN_PROGRESS}"
  echo ""
  echo "The current feature was negotiated against the EXISTING constitution."
  echo "Amending mid-feature creates divergence between the contract the"
  echo "Generator agreed to and the constitution it must comply with."
  echo ""
  echo "Choose one:"
  echo "  1. Finish ${IN_PROGRESS} under the OLD constitution, then apply"
  echo "     amendment + re-validate (recommended)"
  echo "  2. Halt ${IN_PROGRESS} now, apply amendment + re-validate, then"
  echo "     restart the feature against the NEW constitution"
  echo "  3. Abandon the amendment"
  echo ""
  read -r CHOICE
  case "$CHOICE" in
    1) echo "Acknowledged. /harness:constitution-amend will finish current feature first then resume."; exit 0 ;;
    3) echo "Amendment abandoned."; exit 0 ;;
    2) ;;  # continue to phase guard + dispatch
    *)  echo "Invalid choice. Aborted."; exit 1 ;;
  esac
fi
```

### Step 1: Phase guard (FR-2)

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_set "constitution-amending"
```

The FR-2 spec-ownership hook authorizes constitution.md edits only during this phase. Restored at Step Final.

### Step 2: Dispatch Planner in CONSTITUTION-AMEND mode

The Planner reads the current constitution + the proposed change, identifies which principle is being added/changed/removed, and produces structured before→after patches. **It does NOT auto-apply.**

```bash
CLAUDE_SUBAGENT=1 claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/planner.md)
--- MODE: CONSTITUTION-AMEND ---
--- AMENDMENT REASON ---
${REASON}
--- CONTEXT ---
$(cat .harness/spec/prd.md)
$(cat .harness/spec/architecture.md)
$(cat .harness/spec/constitution.md)
$(ls -1 .harness/features/*/contract.md 2>/dev/null | head -10 | xargs cat)" \
  --allowedTools "Read,Write,mcp__context7"
```

The Planner writes to `.harness/constitution-amend-patches.md` (top-level, not per-feature — constitution amendments are global).

### Step 3: Read patches, present to user

```
═══════════════════════════════
  Harness — Constitution Amendment Preview
═══════════════════════════════
Reason: ${REASON}

Planner's interpretation:
  [1-3 sentence summary]

Principle being amended:
  • [§N: principle name — added | changed | removed]

Impact assessment:
  • Affects principles: [list of §-numbers]
  • Affects completed features (count): [N]
  • Affects in-progress feature: [yes/no]

Patches:
  [1] spec/constitution.md § N — [diff preview]

Apply / Cancel?
═══════════════════════════════
```

If user cancels: phase_restore + exit, leaving patches on disk for record.

### Step 4: Mandatory ADR

Even if the user proceeds, append the ADR to `progress/decisions.md` BEFORE applying. The ADR documents the *intent* — even if the user backs out at Step 5 or 6, we have the record.

```
## ADR-NNN — Constitution amendment: [short title]
**Date**: YYYY-MM-DD
**Status**: Proposed (will become Accepted on apply)

### Context
${REASON}

### Decision
Constitution amended:
- Principle §N: [added | changed | removed]
- Before: [quote from current constitution]
- After: [quote from new text]

### Consequences
- All FUTURE features negotiated against the new constitution
- Completed features re-validated (see revalidation reports below)
- In-progress feature: [policy chosen at Step 0 Gate 3]
```

### Step 5: Re-validation pass — Evaluator REVALIDATE mode per completed feature

For EACH completed feature in `manifest.features.completed`, dispatch the Evaluator in REVALIDATE mode against the new constitution. The Evaluator reads the feature's source code + contract + the new constitution, and produces a per-principle compliance report.

```bash
NEW_CONSTITUTION_PATH=".harness/spec/constitution.md.proposed"   # patches not yet applied
# Apply the patches to a TEMP copy first so revalidation tests the proposed state
cp .harness/spec/constitution.md "$NEW_CONSTITUTION_PATH"
# (orchestrator applies the proposed patches to the temp copy via Edit)

REVALIDATION_DIR=".harness/.revalidation-$(date +%Y%m%d%H%M%S)"
mkdir -p "$REVALIDATION_DIR"

COMPLETED=$(awk '/^features:/{f=1} f && /completed:/,/^[a-z]/' .harness/manifest.yaml \
              | grep -E '^[[:space:]]*-' | sed 's/^[[:space:]]*-[[:space:]]*//' | tr -d '"')

for FEATURE in $COMPLETED; do
  echo "Re-validating ${FEATURE}..."

  CLAUDE_SUBAGENT=1 claude -p "$(cat ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/agents/evaluator.md)
--- MODE: REVALIDATE ---
You are NOT running EVALUATE. You are checking whether a previously-shipped feature
still complies with a NEWLY AMENDED constitution. Read the new constitution, the
completed feature's source code, and produce a per-principle compliance report.

Output to .harness/.revalidation-<ts>/${FEATURE}.md:
  - Each principle § from the NEW constitution: PASS | FAIL | N/A
  - For FAIL: which file/line violates, what would need to change
  - Summary: how many principles fail, are any blocking?
--- NEW CONSTITUTION (proposed) ---
$(cat ${NEW_CONSTITUTION_PATH})
--- FEATURE CONTRACT ---
$(cat .harness/features/${FEATURE}/contract.md)
--- FEATURE EVAL REPORT ---
$(cat .harness/features/${FEATURE}/eval-report.md)
--- INSTRUCTION ---
Use Read on src/ to inspect actual code. Do NOT run Playwright — this is a static
constitutional audit, not functional retesting." \
    --allowedTools "Read,Write,Bash"

  cp ".harness/.revalidation-*/${FEATURE}.md" "$REVALIDATION_DIR/${FEATURE}.md" 2>/dev/null
done
```

### Step 6: Present revalidation summary, per-feature decision

```
═══════════════════════════════
  Harness — Re-validation Summary
═══════════════════════════════
Constitution amendment under review (not yet applied).

Completed features evaluated: [N]

Compliance results:
  ✓ FEATURE-001 — fully compliant with new constitution
  ⚠ FEATURE-002 — 1 principle FAIL: [§N description]
                  → Decision needed: backport (add to ROADMAP) | grandfather (document exception)
  ✗ FEATURE-003 — 3 principle FAILs: [list]
                  → Decision needed: backport | grandfather (3 exceptions)

For each feature with FAILs:
  - Backport → Adds tasks to ROADMAP.md under "Constitutional debt"
  - Grandfather → Adds an explicit exception to progress/decisions.md
                  (audit trail: "FEATURE-X exempt from §N because <reason>")

Per-feature decision (1=backport, 2=grandfather, 3=re-evaluate):
═══════════════════════════════
```

After collecting decisions, write them to `progress/decisions.md` as ADR follow-ups (each decision is its own line item under the parent amendment ADR).

### Step 7: Apply patches

Only NOW does the orchestrator apply the patches to the real `spec/constitution.md`.

```bash
# Apply each patch from constitution-amend-patches.md to spec/constitution.md
# (mechanical Edit tool calls, same pattern as /harness:amend Step 4)

# Update manifest amendment history
# (orchestrator appends to constitution.amendments list in manifest.yaml)

# Mark the parent ADR as Accepted (was Proposed)

# Clean up the proposed-state temp file
rm -f "$NEW_CONSTITUTION_PATH"
```

### Step 8: Update changelog

```
## YYYY-MM-DD — Global — Constitution amended
- Reason: "${REASON}"
- ADR: ADR-NNN
- Affected principles: [§-numbers]
- Re-validation results: [N compliant, N backport, N grandfather]
```

### Step Final: Restore phase

```bash
source "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/harness}/scripts/phase-guard.sh"
phase_restore
```

## Anti-patterns

- **Treating ceremony as obstacle**. The ceremony IS the feature. If you find it annoying, that's a signal you might be amending too casually — let the friction do its job.
- **Skipping re-validation** "because the change is small." Even a small principle change can invalidate past features. The whole point is to catch that systematically.
- **Grandfathering everything to avoid backport work**. Grandfathering is for genuine exceptions (e.g., a feature shipped before the new principle existed and rewriting it would be churn). Routine grandfathering hollows out the constitution — at some point your amendment doesn't actually apply to anything.
- **Amending the constitution to match what the Generator already built**. That's a retrospective concern, not a constitution amendment. Use `/harness:retrospective` to capture *positive drift* into the spec, then re-evaluate whether a constitutional change is justified.
- **Making the constitution looser**. The constitution is supposed to TIGHTEN over time as the project learns. Amendments that loosen a principle should require an even higher bar — explicitly justify why the principle was wrong, not just inconvenient.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `.harness/constitution-amend-patches.md` | Planner CONSTITUTION-AMEND mode | global, kept as record of proposed change |
| `.harness/.revalidation-<ts>/` | Evaluator REVALIDATE mode (one file per completed feature) | kept as audit trail |
| `spec/constitution.md` | Orchestrator applies patches (Step 7) | updated in place |
| `progress/decisions.md` | Orchestrator appends ADR + per-feature decisions | append-only |
| `progress/changelog.md` | Orchestrator appends | append-only |
| `manifest.yaml → constitution.amendments` | Orchestrator | history appended |

## Why this is the SECOND writer of constitution.md

Per SKILL.md File Ownership Contract, the original writer is "Planner Pass 1 only — immutable thereafter." This command is the ONE authorized exception, behind the ceremony gates above. The hook (FR-2) enforces this: writes to `spec/constitution.md` outside `phase=constitution-amending` are blocked.
