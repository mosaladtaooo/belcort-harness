---
description: Component-as-assumption stress test (Rajasekaran 2026). Run a canary sprint WITH and WITHOUT a named harness component (brainstorm, negotiation, two-stage-eval, red-flags, calibration-examples, reward-hacking-scan, analyze). Compares eval scores + critical findings + token cost. Outputs verdict — LOAD-BEARING, MARGINAL, OBSOLETE — to inform whether the component is still earning its keep as model capability evolves. Quarterly cadence recommended.
argument-hint: "<component-name>"
---

# `/harness:assumption-test` — Component-as-assumption stress test

Operationalises the direct prescription from Rajasekaran 2026:

> *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing... removing one component at a time and reviewing what impact it had."*

As Claude improves (Opus 4.7, future versions), some harness components silently become dead weight; others may grow more important. Without periodic stress-testing, the harness accumulates obsolete machinery. This command is the meta-process that prevents that.

**Cadence**: quarterly. Each test runs a canary sprint twice — it's expensive. Don't run it more than once per component per quarter unless you have a specific reason.

## Supported components

The component name is `$ARGUMENTS`. Supported (v1.5 initial set):

| Component | What it does in the harness | "Without" mode |
|---|---|---|
| `brainstorm` | Pre-plan exploration phase for vague prompts | Skips `/harness:brainstorm` step in sprint.md step 0a |
| `negotiation` | Generator↔Evaluator agree on contract before code | Generator goes straight from draft contract to BUILD |
| `two-stage-eval` | Evaluator's Part A (binary compliance) gates Part B (numeric scoring) | Evaluator does single-pass numeric scoring only |
| `red-flags` | Adversarial RED FLAGS sections in each agent prompt | RED FLAGS sections temporarily stripped from agent dispatches |
| `calibration-examples` | Evaluator reads examples.md before scoring | Evaluator dispatch context excludes examples.md |
| `reward-hacking-scan` | Evaluator's Step 4.5 git-archaeology scan | Evaluator skips Step 4.5 |
| `analyze` | Cross-artifact consistency check between PRD/architecture/contract | Sprint skips step 2b |

If `$ARGUMENTS` is not in the supported list, exit with the list above as the suggested set.

## Why a canary spec (not a real project)

A canary spec is a small, deterministic sprint definition that the harness can run reproducibly. Stored at `.harness/canary/<canary-name>/` with:
- `prompt.txt` — the user request
- `expected-frs.txt` — what FRs the Planner should produce (baseline reference)
- `expected-min-scores.txt` — minimum scores per criterion that a healthy run produces

The user supplies the canary path. There is no shipped default canary in v1.5 — the F13 "self-test canary" gap is explicit non-goal. Recommended canaries:
- A previous successful sprint from this project (rerun it as canary)
- A toy spec like "build a 2-FR todo app" (deterministic, fast)
- A representative slice of upcoming work

## Procedure

### Step 1: Validate inputs

```bash
COMPONENT="$ARGUMENTS"
SUPPORTED="brainstorm negotiation two-stage-eval red-flags calibration-examples reward-hacking-scan analyze"
case " $SUPPORTED " in
  *" $COMPONENT "*) ;;
  *) echo "Unsupported component: $COMPONENT"; echo "Supported: $SUPPORTED"; exit 1 ;;
esac
```

Ask the user for the canary path:

```
Path to canary directory (must contain prompt.txt + expected-frs.txt + expected-min-scores.txt):
```

Validate the canary directory has the three required files. If not, exit with the format spec.

### Step 2: Run baseline (component active)

Tell the user:

```
═══════════════════════════════
  Harness — Assumption Test (Baseline Run)
═══════════════════════════════
Component under test: $COMPONENT
Canary: <path>

About to run /harness:sprint with the canary prompt and the FULL harness
(component active). This may take 10–30 minutes depending on canary size.

Press Enter to start, or Ctrl-C to abort.
```

After the user confirms, run:

```bash
CANARY_DIR="<user-supplied path>"
BASELINE_DIR=".harness/.assumption-test/baseline-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BASELINE_DIR"

# Run the canary as a normal sprint, capturing the eval-report
PROMPT=$(cat "$CANARY_DIR/prompt.txt")
# (orchestrator dispatches /harness:sprint "$PROMPT" against a clean .harness/ scratch dir)

# Copy the resulting eval-report to BASELINE_DIR for later comparison
cp .harness/features/*/eval-report.md "$BASELINE_DIR/eval-report.md"
# Capture token usage if available (claude -p output may include it; parse from stdout log)
```

### Step 3: Run modified harness (component removed)

The script `scripts/assumption-test.sh` knows how to disable each component. For env-var-driven components (`brainstorm`, `analyze`, `negotiation`, `calibration-examples`, `reward-hacking-scan`), it sets the appropriate env var and re-runs the sprint. For prompt-modifying components (`red-flags`, `two-stage-eval`), it creates a temporary plugin copy with the relevant sections stripped.

```bash
WITHOUT_DIR=".harness/.assumption-test/without-$(date +%Y%m%d%H%M%S)"
mkdir -p "$WITHOUT_DIR"

bash "${CLAUDE_PLUGIN_ROOT}/scripts/assumption-test.sh" \
  --component "$COMPONENT" \
  --canary "$CANARY_DIR" \
  --output "$WITHOUT_DIR"
```

For components the v1.5 script can't fully automate, it prints clear manual instructions and exits with code 2 — the user follows the instructions, then re-invokes with the resulting eval-report path.

### Step 4: Compare and verdict

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/assumption-test.sh" \
  --compare \
  --baseline "$BASELINE_DIR/eval-report.md" \
  --without "$WITHOUT_DIR/eval-report.md" \
  --component "$COMPONENT" \
  --output "$BASELINE_DIR/../verdict.json"
```

The script produces a JSON verdict:

```json
{
  "component": "negotiation",
  "canary": "/path/to/canary",
  "baseline": { "fn": 8, "cq": 7, "tc": 8, "pd": 7, "critical": 0, "major": 1 },
  "without":  { "fn": 6, "cq": 7, "tc": 5, "pd": 7, "critical": 1, "major": 3 },
  "delta":    { "fn": -2, "cq": 0, "tc": -3, "pd": 0, "critical": +1, "major": +2 },
  "verdict": "LOAD-BEARING",
  "rationale": "Removing negotiation degraded Test Coverage by 3 points and introduced a CRITICAL finding. Component is still earning its keep on this canary."
}
```

Verdict thresholds (configurable in script):
- `LOAD-BEARING`: any criterion drops ≥2 points OR critical findings increase
- `MARGINAL`: criterion drops by 1 OR major findings increase
- `OBSOLETE`: no degradation across criteria, findings, or token cost

### Step 5: Present + ADR

Show the verdict to the user with the rationale. Then:

```
═══════════════════════════════
  Verdict: $VERDICT
═══════════════════════════════
$RATIONALE

Decisions to log:
  1. Keep $COMPONENT active (current default)
  2. Remove $COMPONENT from the harness (v1.6 change)
  3. Defer — re-test on a different canary first
  4. Re-test now with a different canary
═══════════════════════════════
```

Whatever the user picks, append a mandatory ADR to `progress/decisions.md`:

```
## ADR-NNN — Assumption test: $COMPONENT
**Date**: YYYY-MM-DD
**Canary**: <path>
**Verdict**: $VERDICT
**Rationale**: <from verdict>
**Decision**: <what user picked>

### Baseline vs without (per-criterion delta)
- Functionality: <baseline>/10 → <without>/10 (Δ <delta>)
- Code Quality:  ...
- Test Coverage: ...
- Product Depth: ...
- Critical findings: <baseline> → <without>
- Major findings:    <baseline> → <without>
```

Update `manifest.yaml`:

```yaml
harness:
  last_assumption_test:
    date: "<ISO>"
    component: "$COMPONENT"
    canary: "<path>"
    verdict: "$VERDICT"
```

This field is surfaced by `/harness:audit` to remind the user which components are due for retesting.

## Anti-patterns

- **Single canary verdict drives a permanent removal decision.** A component that looks obsolete on a tiny canary may be load-bearing on real complex work. Always retest with at least one production-representative canary before removing a component.
- **Skipping the ADR.** The whole point is auditability — without the ADR the decision is invisible six months later and re-litigated.
- **Running on every component back-to-back.** Each test costs a sprint. Pick the most-suspected component, run it, decide, then move on.
- **Treating MARGINAL as license to remove.** MARGINAL means *small degradation observed*, not "no harm." Move it to LOAD-BEARING in the next test or remove cautiously.
- **Mixing canary results across runs of different model versions.** A component obsolete on Opus 4.7 may have been load-bearing on 4.6. Note the model version in the ADR.

## Files written

| File | Writer | Lifetime |
|---|---|---|
| `.harness/.assumption-test/baseline-<ts>/eval-report.md` | Sprint run (baseline) | kept for comparison record |
| `.harness/.assumption-test/without-<ts>/eval-report.md` | Modified sprint run | kept for comparison record |
| `.harness/.assumption-test/verdict.json` | `assumption-test.sh --compare` | kept |
| `progress/decisions.md` | Orchestrator appends ADR | append-only |
| `manifest.yaml → harness.last_assumption_test` | Orchestrator | overwritten per test |

## v1.5 limitations (explicit)

- The full A/B automation is **partial** in v1.5 — env-var-driven components (`brainstorm`, `analyze`, `calibration-examples`, `reward-hacking-scan`) work end-to-end via the script. Prompt-modifying components (`red-flags`, `two-stage-eval`, `negotiation`) require a temporary plugin copy; the script generates the copy and prints `CLAUDE_PLUGIN_ROOT=<temp>` for the user to use.
- No shipped canary corpus — bring your own. F13 (self-test canary) is the natural follow-up.
- Token-cost comparison is best-effort and depends on `claude -p` emitting usage info to stdout. The verdict still works without it; cost just doesn't appear in the delta.

## Files written

The script writes everything to `.harness/.assumption-test/` (gitignored by default — add to `.gitignore` if not already). The ADR in `progress/decisions.md` is the durable record.
