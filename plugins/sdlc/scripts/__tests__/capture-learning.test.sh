#!/usr/bin/env bash
# capture-learning.test.sh — NA-98. Behaviour suite for capture-learning.sh + list-captured.sh.
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/capture-learning.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$here/.."
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

# --- T1: frontmatter-lib round-trips a rule frontmatter block ---------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/sample.md" <<'EOF'
---
id: sample-rule
agent: [web-engineer]
trigger: [one, two]
rule: When X, do Y.
evidence: [AB-1]
uses: 0
status: captured
---

## Why

Body line.
EOF

# shellcheck source=/dev/null
. "$scripts/frontmatter-lib.sh"
parsed="$(extract_fm "$tmp/sample.md" | parse_frontmatter)"
[ "$(field_value "$parsed" id)" = "sample-rule" ] \
  && ok "(T1a) field_value id" || bad "(T1a) field_value id" "got '$(field_value "$parsed" id)'"
list_contains "$(field_value "$parsed" agent)" "web-engineer" \
  && ok "(T1b) list_contains agent" || bad "(T1b) list_contains agent" "agent list did not contain web-engineer"
has_field "$parsed" status \
  && ok "(T1c) has_field status" || bad "(T1c) has_field status" "status missing"

# --- T2: staging-root resolution -------------------------------------------
cap="$scripts/capture-learning.sh"

# T2a: SDLC_CAPTURE_ROOT wins verbatim, and is created when absent
root_a="$tmp/explicit-root"
SDLC_CAPTURE_ROOT="$root_a" bash "$cap" --print-root > "$tmp/out_a" 2>"$tmp/err_a"
[ "$(cat "$tmp/out_a")" = "$root_a" ] \
  && ok "(T2a) SDLC_CAPTURE_ROOT used verbatim" || bad "(T2a) SDLC_CAPTURE_ROOT verbatim" "got '$(cat "$tmp/out_a")'"
[ -d "$root_a/rules" ] && [ -d "$root_a/reviews" ] && [ -f "$root_a/.gitignore" ] \
  && ok "(T2b) root scaffolded (rules, reviews, .gitignore)" || bad "(T2b) root scaffolded" "missing subdir or marker"
[ "$(cat "$root_a/.gitignore")" = "$(printf '*\n!.gitignore')" ] \
  && ok "(T2c) marker content exact" || bad "(T2c) marker content" "got '$(cat "$root_a/.gitignore")'"

# T2d: set-but-unwritable SDLC_CAPTURE_ROOT is a hard error, writes nothing
printf 'not a dir\n' > "$tmp/blocker"
SDLC_CAPTURE_ROOT="$tmp/blocker/nested" bash "$cap" --print-root >/dev/null 2>"$tmp/err_d"
[ "$?" -ne 0 ] && ok "(T2d) unwritable override exits non-zero" || bad "(T2d) unwritable override" "exited 0"

# T2e: from a linked worktree, the root resolves to the MAIN worktree
wt_repo="$tmp/repo"; mkdir -p "$wt_repo"
wt_repo="$(cd "$wt_repo" && pwd -P)"  # canonicalise: git worktree list --porcelain always resolves symlinks (e.g. macOS /tmp -> /private/tmp)
git -C "$wt_repo" init -q
git -C "$wt_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$wt_repo" worktree add -q "$tmp/linked" -b linked >/dev/null 2>&1
got="$(cd "$tmp/linked" && bash "$cap" --print-root)"
case "$got" in
  "$wt_repo"/.claude/memories/captured) ok "(T2e) linked worktree resolves to main checkout" ;;
  *) bad "(T2e) linked worktree resolves to main checkout" "got '$got'" ;;
esac

# --- T3: capture writes ------------------------------------------------------
root="$tmp/cap-root"
run_cap() { SDLC_CAPTURE_ROOT="$root" bash "$cap" "$@"; }

cat > "$tmp/payload.md" <<'EOF'
---
trigger: [capture staging, memory write]
rule: When writing a learning, capture it instead of committing it.
evidence: [AB-1, PR#7]
uses: 0
origin: domain-agent
---

## Why

Committed memory diffs are unreviewed.
EOF

out="$(run_cap rule web-engineer/capture-before-commit AB-1 "$tmp/payload.md")"
f="$root/rules/AB-1--capture-before-commit.md"
[ "$out" = "CAPTURED=$f" ] && ok "(T3a) prints CAPTURED=<path>" || bad "(T3a) CAPTURED line" "got '$out'"
p="$(extract_fm "$f" | parse_frontmatter)"
[ "$(field_value "$p" id)" = "capture-before-commit" ] && ok "(T3b) id derived from arg" || bad "(T3b) id" "got '$(field_value "$p" id)'"
[ "$(field_value "$p" status)" = "captured" ] && ok "(T3c) status captured" || bad "(T3c) status" "got '$(field_value "$p" status)'"
[ "$(field_value "$p" agent)" = "web-engineer" ] && ok "(T3d) agent = target dir" || bad "(T3d) agent" "got '$(field_value "$p" agent)'"
[ "$(field_value "$p" promote-target)" = ".claude/memories/agents/web-engineer/capture-before-commit.md" ] \
  && ok "(T3e) promote-target own dir" || bad "(T3e) promote-target own dir" "got '$(field_value "$p" promote-target)'"
grep -q '^## Why' "$f" && ok "(T3f) body appended" || bad "(T3f) body appended" "## Why missing"

run_cap rule shared/cross-cutting-thing AB-1 "$tmp/payload.md" >/dev/null
p2="$(extract_fm "$root/rules/AB-1--cross-cutting-thing.md" | parse_frontmatter)"
[ "$(field_value "$p2" promote-target)" = ".claude/memories/agents/shared/cross-cutting-thing.md" ] \
  && ok "(T3g) promote-target shared" || bad "(T3g) promote-target shared" "got '$(field_value "$p2" promote-target)'"

run_cap rule web-engineer/capture-before-commit AB-1 - >/dev/null
[ "$(grep -c '^---$' "$f")" -eq 2 ] && ok "(T3h) '-' writes frontmatter only" || bad "(T3h) frontmatter only" "body present after '-' capture"
run_cap rule web-engineer/capture-before-commit AB-1 >/dev/null
[ "$(grep -c '^---$' "$f")" -eq 2 ] && ok "(T3i) omitted payload writes frontmatter only" || bad "(T3i) omitted payload" "body present"

run_cap rule web-engineer/Not_Kebab AB-1 >/dev/null 2>&1 \
  && bad "(T3j) non-kebab rule id rejected" "exited 0" || ok "(T3j) non-kebab rule id rejected"
run_cap rule no-such-agent/some-rule AB-1 >/dev/null 2>&1 \
  && bad "(T3k) unknown agent dir rejected" "exited 0" || ok "(T3k) unknown agent dir rejected"
run_cap bogus foo AB-1 >/dev/null 2>&1 \
  && bad "(T3l) unknown kind rejected" "exited 0" || ok "(T3l) unknown kind rejected"
run_cap rule web-engineer/some-rule AB-1 "$tmp/missing-file.md" >/dev/null 2>&1 \
  && bad "(T3m) missing payload file rejected" "exited 0" || ok "(T3m) missing payload file rejected"

cat > "$tmp/round.md" <<'EOF'
---
domains: [web-engineer]
root_causes: [missing-validation]
issue_count: 2
---

## Issues

- one
EOF
out_r="$(run_cap review AB-1 2026-08-04 2 "$tmp/round.md")"
rf="$root/reviews/2026-08-04-AB-1-r2.md"
[ "$out_r" = "CAPTURED=$rf" ] && ok "(T3n) review path with -r2" || bad "(T3n) review path" "got '$out_r'"
pr="$(extract_fm "$rf" | parse_frontmatter)"
[ "$(field_value "$pr" origin)" = "qa-round" ] && ok "(T3o) review origin fixed" || bad "(T3o) review origin" "got '$(field_value "$pr" origin)'"
[ "$(field_value "$pr" promote-target)" = ".claude/memories/reviews/2026-08-04-AB-1-r2.md" ] \
  && ok "(T3p) review promote-target" || bad "(T3p) review promote-target" "got '$(field_value "$pr" promote-target)'"
run_cap review AB-1 2026-08-04 1 >/dev/null
[ -f "$root/reviews/2026-08-04-AB-1.md" ] && ok "(T3q) round 1 has no suffix" || bad "(T3q) round 1 suffix" "file not at unsuffixed path"

before="$(cat "$f")"; run_cap rule web-engineer/capture-before-commit AB-1 >/dev/null
[ "$(ls "$root/rules" | wc -l | tr -d ' ')" -eq 2 ] && ok "(T3r) re-capture is idempotent overwrite" || bad "(T3r) idempotent overwrite" "extra files created"

exit "$fail"
