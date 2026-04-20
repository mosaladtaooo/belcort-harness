# Progress Protocol — Subagent → Orchestrator Heartbeat

This is a **shared protocol** loaded into the prompt of every subagent (Planner, Generator, Evaluator). It exists to close the Trustworthy Agents §opacity-at-scale anti-pattern: when the orchestrator dispatches a subagent via `claude -p` and blocks for 10–30 minutes, the human sees nothing. The heartbeat gives the human a live, low-overhead window into what each subagent is doing without breaking subagent isolation.

## Why this exists

Trustworthy Agents calls out by name: *"Subagent workflows become no longer neatly visible as a single thread."* If the user can't tell what's happening, they either babysit (defeats autonomy) or check out (defeats oversight). The heartbeat is the minimum mechanism that keeps oversight cheap.

It is **NOT** a chat back-channel. Subagents do not communicate decisions or intermediate results through `_progress.jsonl` — that's still file-based via the existing artifact contracts (proposal.md, review.md, eval-report.md, etc.). The heartbeat is one-way, ephemeral, and discardable. If the run completes successfully, no future agent reads it.

## File

Each running subagent appends to:

```
.harness/features/${FEATURE}/_progress.jsonl
```

`${FEATURE}` is read from `manifest.yaml` `state.current_feature`. The file is created (or truncated) by the orchestrator at dispatch start; the orchestrator polls it every ~10s while the subagent runs; on subagent exit the orchestrator stops polling and may keep or discard the file (default: keep, useful for post-mortem on a stuck run).

**Planner exception.** The Planner runs *before* a feature folder exists (the Planner is what creates it). The Planner therefore emits to a top-level path:

```
.harness/_progress-planner.jsonl
```

After the Planner finishes and the feature folder exists, the orchestrator moves this file to `.harness/features/${FEATURE}/_progress-planner.jsonl` for archival. Subsequent dispatches (Generator NEGOTIATE/BUILD, Evaluator REVIEW-PROPOSAL/EVALUATE) use the per-feature `_progress.jsonl` path.

## Schema (one JSON object per line)

```json
{"ts":"2026-04-20T15:34:12Z","agent":"generator","phase":"RED","fr":"FR-003","msg":"writing failing test for sort-by-created-at"}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `ts` | string (ISO-8601 UTC) | yes | When the milestone happened. Use the agent's clock; precision to seconds is enough |
| `agent` | string | yes | One of: `planner`, `generator`, `evaluator` |
| `phase` | string | yes | Agent-specific milestone label (see "When to emit" below) |
| `fr` | string | optional | Current FR if applicable (e.g., `FR-003`) |
| `ac` | string | optional | Current AC if applicable (e.g., `AC-002-1`) |
| `msg` | string | yes | One short sentence — what's happening NOW. NOT a result. NOT a decision. NOT a question |

Lines are pure JSONL. No comments, no blank lines. The orchestrator's poller skips malformed lines silently rather than crashing — but a malformed line in your output is a bug in your emission code.

## When to emit — by agent

Each agent emits at the **boundaries** that would help a human triage a stuck run. Not every tool call. Not every line of code. Boundaries.

### Planner
- Mode start: `{"phase":"start","msg":"PLAN mode (Pass 1) beginning"}`
- Pass 1 → Pass 2 transition: `{"phase":"pass-2-start","msg":"architecture + criteria"}`
- Each FR drafted: `{"phase":"fr-drafted","fr":"FR-003","msg":"sort + filter requirements captured"}`
- Self-validation start: `{"phase":"self-validate","msg":"running 16-point checklist"}`
- Mode end: `{"phase":"complete","msg":"all artifacts written, 16/16 passed"}`

### Generator (BUILD mode)
- Mode start: `{"phase":"start","msg":"BUILD mode beginning, current_task=FR-003"}`
- Each TDD phase boundary:
  - `{"phase":"RED","fr":"FR-003","msg":"writing failing test"}`
  - `{"phase":"GREEN","fr":"FR-003","msg":"minimum impl to pass test"}`
  - `{"phase":"REFACTOR","fr":"FR-003","msg":"extracting duplication, tests green"}`
  - `{"phase":"COMMIT","fr":"FR-003","msg":"atomic commit, 3 tests added"}`
- Pause request: `{"phase":"PAUSE","fr":"FR-003","msg":"writing pause-questions.md, awaiting user"}`
- Blocker / unexpected error: `{"phase":"BLOCKED","msg":"vitest install failed, retrying with --force"}`
- Mode end: `{"phase":"complete","msg":"all FRs done, implementation-report written"}`

### Generator (NEGOTIATE / FINALIZE-CONTRACT modes)
- Mode start, mode end. NEGOTIATE mode is short; over-emission here is noise.

### Evaluator (REVIEW-PROPOSAL mode)
- Mode start, mode end, plus: `{"phase":"verdict","msg":"agreed | needs-revision"}`

### Evaluator (EVALUATE mode)
- Mode start: `{"phase":"start","msg":"EVALUATE mode beginning, app at http://localhost:3000"}`
- Each FR tested: `{"phase":"testing-fr","fr":"FR-003","msg":"happy path + 3 edge cases"}`
- Each AC verified: `{"phase":"testing-ac","ac":"AC-002-1","msg":"empty input rejection"}`
- Reward-hacking scan: `{"phase":"reward-hacking-scan","msg":"git archaeology: 6 checks running"}`
- Critical finding: `{"phase":"finding","msg":"CRITICAL — DELETE route 404s on FR-003"}`
- Scoring start: `{"phase":"scoring","msg":"Part A binary, then Part B numeric"}`
- Mode end: `{"phase":"complete","msg":"verdict: PASS | FAIL"}`

## Rate limit

**Maximum 1 line per 30 seconds per agent.** A flood of lines is noise; the human can't read 50 events per minute. If you find yourself wanting to emit more often, you're using this as a debug log — that's the wrong tool. Write to `implementation-report.md` or use the proper artifact channel.

The agent enforces this itself by tracking the timestamp of its last emission and skipping if <30s elapsed. The single exception is the boundary events listed above — when a TDD phase changes, emit even if <30s has passed (the boundary IS the signal).

## What NOT to emit

These are RED FLAGS — if you catch yourself wanting to emit one of these, stop, and either (a) write it to the proper artifact, or (b) decide it doesn't need to be communicated at all.

- **Decisions or rationale**. The decision belongs in `implementation-report.md`, `proposal.md`, `review.md`, or `decisions.md`. Heartbeat is "what I'm doing now," not "why I chose this approach."
- **Test output, error messages, stack traces**. These belong in the agent's normal stdout (the orchestrator captures it from `claude -p`). The heartbeat is for *boundary events*, not log lines.
- **Questions for the user**. If you need user input mid-run, use the pause-questions protocol (Generator) or AskUserQuestions tool (Planner). Don't sneak questions into a heartbeat msg.
- **Multi-line content**. One line per event. The msg field is one sentence, no embedded newlines.
- **Sensitive content**. The heartbeat may be displayed to the user in a terminal — don't emit secrets, credentials, or full file contents.
- **Anything you'd be embarrassed to read in a tool's logs three months from now**.

## Emission code (reference)

The agent emits via shell — not by writing the file from inside its model context. Example pattern:

```bash
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"ts":"%s","agent":"generator","phase":"RED","fr":"%s","msg":"%s"}\n' \
  "$ts" "$CURRENT_FR" "writing failing test" \
  >> ".harness/features/${FEATURE}/_progress.jsonl"
```

Use `printf '%s'` rather than `echo` for the msg field to avoid escape-character surprises. Quote-escape any user-controlled content if the msg includes it (rare — most msgs are agent-authored).

## Orchestrator side (reference)

The orchestrator opens a backgrounded poller before each `claude -p` dispatch and stops it on dispatch exit. See `commands/sprint.md` for the canonical wrapping pattern (`start_progress_poller` / `stop_progress_poller`). The poller reads new lines every 10s and prints them in compact form: `  [HH:MM AGENT] phase: msg`.

If `config.observability.heartbeat: false` in `manifest.yaml`, agents skip emission and the orchestrator skips polling. The harness still works — you just lose the live window.

## Backward compatibility

Older subagent prompts (v1.4 and earlier) don't know about this protocol. If they don't emit, `_progress.jsonl` stays empty and the poller prints nothing — silent degradation. v1.5+ subagent prompts include a §Progress Logging section that points back here.
