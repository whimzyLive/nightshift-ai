#!/usr/bin/env bash
# format-write.sh — SessionEnd formatting pass. When the repository is configured with
# prettier, format-writes the files the session left modified so unformatted output never
# survives session teardown. Always exits 0 — a formatting failure must never block teardown.
#
# "Configured with prettier" means BOTH of:
#   1. a prettier config exists — .prettierrc*, prettier.config.*, or a "prettier" key in
#      package.json; and
#   2. the repo's own prettier binary is installed at node_modules/.bin/prettier.
# No global or npx fallback — teardown must never fetch a formatter over the network, and a
# repo without prettier installed has not opted in, config file or not.
#
# Deliberately SCOPED-ONLY: it formats just the files the working tree currently has changed
# (staged, unstaged, or untracked) — never a full-repo sweep, so an unrelated unformatted
# corner of the repo is never touched. .prettierignore and unsupported file types are
# respected via --ignore-unknown.
set -uo pipefail

# Bail silently unless we're inside a git work tree (mirrors cleanup-tmp.sh's never-fail posture).
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0

# Gate 1 — prettier config present?
has_config=""
for f in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml .prettierrc.json5 \
  .prettierrc.js .prettierrc.cjs .prettierrc.mjs .prettierrc.toml \
  prettier.config.js prettier.config.cjs prettier.config.mjs prettier.config.ts; do
  [ -e "$f" ] && has_config=1 && break
done
if [ -z "$has_config" ] && [ -f package.json ] && grep -q '"prettier"[[:space:]]*:' package.json; then
  has_config=1
fi
[ -n "$has_config" ] || exit 0

# Gate 2 — local prettier binary installed?
prettier_bin="node_modules/.bin/prettier"
[ -x "$prettier_bin" ] || exit 0

# Collect the session's changed files (NUL-safe): tracked changes vs HEAD plus untracked
# files, existence-filtered so deletions/renames never reach prettier. `git diff HEAD` fails
# harmlessly on an unborn branch; untracked listing already honors .gitignore.
{
  git diff --name-only -z HEAD 2>/dev/null || true
  git ls-files -z --others --exclude-standard 2>/dev/null || true
} |
  while IFS= read -r -d '' path; do
    [ -f "$path" ] && printf '%s\0' "$path"
  done |
  xargs -0 -r "$prettier_bin" --write --ignore-unknown >/dev/null 2>&1 || true

exit 0
