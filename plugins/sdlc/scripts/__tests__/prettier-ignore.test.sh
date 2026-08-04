#!/usr/bin/env bash
# prettier-ignore.test.sh — AC-8 gate + non-vacuity proof for the .prettierignore rule that
# ignores all plugins/sdlc/**/*.md (NA-86 / ADR 0016).
#
# check-plugin-docs-format.sh cannot itself distinguish "everything matched is clean" from
# "everything matched is ignored" (its own header documents this prettier-CLI limitation), so the
# non-vacuity proof — plugins/gtm/README.md must still report ignored:false — lives here instead.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/prettier-ignore.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# plugins/sdlc/scripts/__tests__ -> repo root is four levels up.
repo_root="$(cd "$here/../../../.." && pwd)"
cd "$repo_root" || {
  echo "prettier-ignore.test.sh: FAILED — cannot cd to repo root ($here/../../../..)" >&2
  exit 1
}

if ! pnpm exec prettier --version >/dev/null 2>&1; then
  echo "prettier-ignore.test.sh: FAILED — prettier unavailable; run 'pnpm install --frozen-lockfile'" >&2
  exit 1
fi

failures=0

is_ignored() {
  pnpm exec prettier --file-info "$1" 2>/dev/null | grep -q '"ignored": *true'
}

# Assertion 1 — the file the spec names explicitly.
if is_ignored "plugins/sdlc/commands/auto.md"; then
  echo "PASS: plugins/sdlc/commands/auto.md reports ignored: true"
else
  echo "FAIL: plugins/sdlc/commands/auto.md reports ignored: false" >&2
  failures=$((failures + 1))
fi

# Assertion 2 — one representative file per top-level plugins/sdlc/ dir, plus every
# plugins/sdlc/**/*.md file (the offending path is named on failure, per the error-row contract).
representative_files=(
  "plugins/sdlc/commands/auto.md"
  "plugins/sdlc/agents/scrum-master.md"
  "plugins/sdlc/refs/triage.md"
  "plugins/sdlc/skills/acli/SKILL.md"
)
for f in "${representative_files[@]}"; do
  if is_ignored "$f"; then
    echo "PASS: $f reports ignored: true"
  else
    echo "FAIL: $f reports ignored: false" >&2
    failures=$((failures + 1))
  fi
done

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! is_ignored "$f"; then
    echo "FAIL: un-ignored plugins/sdlc/**/*.md file: $f" >&2
    failures=$((failures + 1))
  fi
done < <(find plugins/sdlc -name "*.md" -type f)

if [ "$failures" -eq 0 ]; then
  echo "PASS: every plugins/sdlc/**/*.md file reports ignored: true"
fi

# Assertion 3 (load-bearing, must not be dropped) — the ignore rule must not over-reach onto
# plugins/gtm/**.
if is_ignored "plugins/gtm/README.md"; then
  echo "FAIL: plugins/gtm/README.md reports ignored: true — the ignore rule over-reached" >&2
  failures=$((failures + 1))
else
  echo "PASS: plugins/gtm/README.md reports ignored: false"
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if is_ignored "$f"; then
    echo "FAIL: the ignore rule over-reached onto plugins/gtm/**: $f" >&2
    failures=$((failures + 1))
  fi
done < <(find plugins/gtm -name "*.md" -type f)

if [ "$failures" -ne 0 ]; then
  echo
  echo "prettier-ignore.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "prettier-ignore.test.sh: PASS — all assertions passed"
exit 0
