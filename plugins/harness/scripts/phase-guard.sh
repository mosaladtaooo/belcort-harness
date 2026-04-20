#!/usr/bin/env bash
# BELCORT Harness — Phase Guard helpers (FR-2)
#
# Spec-edit commands (/harness:amend, /clarify, /edit, /tune-evaluator,
# /retrospective, /constitution-amend) source this script and call:
#
#   phase_set "amending"        # at command start
#   ... do work, including Edit/Write to spec files ...
#   phase_restore                # at command end (success or failure)
#
# The pre-tool-use.sh hook reads state.phase from manifest.yaml and only
# permits orchestrator-side edits to .harness/spec/*, .harness/features/*/
# contract.md, and .harness/evaluator/criteria.md when the phase is in the
# authorized set: amending | clarifying | editing | tuning | retrospective |
# constitution-amending.
#
# Without phase_set, those edits are blocked — which is the entire point of
# FR-2: enforce the file-ownership contract that was previously prose-only.
#
# Idempotent: phase_restore is safe to call multiple times. If no prior phase
# was saved (i.e., phase_set was never called), it's a no-op.

# Internal: portable in-place sed (BSD vs GNU). Writes to .harness/manifest.yaml.
_phase_inplace_replace() {
  local new_phase="$1"
  if command -v gsed >/dev/null 2>&1; then
    gsed -i.bak "s|^\\([[:space:]]*\\)phase:.*|\\1phase: \"${new_phase}\"|" .harness/manifest.yaml
  else
    sed -i.bak "s|^\\([[:space:]]*\\)phase:.*|\\1phase: \"${new_phase}\"|" .harness/manifest.yaml
  fi
  rm -f .harness/manifest.yaml.bak
}

phase_set() {
  local new_phase="$1"
  [ -n "$new_phase" ] || { echo "phase_set: missing phase argument" >&2; return 1; }
  [ -f ".harness/manifest.yaml" ] || { echo "phase_set: no manifest.yaml" >&2; return 1; }

  # Save prior phase so phase_restore can roll back even on script error
  local prior
  prior=$(grep '^[[:space:]]*phase:' .harness/manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')
  printf '%s\n' "$prior" > .harness/.phase-prior

  _phase_inplace_replace "$new_phase"
}

phase_restore() {
  [ -f ".harness/.phase-prior" ] || return 0
  local prior
  prior=$(cat .harness/.phase-prior 2>/dev/null)
  if [ -n "$prior" ] && [ -f ".harness/manifest.yaml" ]; then
    _phase_inplace_replace "$prior"
  fi
  rm -f .harness/.phase-prior
}
