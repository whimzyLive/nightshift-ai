#!/usr/bin/env bash
# check-plugin-docs-format.sh — all-files Prettier fixed-point gate for plugin docs (NA-62).
#
# WHY THIS EXISTS (NA-62)
#   Prettier 3.6.2 is non-idempotent on certain fenced command blocks: a well-formed committed
#   plugins/**/*.md file can satisfy `format(X) != X` (state 1 — well-formed but UNSTABLE), so the
#   next unguarded `prettier --write` (a pre-commit hook, editor-on-save, or any PR touching it)
#   shatters runnable command blocks into broken four-backtick fences (the NA-56 corruption). CI's
#   line-34 format check is affected-only (`--base`-scoped), so a latent state-1 file not in the
#   current diff ships green. This gate runs the SAME native `prettier --check` predicate over ALL
#   plugins/**/*.md on every PR, closing that scope hole.
#
# WHY plain `prettier`, not `nx format:check` (deliberate CLAUDE.md nx-first deviation)
#   nx format:check is project-graph-based; plugins/**/*.md belong to no nx project, so no nx form
#   checks every plugin markdown file BY PATH. `prettier --check` over the path glob is the correct
#   (and only) tool for an all-files check of these non-project files. See NA-62 spec Decision 3.
#
# USAGE
#   bash plugins/sdlc/scripts/check-plugin-docs-format.sh
#   Exit 0 + "OK" when every plugins/**/*.md is a Prettier fixed point.
#   Exit 1 + prettier's native [warn] offender list when one or more are not (or on an empty glob /
#   missing prettier).

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
