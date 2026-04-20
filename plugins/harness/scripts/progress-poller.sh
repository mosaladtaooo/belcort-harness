#!/usr/bin/env bash
# BELCORT Harness — Subagent Progress Poller
#
# Sourced by /harness:sprint dispatch wrappers. Closes the Trustworthy Agents
# §opacity-at-scale anti-pattern: while the orchestrator blocks on `claude -p`,
# the polled file gives the human a low-overhead live window into what the
# subagent is doing.
#
# Protocol: plugins/harness/agents/_progress-protocol.md
#
# Usage (in a Bash invocation that also runs `claude -p`):
#
#   source "${CLAUDE_PLUGIN_ROOT}/scripts/progress-poller.sh"
#   PROGRESS_FILE=".harness/features/${FEATURE}/_progress.jsonl"
#   start_progress_poller "$PROGRESS_FILE"
#   trap "stop_progress_poller '$PROGRESS_FILE'" EXIT
#
#   claude -p "..."   # the long-running subagent
#
#   stop_progress_poller "$PROGRESS_FILE"
#   trap - EXIT
#
# The poller respects `config.observability.heartbeat` in manifest.yaml.
# When false (or manifest missing), start_progress_poller is a no-op and
# stop_progress_poller is a no-op — silent degradation, no errors.

# ─────────────────────────────────────────────────────────────
# Internal: read heartbeat toggle from manifest
# ─────────────────────────────────────────────────────────────
_progress_heartbeat_enabled() {
  [ -f ".harness/manifest.yaml" ] || return 1
  local v
  v=$(awk '/^[[:space:]]*observability:/{f=1;next} f && /^[[:space:]]*heartbeat:/{gsub(/"/,"",$2); print $2; exit}' \
        .harness/manifest.yaml 2>/dev/null)
  # Default true when key missing — observability is on by default in v1.5
  [ -z "$v" ] && return 0
  [ "$v" = "true" ]
}

_progress_poll_interval() {
  local v
  v=$(awk '/^[[:space:]]*observability:/{f=1;next} f && /^[[:space:]]*poll_interval_seconds:/{print $2; exit}' \
        .harness/manifest.yaml 2>/dev/null)
  printf '%s' "${v:-10}"
}

# ─────────────────────────────────────────────────────────────
# start_progress_poller <path-to-_progress.jsonl>
# ─────────────────────────────────────────────────────────────
start_progress_poller() {
  local progress_file="$1"
  [ -n "$progress_file" ] || return 0
  if ! _progress_heartbeat_enabled; then
    return 0
  fi

  # Truncate or create the file so the poller starts from a clean slate
  : > "$progress_file"
  # Sentinel file the background loop watches — removing it causes graceful exit
  touch "${progress_file}.poller-active"

  local interval
  interval=$(_progress_poll_interval)

  (
    last_lines=0
    while [ -f "${progress_file}.poller-active" ]; do
      if [ -f "$progress_file" ]; then
        cur=$(wc -l < "$progress_file" 2>/dev/null | tr -d ' ')
        if [ "${cur:-0}" -gt "$last_lines" ]; then
          # Print only new lines since last tick
          tail -n +$((last_lines + 1)) "$progress_file" 2>/dev/null | \
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            if command -v jq >/dev/null 2>&1; then
              ts=$(printf '%s' "$line"   | jq -r '.ts    // empty' 2>/dev/null | cut -c12-16)
              ag=$(printf '%s' "$line"   | jq -r '.agent // "?"'   2>/dev/null | tr '[:lower:]' '[:upper:]' | cut -c1-3)
              ph=$(printf '%s' "$line"   | jq -r '.phase // ""'    2>/dev/null)
              fr=$(printf '%s' "$line"   | jq -r '.fr    // empty' 2>/dev/null)
              msg=$(printf '%s' "$line"  | jq -r '.msg   // ""'    2>/dev/null)
              if [ -n "$fr" ]; then
                printf '  [%s %s] %s %s: %s\n' "${ts:-??:??}" "${ag:-?}" "$ph" "$fr" "$msg"
              else
                printf '  [%s %s] %s: %s\n'    "${ts:-??:??}" "${ag:-?}" "$ph" "$msg"
              fi
            else
              # Fallback when jq is missing — print raw line so info isn't lost
              printf '  [HEARTBEAT] %s\n' "$line"
            fi
          done
          last_lines=$cur
        fi
      fi
      sleep "$interval"
    done
  ) &
  local poller_pid=$!
  # Record poller PID so stop_progress_poller can find it
  echo "$poller_pid" > "${progress_file}.poller.pid"
  # disown detaches from the parent shell's job table so kill doesn't trigger
  # the noisy "Terminated: 15 ( ... function body ... )" message when
  # stop_progress_poller fires. Best-effort — disown errors when job control
  # is off (non-interactive shells) which is fine, the noise wasn't there anyway.
  disown "$poller_pid" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────
# stop_progress_poller <path-to-_progress.jsonl>
# ─────────────────────────────────────────────────────────────
# Idempotent — safe to call multiple times (e.g., trap + explicit call).
stop_progress_poller() {
  local progress_file="$1"
  [ -n "$progress_file" ] || return 0
  # Removing the sentinel signals the loop to exit on its next tick
  rm -f "${progress_file}.poller-active" 2>/dev/null
  # Best-effort: explicitly kill the loop in case it's mid-sleep
  if [ -f "${progress_file}.poller.pid" ]; then
    pid=$(cat "${progress_file}.poller.pid" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "${progress_file}.poller.pid" 2>/dev/null
  fi
}
