#!/usr/bin/env bash
# BELCORT Harness — Component-as-Assumption Stress Test (FR-5)
#
# Operationalises Rajasekaran 2026: "every component in a harness encodes an
# assumption about what the model can't do on its own, and those assumptions are
# worth stress testing... removing one component at a time and reviewing what
# impact it had."
#
# Usage:
#   assumption-test.sh --component <name> --canary <dir> --output <dir>
#       Set up a "without component X" run. Prints what to do (manual or auto).
#
#   assumption-test.sh --compare --baseline <eval-report.md> --without <eval-report.md> \
#                      --component <name> [--output <verdict.json>]
#       Compare two eval-reports, classify the verdict, write JSON.
#
# Exit codes:
#   0 — success (auto-disable applied OR comparison written)
#   1 — usage or argument error
#   2 — manual step required (component can't be auto-disabled in v1.5);
#        instructions printed to stderr, follow them and re-invoke --compare
#   3 — comparison failed (could not parse one of the eval-reports)
#
# Verdict thresholds (configurable via env):
#   ASSUMPTION_TEST_LOAD_BEARING_DELTA   default 2  (any criterion drops by N+ → LOAD-BEARING)
#   ASSUMPTION_TEST_MARGINAL_DELTA       default 1  (any criterion drops by N+ → MARGINAL; below threshold = OBSOLETE)
#   Also: any new CRITICAL → LOAD-BEARING; any new MAJOR (no new CRITICAL) → MARGINAL.

set -u

LOAD_DELTA="${ASSUMPTION_TEST_LOAD_BEARING_DELTA:-2}"
MARGINAL_DELTA="${ASSUMPTION_TEST_MARGINAL_DELTA:-1}"

MODE=""
COMPONENT=""
CANARY=""
OUTPUT=""
BASELINE=""
WITHOUT=""

# ─────────────────────────────────────────────────────────────
# Arg parse
# ─────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --component) COMPONENT="$2"; shift 2 ;;
    --canary)    CANARY="$2"; shift 2 ;;
    --output)    OUTPUT="$2"; shift 2 ;;
    --baseline)  BASELINE="$2"; shift 2 ;;
    --without)   WITHOUT="$2"; shift 2 ;;
    --compare)   MODE="compare"; shift ;;
    --help|-h)
      sed -n '4,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -z "$MODE" ] && [ -n "$CANARY" ] && MODE="setup"

# ─────────────────────────────────────────────────────────────
# Per-component: how to run "without" mode
# ─────────────────────────────────────────────────────────────
component_disable_strategy() {
  local comp="$1"
  case "$comp" in
    brainstorm)
      cat <<EOF
auto:env
SKIP_BRAINSTORM=1
Skips sprint.md step 0a (brainstorm check). Run:
  SKIP_BRAINSTORM=1 /harness:sprint "<canary prompt>"
EOF
      ;;
    negotiation)
      cat <<EOF
manual:plugin-copy
Negotiation is multi-step (proposal → review → finalize) — env-var skip would leave the
contract un-negotiated. To disable cleanly, copy the plugin and patch sprint.md to skip step 2c:
  cp -r "\${CLAUDE_PLUGIN_ROOT}" /tmp/harness-no-neg
  sed -i.bak 's/### 2c\. NEGOTIATE/### 2c. NEGOTIATE [DISABLED]/' /tmp/harness-no-neg/commands/sprint.md
  CLAUDE_PLUGIN_ROOT=/tmp/harness-no-neg /harness:sprint "<canary prompt>"
EOF
      ;;
    two-stage-eval)
      cat <<EOF
manual:plugin-copy
Two-stage eval (Part A binary, Part B numeric) is in agents/evaluator.md Step 6. To disable:
  cp -r "\${CLAUDE_PLUGIN_ROOT}" /tmp/harness-no-2stage
  # In /tmp/harness-no-2stage/agents/evaluator.md, comment out Step 6 PART A section
  # (manually — sed across markdown is fragile)
  CLAUDE_PLUGIN_ROOT=/tmp/harness-no-2stage /harness:sprint "<canary prompt>"
EOF
      ;;
    red-flags)
      cat <<EOF
manual:plugin-copy
RED FLAGS sections are in all three agent prompts. Strip them programmatically:
  cp -r "\${CLAUDE_PLUGIN_ROOT}" /tmp/harness-no-redflags
  for f in /tmp/harness-no-redflags/agents/*.md; do
    awk '/^## RED FLAGS/{skip=1} /^---$/ && skip{skip=0; next} !skip' "\$f" > "\$f.tmp" && mv "\$f.tmp" "\$f"
  done
  CLAUDE_PLUGIN_ROOT=/tmp/harness-no-redflags /harness:sprint "<canary prompt>"
EOF
      ;;
    calibration-examples)
      cat <<EOF
auto:env
SKIP_CALIBRATION_EXAMPLES=1
Evaluator dispatch context excludes examples.md. The Evaluator's prompt still references
examples.md but the file is empty for this run. Run:
  # Setup: temporarily backup examples.md
  cp .harness/evaluator/examples.md .harness/evaluator/examples.md.assumption-test-backup
  : > .harness/evaluator/examples.md
  /harness:sprint "<canary prompt>"
  # Restore after the run:
  mv .harness/evaluator/examples.md.assumption-test-backup .harness/evaluator/examples.md
EOF
      ;;
    reward-hacking-scan)
      cat <<EOF
auto:env
SKIP_REWARD_HACKING=1
Evaluator's Step 4.5 git-archaeology scan. The Evaluator agent reads this env var and
skips the scan. Run:
  SKIP_REWARD_HACKING=1 /harness:sprint "<canary prompt>"
EOF
      ;;
    analyze)
      cat <<EOF
auto:env
SKIP_ANALYZE=1
Sprint.md step 2b is the cross-artifact consistency check. Run:
  SKIP_ANALYZE=1 /harness:sprint "<canary prompt>"
EOF
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────
# Setup mode: print disable strategy for the named component
# ─────────────────────────────────────────────────────────────
if [ "$MODE" = "setup" ]; then
  [ -z "$COMPONENT" ] && { echo "--component required for setup" >&2; exit 1; }
  [ -z "$CANARY" ]    && { echo "--canary required for setup" >&2; exit 1; }
  [ -z "$OUTPUT" ]    && { echo "--output required for setup" >&2; exit 1; }

  STRATEGY=$(component_disable_strategy "$COMPONENT")
  if [ "$STRATEGY" = "unsupported" ]; then
    echo "Unsupported component: $COMPONENT" >&2
    echo "Supported: brainstorm negotiation two-stage-eval red-flags calibration-examples reward-hacking-scan analyze" >&2
    exit 1
  fi

  KIND=$(printf '%s\n' "$STRATEGY" | head -1 | awk -F: '{print $2}')
  REST=$(printf '%s\n' "$STRATEGY" | tail -n +2)

  mkdir -p "$OUTPUT"

  echo "═══════════════════════════════"
  echo "  Assumption Test — Setup for: $COMPONENT"
  echo "═══════════════════════════════"
  echo ""
  printf '%s\n' "$REST"
  echo ""
  echo "After the canary sprint completes, copy its eval-report to $OUTPUT/eval-report.md,"
  echo "then run this script with --compare to get the verdict:"
  echo ""
  echo "  bash $0 --compare \\"
  echo "    --baseline <path-to-baseline-eval-report.md> \\"
  echo "    --without  $OUTPUT/eval-report.md \\"
  echo "    --component $COMPONENT \\"
  echo "    --output   $OUTPUT/../verdict.json"
  echo ""

  if [ "$KIND" = "env" ]; then
    exit 0  # auto strategy — user can run inline
  else
    exit 2  # manual strategy — user must follow instructions before --compare
  fi
fi

# ─────────────────────────────────────────────────────────────
# Compare mode: parse two eval-reports, classify verdict
# ─────────────────────────────────────────────────────────────
if [ "$MODE" = "compare" ]; then
  [ -z "$BASELINE" ]  && { echo "--baseline required for compare" >&2; exit 1; }
  [ -z "$WITHOUT" ]   && { echo "--without required for compare" >&2; exit 1; }
  [ -z "$COMPONENT" ] && { echo "--component required for compare" >&2; exit 1; }
  [ -f "$BASELINE" ]  || { echo "Baseline eval-report not found: $BASELINE" >&2; exit 3; }
  [ -f "$WITHOUT" ]   || { echo "Without eval-report not found: $WITHOUT" >&2; exit 3; }

  # Extract scores from "Part B — Quality Scoring" table
  # Format expected: | Functionality | X/10 | 6 | PASS/FAIL |
  extract_score() {
    local file="$1" criterion="$2"
    grep -E "^\| *${criterion}" "$file" 2>/dev/null \
      | head -1 | awk -F'|' '{gsub(/[ \/]/,"",$3); print $3+0}' | head -c 4
  }

  count_findings() {
    local file="$1" prefix="$2"   # prefix = "C" for critical, "M" for major
    grep -cE "^### ${prefix}[0-9]+:" "$file" 2>/dev/null
  }

  BASE_FN=$(extract_score "$BASELINE" "Functionality")
  BASE_CQ=$(extract_score "$BASELINE" "Code Quality")
  BASE_TC=$(extract_score "$BASELINE" "Test Coverage")
  BASE_PD=$(extract_score "$BASELINE" "Product Depth")
  BASE_C=$(count_findings "$BASELINE" "C")
  BASE_M=$(count_findings "$BASELINE" "M")

  WITH_FN=$(extract_score "$WITHOUT" "Functionality")
  WITH_CQ=$(extract_score "$WITHOUT" "Code Quality")
  WITH_TC=$(extract_score "$WITHOUT" "Test Coverage")
  WITH_PD=$(extract_score "$WITHOUT" "Product Depth")
  WITH_C=$(count_findings "$WITHOUT" "C")
  WITH_M=$(count_findings "$WITHOUT" "M")

  # Defaults if extraction failed (eval-report wasn't structured as expected)
  for v in BASE_FN BASE_CQ BASE_TC BASE_PD WITH_FN WITH_CQ WITH_TC WITH_PD; do
    eval "[ -z \"\${$v:-}\" ] && $v=0"
  done

  D_FN=$((BASE_FN - WITH_FN))
  D_CQ=$((BASE_CQ - WITH_CQ))
  D_TC=$((BASE_TC - WITH_TC))
  D_PD=$((BASE_PD - WITH_PD))
  D_C=$((WITH_C - BASE_C))
  D_M=$((WITH_M - BASE_M))

  MAX_DEGRADE=$D_FN
  for d in $D_CQ $D_TC $D_PD; do
    [ "$d" -gt "$MAX_DEGRADE" ] && MAX_DEGRADE=$d
  done

  VERDICT="OBSOLETE"
  RATIONALE="No criterion degraded by ≥${MARGINAL_DELTA} and no new findings — $COMPONENT did not earn its keep on this canary."

  if [ "$D_C" -gt 0 ] || [ "$MAX_DEGRADE" -ge "$LOAD_DELTA" ]; then
    VERDICT="LOAD-BEARING"
    if [ "$D_C" -gt 0 ]; then
      RATIONALE="Removing $COMPONENT introduced $D_C new CRITICAL finding(s). Component is load-bearing."
    else
      RATIONALE="Removing $COMPONENT degraded a criterion by ${MAX_DEGRADE} points (threshold ${LOAD_DELTA}). Component is load-bearing."
    fi
  elif [ "$D_M" -gt 0 ] || [ "$MAX_DEGRADE" -ge "$MARGINAL_DELTA" ]; then
    VERDICT="MARGINAL"
    RATIONALE="Removing $COMPONENT degraded by ${MAX_DEGRADE} points (or +$D_M MAJOR findings). Component is marginal — re-test on a different canary before deciding to remove."
  fi

  # Emit JSON
  JSON=$(printf '{
  "component": "%s",
  "baseline": { "fn": %s, "cq": %s, "tc": %s, "pd": %s, "critical": %s, "major": %s },
  "without":  { "fn": %s, "cq": %s, "tc": %s, "pd": %s, "critical": %s, "major": %s },
  "delta":    { "fn": %s, "cq": %s, "tc": %s, "pd": %s, "critical": %s, "major": %s },
  "verdict": "%s",
  "rationale": "%s"
}\n' \
    "$COMPONENT" \
    "$BASE_FN" "$BASE_CQ" "$BASE_TC" "$BASE_PD" "$BASE_C" "$BASE_M" \
    "$WITH_FN" "$WITH_CQ" "$WITH_TC" "$WITH_PD" "$WITH_C" "$WITH_M" \
    "$D_FN" "$D_CQ" "$D_TC" "$D_PD" "$D_C" "$D_M" \
    "$VERDICT" "$RATIONALE")

  if [ -n "$OUTPUT" ]; then
    printf '%s\n' "$JSON" > "$OUTPUT"
    echo "Verdict written to $OUTPUT"
  fi
  printf '%s\n' "$JSON"
  exit 0
fi

echo "Usage: $0 (--component X --canary D --output O) | (--compare --baseline B --without W --component X)" >&2
exit 1
