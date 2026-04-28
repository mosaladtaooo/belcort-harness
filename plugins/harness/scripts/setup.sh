#!/usr/bin/env bash
# BELCORT Harness — Project-local Setup (v2)
# Creates .harness/ with baseline templates and installs the project CLAUDE.md.
# Idempotent; safe to run multiple times.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEMPLATES="$PLUGIN_ROOT/templates"

if [ ! -d "$TEMPLATES" ]; then
  echo "ERROR: templates directory not found at $TEMPLATES" >&2
  exit 1
fi

# 1. Create .harness/ structure
mkdir -p .harness/spec .harness/evaluator .harness/features .harness/progress

# 1a. Brownfield stack detection (FIX B1 Phase 1)
# Detect existing project conventions BEFORE writing harness defaults so the
# manifest reflects this project's reality, not greenfield Next.js+Vitest.
# Values are exported so the manifest substitution step (1c) can read them.
DEFAULT_BRANCH=""
SRC_DIR=""
TEST_RUNNER=""
STACK_FAMILY=""

detect_stack() {
  # 1. Default branch (read from git, not hard-code 'main')
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
    [ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH=$(git config init.defaultBranch 2>/dev/null || true)
    # Fall back to inspecting local branches: prefer main > master > develop
    if [ -z "$DEFAULT_BRANCH" ]; then
      for b in main master develop; do
        if git show-ref --verify --quiet "refs/heads/$b"; then DEFAULT_BRANCH="$b"; break; fi
      done
    fi
  fi
  [ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

  # 2. Source directory layout
  if { [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ]; } && [ -d "app" ]; then
    SRC_DIR="app"
  elif [ -d "src" ]; then
    SRC_DIR="src"
  elif [ -d "app" ]; then
    SRC_DIR="app"
  elif [ -d "lib" ] && [ -f "package.json" ]; then
    SRC_DIR="lib"
  else
    SRC_DIR="."  # flat layout — Evaluator greps from project root
  fi

  # 3. Test runner (read package.json devDependencies + dependencies)
  if [ -f "package.json" ]; then
    if grep -q '"jest"' package.json 2>/dev/null; then
      TEST_RUNNER="jest"
    elif grep -q '"vitest"' package.json 2>/dev/null; then
      TEST_RUNNER="vitest"
    elif grep -q '"@playwright/test"' package.json 2>/dev/null; then
      TEST_RUNNER="playwright"
    elif grep -q '"mocha"' package.json 2>/dev/null; then
      TEST_RUNNER="mocha"
    else
      TEST_RUNNER="(none — please configure manually)"
    fi
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    if [ -f "pyproject.toml" ] && grep -q 'pytest' pyproject.toml 2>/dev/null; then
      TEST_RUNNER="pytest"
    else
      TEST_RUNNER="(python — pytest assumed; please confirm)"
    fi
  elif [ -f "Cargo.toml" ]; then
    TEST_RUNNER="cargo test"
  elif [ -f "go.mod" ]; then
    TEST_RUNNER="go test"
  else
    TEST_RUNNER="(no package.json — non-Node project?)"
  fi

  # 4. Stack family
  if [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ]; then
    STACK_FAMILY="nextjs"
  elif [ -f "astro.config.mjs" ] || [ -f "astro.config.ts" ] || [ -f "astro.config.js" ]; then
    STACK_FAMILY="astro"
  elif [ -f "package.json" ] && grep -q '"react-native"' package.json 2>/dev/null; then
    STACK_FAMILY="react-native"
  elif [ -f "package.json" ] && grep -q '"expo"' package.json 2>/dev/null; then
    STACK_FAMILY="expo"
  elif [ -f "package.json" ] && grep -q '"vite"' package.json 2>/dev/null; then
    STACK_FAMILY="vite"
  elif [ -f "package.json" ] && grep -q '"remix"' package.json 2>/dev/null; then
    STACK_FAMILY="remix"
  elif [ -f "Cargo.toml" ]; then
    STACK_FAMILY="rust"
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    STACK_FAMILY="python"
  elif [ -f "go.mod" ]; then
    STACK_FAMILY="go"
  elif [ -f "package.json" ]; then
    STACK_FAMILY="node-generic"
  else
    STACK_FAMILY="generic"
  fi

  # Show user what was detected
  echo "Detected project conventions:"
  echo "  - default_branch: ${DEFAULT_BRANCH}"
  echo "  - source_dir:     ${SRC_DIR}"
  echo "  - test_runner:    ${TEST_RUNNER}"
  echo "  - stack_family:   ${STACK_FAMILY}"
  echo ""
  echo "These will be written to .harness/manifest.yaml. Edit there to override."
  echo ""
}
detect_stack

# 2. Copy baseline templates if not already present (never overwrite user customisations)
copy_if_missing() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    echo "  keep: $dst (already exists, not overwriting)"
  else
    cp "$src" "$dst"
    echo "  new:  $dst"
  fi
}

copy_if_missing "$TEMPLATES/manifest.yaml"                          ".harness/manifest.yaml"
copy_if_missing "$TEMPLATES/ROADMAP.md"                             ".harness/ROADMAP.md"
copy_if_missing "$TEMPLATES/progress/changelog.md"                  ".harness/progress/changelog.md"
copy_if_missing "$TEMPLATES/progress/decisions.md"                  ".harness/progress/decisions.md"
copy_if_missing "$TEMPLATES/progress/known-issues.md"               ".harness/progress/known-issues.md"
copy_if_missing "$TEMPLATES/evaluator/criteria.md.txt"              ".harness/evaluator/criteria.md"
copy_if_missing "$TEMPLATES/evaluator/examples.md.txt"              ".harness/evaluator/examples.md"
copy_if_missing "$TEMPLATES/evaluator/tuning-log.md.txt"            ".harness/evaluator/tuning-log.md"

# 2c. Substitute detected stack values into manifest.yaml (FIX B1 Phase 1)
# Idempotent: only write if the placeholder/default is still present. Never
# overwrite a user-customised value. We touch only the project: and git: blocks
# (and the testing.unit field if it's still the literal default and a real
# detection was made) — all other manifest sections belong to other agents.
MANIFEST=".harness/manifest.yaml"
if [ -f "$MANIFEST" ]; then
  # Use a portable in-place edit. macOS sed needs an empty -i argument; GNU sed
  # accepts -i without one. The python3 fallback covers both without divergence.
  python3 - "$MANIFEST" "$DEFAULT_BRANCH" "$SRC_DIR" "$TEST_RUNNER" "$STACK_FAMILY" <<'PY'
import sys, re, io
path, default_branch, src_dir, test_runner, stack_family = sys.argv[1:6]
with open(path, "r", encoding="utf-8") as f:
    txt = f.read()

# (1) git.main_branch — only replace if it's still the default literal "main"
# AND the detected branch is something else. Otherwise leave untouched (user
# may have already set this on a re-run).
if default_branch and default_branch != "main":
    txt = re.sub(
        r'(?m)^(\s*main_branch:\s*)"main"\s*$',
        lambda m: f'{m.group(1)}"{default_branch}"',
        txt, count=1,
    )

# (2) project: block — add src_dir / test_runner / stack_family rows under
# project: if not already present. Insert after `created: ""` (the last default
# row) for stable ordering. Idempotent — skip if any of the new keys already
# appear under project:.
def has_project_key(text, key):
    return re.search(rf'(?m)^project:\s*\n(?:.*\n)*?\s+{re.escape(key)}:', text) is not None

project_inserts = []
if not has_project_key(txt, "src_dir"):
    project_inserts.append(f'  src_dir: "{src_dir}"            # detected at setup; FIX B1 brownfield-aware')
if not has_project_key(txt, "test_runner"):
    project_inserts.append(f'  test_runner: "{test_runner}"')
if not has_project_key(txt, "stack_family"):
    project_inserts.append(f'  stack_family: "{stack_family}"')

if project_inserts:
    insertion = "\n".join(project_inserts) + "\n"
    # Insert directly after `  created: ""` line inside the project: block.
    # Match the project: block up through `  created: "..."` and the trailing
    # newline. The original template has a blank line after `created: ""`
    # before the next top-level key (`# FR-6` comment, `constitution:` etc.);
    # by inserting between `created: ""\n` and that blank line we keep the
    # new rows visually grouped under project: and preserve the existing
    # vertical breathing room between blocks.
    # Use [ \t]* (not \s*) after the closing quote so the match terminates at
    # the immediate newline of `  created: ""` and does NOT swallow any
    # trailing blank line that separates project: from the next top-level key.
    # If \s*\n were used instead, the substitution would land AFTER the blank,
    # visually decoupling the new rows from the project: block.
    new_txt, n = re.subn(
        r'(?m)^(project:\s*\n(?:  [^\n]*\n)*?  created:\s*"[^"]*"[ \t]*\n)',
        lambda m: m.group(1) + insertion,
        txt, count=1,
    )
    if n == 0:
        # Fallback: append a project block extension at end of file
        new_txt = txt.rstrip() + "\n\n# --- detected at setup (FIX B1) ---\nproject_detected:\n" + insertion
    txt = new_txt

with open(path, "w", encoding="utf-8") as f:
    f.write(txt)
PY
fi

# 2d. .gitignore management (FIX B1 Phase 1)
# Add `.harness/` to .gitignore so harness state doesn't accidentally get
# committed. Idempotent — only adds if not already present.
if [ -f ".gitignore" ]; then
  if ! grep -q '^\.harness/$\|^\.harness/\*$\|^/\.harness/' .gitignore 2>/dev/null; then
    printf '\n# BELCORT Harness state — do not commit\n.harness/\n' >> .gitignore
    echo "  appended: .gitignore (added .harness/ entry)"
  else
    echo "  keep: .gitignore (.harness/ already ignored)"
  fi
else
  cat > .gitignore <<'EOF'
# BELCORT Harness state — do not commit
.harness/
EOF
  echo "  new:  .gitignore (created with .harness/ entry)"
fi

# 3. Install or patch project-local CLAUDE.md
PROJECT_CLAUDE_MD="./CLAUDE.md"
SNIPPET="$TEMPLATES/CLAUDE.md.project.txt"
BEGIN_MARKER="<!-- BELCORT-HARNESS BEGIN v2 -->"
END_MARKER="<!-- BELCORT-HARNESS END -->"

if [ ! -f "$SNIPPET" ]; then
  echo "ERROR: project snippet template missing at $SNIPPET" >&2
  exit 1
fi

touch "$PROJECT_CLAUDE_MD"

# Strip any existing BELCORT-HARNESS block (any version)
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
awk '
  /<!-- BELCORT-HARNESS BEGIN/ { skip=1; next }
  /<!-- BELCORT-HARNESS END -->/ { skip=0; next }
  !skip { print }
' "$PROJECT_CLAUDE_MD" > "$TMP"

# CLAUDE.md conflict surfacing (FIX B1 Phase 3) — scan the surviving (non-harness)
# content for tokens that conflict with the harness defaults we're about to
# write. Don't block; just warn so the user can resolve via .harness/manifest.yaml
# if needed. Suppressed when the source file is empty (greenfield).
if [ -s "$TMP" ]; then
  CONFLICT_HITS=""
  while IFS= read -r kw; do
    if grep -inE "$kw" "$TMP" >/dev/null 2>&1; then
      CONFLICT_HITS="${CONFLICT_HITS}${kw}\n"
    fi
  done <<'EOF'
\bvitest\b
\bjest\b
\bplaywright\b
\bcypress\b
\bmaster branch\b
\bmain branch\b
\bdevelop branch\b
EOF
  if [ -n "$CONFLICT_HITS" ]; then
    echo ""
    echo "WARNING: Existing CLAUDE.md mentions tokens that may conflict with harness defaults:"
    printf "$CONFLICT_HITS" | sed 's/^/  - /; s/\\\\b//g'
    echo "  Detected stack: branch=${DEFAULT_BRANCH}, test_runner=${TEST_RUNNER}, stack=${STACK_FAMILY}."
    echo "  Review .harness/manifest.yaml after setup completes to reconcile."
    echo ""
  fi
fi

# Append fresh block
{
  cat "$TMP"
  [ -s "$TMP" ] && echo ""
  echo "$BEGIN_MARKER"
  cat "$SNIPPET"
  echo "$END_MARKER"
} > "$PROJECT_CLAUDE_MD"

echo ""
echo "BELCORT Harness installed in this project."
echo "  .harness/            - harness state directory"
echo "  ./CLAUDE.md          - project-local activation rules (scoped to this project only)"
echo ""
echo "Next: run '/harness:doctor' to verify the environment, then '/harness:sprint \"<what to build>\"' to start."

# 4. Legacy global-install check (non-fatal warning)
if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q "<!-- BELCORT-HARNESS BEGIN" "$HOME/.claude/CLAUDE.md"; then
  echo ""
  echo "NOTE: A legacy global BELCORT-HARNESS block was detected at ~/.claude/CLAUDE.md."
  echo "      In v2+ the harness rules install project-local, not globally. You can remove"
  echo "      the legacy global block by running: bash '$PLUGIN_ROOT/scripts/uninstall-rules.sh'"
fi
