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

# Fail-fast empty-set guard — a vacuously-green gate is worse than none (mirror the sibling guard).
# Deliberately `find`, not `shopt -s globstar`: globstar requires bash >= 4, but macOS ships bash
# 3.2 as its default /bin/bash (Apple's last GPLv2-licensed release) — `shopt -s globstar` fails
# with "invalid shell option name" there, silently degrading this guard on any contributor's local
# macOS run even though CI's bash is new enough. `find` has no such version dependency.
file_count="$(find plugins -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$file_count" -eq 0 ]; then
  echo "check-plugin-docs-format: FAILED — no plugins/**/*.md files found (wrong dir / misconfigured path)" >&2
  exit 1
fi

# Prettier availability guard — actionable message on a local run before node_modules is installed.
if ! pnpm exec prettier --version >/dev/null 2>&1; then
  echo "check-plugin-docs-format: FAILED — prettier unavailable; run 'pnpm install --frozen-lockfile'" >&2
  exit 1
fi

# The gate: the native fixed-point predicate over ALL plugin markdown, in one call.
# Let prettier expand its own glob (quoted) so it applies .prettierignore consistently.
if pnpm exec prettier --check "plugins/**/*.md"; then
  echo "check-plugin-docs-format: OK — every plugins/**/*.md is a Prettier fixed point"
  exit 0
fi

echo "check-plugin-docs-format: FAILED — one or more plugins/**/*.md files are not Prettier fixed points" >&2
echo "Fix: inspect prettier --write's diff per flagged file; accept benign reformats, but MANUALLY" >&2
echo "dedent any fenced command block prettier would re-fence to four backticks (see NA-62)." >&2
exit 1
