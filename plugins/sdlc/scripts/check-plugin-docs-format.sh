#!/usr/bin/env bash
# check-plugin-docs-format.sh — all-files Prettier fixed-point gate for plugin docs (NA-62).
#
# rationale: refs/design-notes/check-plugin-docs-format-history.md
#   (why this gate exists (NA-62/NA-56), and why plain `prettier` rather than `nx format:check`)
#
# USAGE
#   bash plugins/sdlc/scripts/check-plugin-docs-format.sh
#   Exit 0 + "OK" when every plugins/**/*.md is a Prettier fixed point.
#   Exit 1 + prettier's native [warn] offender list when one or more are not (or on an empty glob /
#   missing prettier).
#
# SCOPE NARROWED BY NA-86 / ADR 0016
#   .prettierignore now ignores all plugins/sdlc/**/*.md, so plugins/gtm/** is the SOLE remaining
#   non-ignored tree this script's plugins/**/*.md glob actually checks — one more .prettierignore
#   entry away from this gate silently checking zero files and reporting a vacuous pass (see the
#   "bare directory-level .prettierignore" limitation noted above: this script cannot detect that
#   case itself). plugins/sdlc/scripts/__tests__/prettier-ignore.test.sh assertion 3
#   (plugins/gtm/README.md must still report ignored:false) is the only thing that would catch it.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# plugins/sdlc/scripts -> repo root is three levels up.
repo_root="$(cd "$here/../../.." && pwd)"
cd "$repo_root" || {
  echo "check-plugin-docs-format: FAILED — cannot cd to repo root ($here/../../..)" >&2
  exit 1
}

# Prettier availability guard — actionable message on a local run before node_modules is installed.
if ! pnpm exec prettier --version >/dev/null 2>&1; then
  echo "check-plugin-docs-format: FAILED — prettier unavailable; run 'pnpm install --frozen-lockfile'" >&2
  exit 1
fi

# The gate: the native fixed-point predicate over ALL plugin markdown, in one call.
# Let prettier expand its own glob (quoted) so it applies .prettierignore consistently.
#
# Fail-fast empty-set guard — a vacuously-green gate is worse than none (mirror the sibling guard).
# Deliberately NOT a separate `find`/`shopt -s globstar` pre-check: either would enumerate the glob
# through a DIFFERENT mechanism than the gate itself uses below (a plain filesystem walk ignores
# .prettierignore and dotfile rules prettier applies), so the guard's count could silently diverge
# from what the gate actually checks — a later .prettierignore entry could make the pre-check see
# files while prettier's own ignore-aware glob sees none, defeating the guard. `find` also would
# have needed `shopt -s globstar` for the recursive `**`, which fails outright on macOS's stock
# bash 3.2 (globstar needs bash >= 4; verified locally). Avoid both problems by reading the SAME
# `prettier --check` invocation's own output: prettier reports an unmatched glob explicitly
# ("No files matching the pattern were found", non-zero exit) when the raw glob resolves to zero
# paths (wrong dir, plugins/ deleted/misconfigured), so that single call is simultaneously the
# fixed-point gate and the empty-set detector for THAT case — same enumeration, zero chance of the
# guard and the gate seeing a different file set. (A bare directory-level .prettierignore entry
# that ignores every matched file individually is a different, deeper prettier-CLI limitation:
# prettier reports blanket "All matched files use Prettier code style!" for that case with no way
# to distinguish it from a genuine all-clean result. No local pre-check can fix that — it is
# identical to what the CI gate itself would silently report, since both now run this exact call.)
output="$(pnpm exec prettier --check "plugins/**/*.md" 2>&1)"
exit_code=$?
printf '%s\n' "$output"

if printf '%s' "$output" | grep -q 'No files matching the pattern were found'; then
  echo "check-plugin-docs-format: FAILED — no plugins/**/*.md files matched prettier's own glob (wrong dir / misconfigured path)" >&2
  exit 1
fi

if [ "$exit_code" -eq 0 ]; then
  echo "check-plugin-docs-format: OK — every plugins/**/*.md is a Prettier fixed point"
  exit 0
fi

echo "check-plugin-docs-format: FAILED — one or more plugins/**/*.md files are not Prettier fixed points" >&2
echo "Fix: inspect prettier --write's diff per flagged file; accept benign reformats, but MANUALLY" >&2
echo "dedent any fenced command block prettier would re-fence to four backticks (see NA-62)." >&2
exit 1
