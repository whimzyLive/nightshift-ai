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

# --- T4: list-captured --------------------------------------------------------
lst="$scripts/list-captured.sh"
run_lst() { SDLC_CAPTURE_ROOT="$root" bash "$lst" "$@"; }

tsv="$(run_lst --kind rule --story AB-1)"
[ "$(printf '%s\n' "$tsv" | wc -l | tr -d ' ')" -eq 2 ] \
  && ok "(T4a) two rule captures listed" || bad "(T4a) rule capture count" "got: $tsv"
printf '%s\n' "$tsv" | head -1 | cut -f1 | grep -q "^$root/rules/" \
  && ok "(T4b) TSV field 1 is the path" || bad "(T4b) TSV path leads" "got '$(printf '%s\n' "$tsv" | head -1 | cut -f1)'"
printf '%s\n' "$tsv" | head -1 | cut -f2 | grep -qx rule \
  && ok "(T4c) TSV field 2 is the kind" || bad "(T4c) TSV kind" "got '$(printf '%s\n' "$tsv" | head -1 | cut -f2)'"

run_lst --kind rule --agent shared | grep -q cross-cutting-thing \
  && ok "(T4d) --agent filters on the agent list" || bad "(T4d) --agent filter" "shared capture not returned"
[ -z "$(run_lst --kind rule --agent mobile-engineer)" ] \
  && ok "(T4e) --agent excludes non-matching" || bad "(T4e) --agent exclusion" "returned rows for mobile-engineer"

json="$(run_lst --json --kind review)"
printf '%s' "$json" | grep -q '"count"' && ok "(T4f) --json has count" || bad "(T4f) --json count" "got '$json'"
printf '%s' "$json" | grep -q '"promoteTarget"' && ok "(T4g) --json has promoteTarget" || bad "(T4g) --json promoteTarget" "missing"
printf '%s' "$json" | grep -q 'findings' && ok "(T4h) review summary is '<N> findings — ...'" || bad "(T4h) review summary" "missing"

empty="$tmp/empty-root"
[ -z "$(SDLC_CAPTURE_ROOT="$empty" bash "$lst")" ] \
  && ok "(T4i) empty staging area prints nothing" || bad "(T4i) empty TSV" "printed output"
[ "$(SDLC_CAPTURE_ROOT="$empty" bash "$lst" --json)" = '{"entries":[],"count":0}' ] \
  && ok "(T4j) empty staging area JSON" || bad "(T4j) empty JSON" "got '$(SDLC_CAPTURE_ROOT="$empty" bash "$lst" --json)'"

printf 'no frontmatter here\n' > "$root/rules/AB-1--broken.md"
SDLC_CAPTURE_ROOT="$root" bash "$lst" --kind rule >/dev/null 2>"$tmp/warn"
[ "$?" -eq 0 ] && [ -s "$tmp/warn" ] \
  && ok "(T4k) malformed capture warns and continues" || bad "(T4k) malformed capture" "no warning or non-zero exit"
rm -f "$root/rules/AB-1--broken.md"

# --- T5: collect-memory never sees a capture; git stays clean ---------------
cm_repo="$tmp/cmrepo"; mkdir -p "$cm_repo/.claude/memories/agents/web-engineer"
git -C "$cm_repo" init -q
git -C "$cm_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
SDLC_CAPTURE_ROOT="$cm_repo/.claude/memories/captured" bash "$cap" rule web-engineer/staged-rule AB-1 "$tmp/payload.md" >/dev/null
git -C "$cm_repo" add -f .claude/memories/captured/.gitignore
git -C "$cm_repo" -c user.email=t@t -c user.name=t commit -q -m marker
[ -z "$(git -C "$cm_repo" status --porcelain)" ] \
  && ok "(T5a) staging .gitignore keeps git status clean" || bad "(T5a) git status clean" "got '$(git -C "$cm_repo" status --porcelain)'"
out_cm="$(bash "$scripts/collect-memory.sh" web-engineer "$cm_repo" 2>/dev/null)"
printf '%s' "$out_cm" | grep -q 'staged-rule' \
  && bad "(T5b) collect-memory ignores captures" "captured rule leaked into collection" \
  || ok "(T5b) collect-memory ignores captures"

# --- T6: check-frontmatter warns on a bad capture, never fails ---------------
cf_repo="$tmp/cfrepo"; mkdir -p "$cf_repo/.claude/memories/captured/rules"
cat > "$cf_repo/.claude/memories/captured/rules/AB-1--bad-capture.md" <<'EOF'
---
id: bad-capture
agent: [web-engineer]
trigger: []
rule: ""
evidence: []
uses: 0
status: captured
captured: 2026-08-04T00:00:00Z
story: AB-1
origin: domain-agent
promote-target: .claude/memories/agents/web-engineer/bad-capture.md
---
EOF
cf_out="$(bash "$scripts/check-frontmatter.sh" "$cf_repo" 2>&1)"; cf_rc=$?
[ "$cf_rc" -eq 0 ] && ok "(T6a) capture problems never fail the gate" || bad "(T6a) exit code" "got $cf_rc"
printf '%s' "$cf_out" | grep -qi 'bad-capture' \
  && ok "(T6b) malformed capture surfaced as a warning" || bad "(T6b) warning emitted" "no mention of bad-capture"

exit "$fail"
