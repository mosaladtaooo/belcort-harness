#!/usr/bin/env bash
# BELCORT Harness repository self-audit.
#
# This checks the repo that ships the harness itself. It is intentionally
# separate from /harness:doctor, which checks a user's runtime environment.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

FAILS=0
PASSES=0

pass() {
  PASSES=$((PASSES + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  FAILS=$((FAILS + 1))
  printf 'FAIL  %s\n' "$1" >&2
}

require_file() {
  [ -f "$1" ] && pass "file exists: $1" || fail "missing file: $1"
}

json_value() {
  local path="$1" expr="$2"
  python3 - "$path" "$expr" <<'PY'
import json, sys
path, expr = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
cur = data
for part in expr.split("."):
    if "[" in part and part.endswith("]"):
        name, idx = part[:-1].split("[", 1)
        if name:
            cur = cur[name]
        cur = cur[int(idx)]
    else:
        cur = cur[part]
print(cur)
PY
}

check_json() {
  local file
  for file in \
    ".claude-plugin/marketplace.json" \
    "plugins/harness/.claude-plugin/plugin.json" \
    "plugins/harness/.mcp.json" \
    "plugins/harness/hooks/hooks.json"; do
    if python3 -m json.tool "$file" >/dev/null; then
      pass "valid JSON: $file"
    else
      fail "invalid JSON: $file"
    fi
  done
}

check_shell_syntax() {
  local file ok=1
  while IFS= read -r file; do
    if bash -n "$file"; then
      pass "shell syntax: $file"
    else
      fail "shell syntax: $file"
      ok=0
    fi
  done < <(find install plugins/harness/scripts plugins/harness/hooks scripts -name '*.sh' -type f | sort)
  [ "$ok" -eq 1 ] || true
}

check_hook_registration() {
  python3 - <<'PY'
import json, pathlib, sys
cfg = json.load(open("plugins/harness/hooks/hooks.json", encoding="utf-8"))
bad = []
for event, entries in cfg.get("hooks", {}).items():
    for entry in entries:
        for hook in entry.get("hooks", []):
            command = hook.get("command", "")
            if not command.startswith('bash "${CLAUDE_PLUGIN_ROOT}/hooks/'):
                bad.append(f"{event}: command should invoke hook through bash: {command}")
            target = command.replace('bash "${CLAUDE_PLUGIN_ROOT}/', "plugins/harness/").rstrip('"')
            if target and not pathlib.Path(target).exists():
                bad.append(f"{event}: hook target missing: {target}")
if bad:
    print("\n".join(bad), file=sys.stderr)
    sys.exit(1)
PY
  if [ "$?" -eq 0 ]; then
    pass "hook commands invoke existing scripts through bash"
  else
    fail "hook command registration"
  fi
}

run_hook_fixture() {
  local name="$1" expected="$2" payload="$3"
  local out err code
  out="$(mktemp)"
  err="$(mktemp)"
  printf '%s' "$payload" | bash plugins/harness/hooks/pre-tool-use.sh >"$out" 2>"$err"
  code=$?
  rm -f "$out" "$err"
  if [ "$code" -eq "$expected" ]; then
    pass "hook fixture: $name"
  else
    fail "hook fixture: $name expected exit $expected got $code"
  fi
}

check_hook_fixtures() {
  run_hook_fixture "benign bash allowed" 0 \
    '{"tool_name":"Bash","tool_input":{"command":"git status --short"}}'
  run_hook_fixture "force push blocked" 2 \
    '{"tool_name":"Bash","tool_input":{"command":"git push origin HEAD --force"}}'
  run_hook_fixture "short force push blocked" 2 \
    '{"tool_name":"Bash","tool_input":{"command":"git push -f origin HEAD"}}'
  run_hook_fixture "sudo blocked" 2 \
    '{"tool_name":"Bash","tool_input":{"command":"sudo rm -rf /tmp/example"}}'
  run_hook_fixture ".harness deletion blocked" 2 \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf .harness/"}}'
  run_hook_fixture ".env.example write allowed" 0 \
    '{"tool_name":"Write","tool_input":{"file_path":".env.example","content":"FOO=REPLACE_ME"}}'
  run_hook_fixture ".env.local write blocked" 2 \
    '{"tool_name":"Write","tool_input":{"file_path":".env.local","content":"SECRET=real"}}'
  run_hook_fixture "stale worktree harness write blocked" 2 \
    '{"tool_name":"Edit","tool_input":{"file_path":".worktrees/current/.harness/manifest.yaml","old_string":"a","new_string":"b"}}'
}

check_versions() {
  local plugin_version marketplace_meta marketplace_plugin
  plugin_version="$(json_value plugins/harness/.claude-plugin/plugin.json version)"
  marketplace_meta="$(json_value .claude-plugin/marketplace.json metadata.version)"
  marketplace_plugin="$(json_value .claude-plugin/marketplace.json 'plugins[0].version')"

  [ "$plugin_version" = "$marketplace_meta" ] && [ "$plugin_version" = "$marketplace_plugin" ] \
    && pass "metadata versions match: $plugin_version" \
    || fail "metadata versions differ: plugin=$plugin_version marketplace=$marketplace_meta marketplace-plugin=$marketplace_plugin"

  grep -q "harness@${plugin_version}" README.md \
    && pass "README install verification mentions harness@${plugin_version}" \
    || fail "README missing harness@${plugin_version} install verification"

  grep -q "v${plugin_version} — shipped to \`main\` as current stable" README.md \
    && pass "README current stable matches v${plugin_version}" \
    || fail "README current stable does not match v${plugin_version}"

  grep -q "^## v${plugin_version} —" CHANGELOG.md \
    && pass "CHANGELOG top release includes v${plugin_version}" \
    || fail "CHANGELOG missing v${plugin_version} release heading"

  grep -q "^| ${plugin_version} |" ROADMAP.md \
    && pass "ROADMAP shipped table includes ${plugin_version}" \
    || fail "ROADMAP shipped table missing ${plugin_version}"
}

check_docs_drift() {
  if grep -q '#v2-beta' README.md; then
    fail "README still recommends #v2-beta install path"
  else
    pass "README has no #v2-beta install path"
  fi

  if grep -q 'active development branch for post-v2.1.9' README.md; then
    fail "README still describes v2-beta as active"
  else
    pass "README does not describe v2-beta as active"
  fi

  if grep -q '"agents": "\./agents/"' README.md plugins/harness/skills/harness/SKILL.md plugins/harness/commands/sprint.md; then
    fail "live docs still show invalid string-form agents metadata"
  else
    pass "live docs do not show invalid string-form agents metadata"
  fi

  grep -q 'Planner .*analyze .*human approval gate .*Generator' README.md \
    && pass "README pipeline orders analyze before human gate" \
    || fail "README pipeline ordering missing analyze-before-human-gate"

  grep -q 'plan → analyze → \[human gate\] → negotiate' plugins/harness/skills/harness/SKILL.md \
    && pass "SKILL command table orders analyze before human gate" \
    || fail "SKILL command table ordering drifted"

  grep -q 'Do NOT update `state.phase = "negotiating"` yet' plugins/harness/commands/sprint.md \
    && pass "sprint keeps negotiating phase after human gate" \
    || fail "sprint negotiating phase guard missing"

  grep -q '## Worker logs (real-time captures, v3.1.1+)' plugins/harness/templates/features/simulation-report.md.txt \
    && pass "simulation-report template has v3.1.1 real-time worker logs section" \
    || fail "simulation-report template missing v3.1.1 real-time worker logs section"

  if grep -q 'negotiate` (standalone)' plugins/harness/skills/harness/SKILL.md; then
    fail "SKILL manual command table lists removed negotiate standalone command"
  else
    pass "SKILL manual command table does not list removed negotiate standalone command"
  fi
}

require_file "README.md"
require_file "CHANGELOG.md"
require_file "ROADMAP.md"
require_file "plugins/harness/hooks/pre-tool-use.sh"
require_file "plugins/harness/templates/features/simulation-report.md.txt"

check_json
check_shell_syntax
check_hook_registration
check_hook_fixtures
check_versions
check_docs_drift

printf '\nSelf-audit: %d passed, %d failed\n' "$PASSES" "$FAILS"
[ "$FAILS" -eq 0 ]
