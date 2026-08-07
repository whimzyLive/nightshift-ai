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

# T2d: set-but-unwritable SDLC_CAPTURE_ROOT is a hard error, writes nothing ANYWHERE — not just
# at the target path (spec: "writes nothing anywhere" for an unwritable override).
printf 'not a dir\n' > "$tmp/blocker"
before_tree="$(find "$tmp" -type f | sort)"
SDLC_CAPTURE_ROOT="$tmp/blocker/nested" bash "$cap" --print-root >/dev/null 2>"$tmp/err_d"
[ "$?" -ne 0 ] && ok "(T2d) unwritable override exits non-zero" || bad "(T2d) unwritable override" "exited 0"
after_tree="$(find "$tmp" -type f | sort)"
[ "$before_tree" = "$(printf '%s\n' "$after_tree" | grep -vF "$tmp/err_d")" ] \
  && ok "(T2d2) unwritable override wrote nothing anywhere under \$tmp" \
  || bad "(T2d2) unwritable override wrote nothing anywhere" "tree changed beyond err_d: $after_tree"

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

# T2e2: a capture written from the linked worktree survives `git worktree remove --force` of
# that worktree (spec D3's central claim — the staging root is the PRIMARY checkout, never the
# linked worktree, so removing the worktree must not touch it).
wt_cap_out="$(cd "$tmp/linked" && bash "$cap" rule web-engineer/survives-worktree-removal AB-1)"
wt_cap_file="$wt_repo/.claude/memories/captured/rules/AB-1--survives-worktree-removal.md"
[ "$wt_cap_out" = "CAPTURED=$wt_cap_file" ] && [ -f "$wt_cap_file" ] \
  && ok "(T2e2) capture written from the linked worktree lands in the main checkout" \
  || bad "(T2e2) capture from linked worktree" "got '$wt_cap_out'"
git -C "$wt_repo" worktree remove --force "$tmp/linked"
[ ! -d "$tmp/linked" ] \
  && ok "(T2e3a) the linked worktree was actually removed" \
  || bad "(T2e3a) linked worktree removed" "$tmp/linked still exists — worktree remove failed silently"
[ -f "$wt_cap_file" ] \
  && ok "(T2e3b) the capture survives 'git worktree remove --force' of the linked worktree" \
  || bad "(T2e3b) capture survives worktree removal" "capture file gone after worktree remove"

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

cat > "$tmp/payload-shared.md" <<'EOF'
---
agent: [web-engineer, mobile-engineer]
trigger: [cross-cutting concern]
rule: When a rule binds more than one agent, capture it under shared/.
evidence: [AB-1]
uses: 0
origin: domain-agent
---
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

run_cap rule shared/cross-cutting-thing AB-1 "$tmp/payload-shared.md" >/dev/null
p2="$(extract_fm "$root/rules/AB-1--cross-cutting-thing.md" | parse_frontmatter)"
[ "$(field_value "$p2" promote-target)" = ".claude/memories/agents/shared/cross-cutting-thing.md" ] \
  && ok "(T3g) promote-target shared" || bad "(T3g) promote-target shared" "got '$(field_value "$p2" promote-target)'"
[ "$(field_value "$p2" agent)" = "web-engineer,mobile-engineer" ] \
  && ok "(T3g2) shared agent list comes from the payload, never the literal 'shared'" \
  || bad "(T3g2) shared agent list from payload" "got '$(field_value "$p2" agent)'"

run_cap rule shared/under-agented AB-1 "$tmp/payload.md" >/dev/null 2>&1 \
  && bad "(T3g3) shared/ with < 2 payload agents rejected" "exited 0" \
  || ok "(T3g3) shared/ with < 2 payload agents rejected"
[ ! -e "$root/rules/AB-1--under-agented.md" ] \
  && ok "(T3g4) rejected shared capture wrote no file" || bad "(T3g4) rejected shared capture wrote no file" "file exists"

# --- T3g5-7: shared/ counter-only exemption ---------------------------------
cat > "$tmp/counter-only.md" <<'EOF'
---
uses: 1
evidence: [AB-1]
---
EOF
run_cap rule shared/counter-only-target AB-1 "$tmp/counter-only.md" >/dev/null 2>"$tmp/counter_err"
counter_rc=$?
[ "$counter_rc" -eq 0 ] \
  && ok "(T3g5) shared/ counter-only payload (uses set, rule absent) is exempt from the >= 2 agents guard" \
  || bad "(T3g5) shared counter-only exemption" "exited $counter_rc: $(cat "$tmp/counter_err")"
[ -f "$root/rules/AB-1--counter-only-target.md" ] \
  && ok "(T3g6) shared/ counter-only capture is written" || bad "(T3g6) shared counter-only written" "file missing"
p3="$(extract_fm "$root/rules/AB-1--counter-only-target.md" | parse_frontmatter)"
[ "$(field_value "$p3" uses)" = "1" ] \
  && ok "(T3g7) shared/ counter-only capture carries the payload's uses" || bad "(T3g7) counter-only uses" "got '$(field_value "$p3" uses)'"

# --- T3g8-9: the counter-only exemption cannot be smuggled via a single-agent payload --------
cat > "$tmp/smuggled.md" <<'EOF'
---
agent: [web-engineer]
trigger: [some situation]
evidence: [AB-1]
uses: 0
---
EOF
run_cap rule shared/smuggled AB-1 "$tmp/smuggled.md" >/dev/null 2>&1 \
  && bad "(T3g8) a single-agent payload cannot smuggle past the >= 2 agents guard" "exited 0" \
  || ok "(T3g8) a single-agent payload cannot smuggle past the >= 2 agents guard"
[ ! -e "$root/rules/AB-1--smuggled.md" ] \
  && ok "(T3g9) rejected smuggle attempt wrote no file" || bad "(T3g9) rejected smuggle attempt" "file exists"

run_cap rule web-engineer/capture-before-commit AB-1 - >/dev/null
[ "$(grep -c '^---$' "$f")" -eq 2 ] && ok "(T3h) '-' writes frontmatter only" || bad "(T3h) frontmatter only" "body present after '-' capture"
run_cap rule web-engineer/capture-before-commit AB-1 >/dev/null
[ "$(grep -c '^---$' "$f")" -eq 2 ] && ok "(T3i) omitted payload writes frontmatter only" || bad "(T3i) omitted payload" "body present"

run_cap rule web-engineer/Not_Kebab AB-1 >/dev/null 2>&1 \
  && bad "(T3j) non-kebab rule id rejected" "exited 0" || ok "(T3j) non-kebab rule id rejected"
run_cap rule web-engineer AB-1 >/dev/null 2>&1 \
  && bad "(T3j2) a target with no slash is rejected" "exited 0" || ok "(T3j2) a target with no slash is rejected"
[ ! -e "$root/rules/AB-1--web-engineer.md" ] \
  && ok "(T3j3) rejected slash-less target wrote no file" || bad "(T3j3) rejected slash-less target wrote no file" "file exists"
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

run_cap rule web-engineer/capture-before-commit AB-1 >/dev/null
[ "$(ls "$root/rules" | wc -l | tr -d ' ')" -eq 3 ] && ok "(T3r) re-capture is idempotent overwrite" || bad "(T3r) idempotent overwrite" "extra files created"

# --- T3s: a failed write is reported as a failure, never a false CAPTURED= (Critical 1) -----
wf_root="$tmp/write-fail-root"; mkdir -p "$wf_root/rules" "$wf_root/reviews"
chmod 500 "$wf_root/rules"
wf_out="$(SDLC_CAPTURE_ROOT="$wf_root" bash "$cap" rule web-engineer/unwritable-target AB-1 2>"$tmp/wf_err")"
wf_rc=$?
chmod 700 "$wf_root/rules"
[ "$wf_rc" -ne 0 ] && ok "(T3s1) a failed write exits non-zero" || bad "(T3s1) failed write exit code" "exited 0"
printf '%s' "$wf_out" | grep -q '^CAPTURED=' \
  && bad "(T3s2) a failed write never prints CAPTURED=" "CAPTURED= line present: $wf_out" \
  || ok "(T3s2) a failed write never prints CAPTURED="
[ -s "$tmp/wf_err" ] && ok "(T3s3) a failed write reports the failure on stderr" || bad "(T3s3) failure reported on stderr" "stderr empty"
[ ! -e "$wf_root/rules/AB-1--unwritable-target.md" ] \
  && ok "(T3s4) a failed write leaves no partial/final file behind" || bad "(T3s4) no file left behind" "file exists"

# --- T3t: story-key validation, both kinds (Critical 2) --------------------------------------
run_cap rule web-engineer/story-key-check '../../escaped' >/dev/null 2>&1 \
  && bad "(T3t1) path-traversal story key rejected (rule)" "exited 0" \
  || ok "(T3t1) path-traversal story key rejected (rule)"
[ -z "$(find "$tmp" -maxdepth 2 -name 'escaped--story-key-check.md')" ] \
  && ok "(T3t2) rejected story key escaped nothing onto disk (rule)" \
  || bad "(T3t2) rejected story key wrote nothing" "escaped file exists"
run_cap rule web-engineer/story-key-check 'feat/NA-98' >/dev/null 2>&1 \
  && bad "(T3t3) a branch name is rejected as a story key (rule)" "exited 0" \
  || ok "(T3t3) a branch name is rejected as a story key (rule)"
run_cap rule web-engineer/story-key-check 'ab-1' >/dev/null 2>&1 \
  && bad "(T3t4) a lowercase story key is rejected (rule)" "exited 0" \
  || ok "(T3t4) a lowercase story key is rejected (rule)"
run_cap rule web-engineer/story-key-check 'AB-1' >/dev/null 2>&1 \
  && ok "(T3t5) a well-formed story key is accepted (rule)" \
  || bad "(T3t5) well-formed story key accepted (rule)" "exited non-zero"
run_cap review '../../escaped' 2026-08-04 1 >/dev/null 2>&1 \
  && bad "(T3t6) path-traversal story key rejected (review)" "exited 0" \
  || ok "(T3t6) path-traversal story key rejected (review)"
run_cap review 'AB-1' 2026-08-04 3 >/dev/null 2>&1 \
  && ok "(T3t7) a well-formed story key is accepted (review)" \
  || bad "(T3t7) well-formed story key accepted (review)" "exited non-zero"

# --- T3u: round must be a positive integer, never a silent overwrite of round 1 ---------------
cat > "$tmp/round-distinguishing.md" <<'EOF'
---
domains: [web-engineer]
root_causes: [missing-validation]
issue_count: 7
---
EOF
run_cap review AB-1 2026-08-05 1 "$tmp/round-distinguishing.md" >/dev/null
r1f="$root/reviews/2026-08-05-AB-1.md"
r1_before="$(field_value "$(extract_fm "$r1f" | parse_frontmatter)" issue_count)"
[ "$r1_before" = "7" ] && ok "(T3u0) round 1 seeded with the distinguishing issue_count" \
  || bad "(T3u0) round 1 seed" "got issue_count='$r1_before'"
run_cap review AB-1 2026-08-05 abc >/dev/null 2>"$tmp/round_err"
round_rc=$?
[ "$round_rc" -ne 0 ] && ok "(T3u1) a non-numeric round is rejected" || bad "(T3u1) non-numeric round rejected" "exited 0"
[ -s "$tmp/round_err" ] && ok "(T3u2) a non-numeric round reports the failure on stderr" || bad "(T3u2) round failure on stderr" "stderr empty"
r1_after="$(field_value "$(extract_fm "$r1f" | parse_frontmatter)" issue_count)"
[ "$r1_before" = "$r1_after" ] \
  && ok "(T3u3) round 1's capture survives a rejected non-numeric round (no silent overwrite)" \
  || bad "(T3u3) round 1 survives rejected round" "issue_count changed from '$r1_before' to '$r1_after'"
run_cap review AB-1 2026-08-05 0 >/dev/null 2>&1 \
  && bad "(T3u4) round 0 is rejected (not a positive integer)" "exited 0" \
  || ok "(T3u4) round 0 is rejected (not a positive integer)"
run_cap review AB-1 2026-08-05 99999999999999999999 >/dev/null 2>&1 \
  && bad "(T3u5) an overflowing round is rejected (not 1-9999)" "exited 0" \
  || ok "(T3u5) an overflowing round is rejected (not 1-9999)"
r1_after2="$(field_value "$(extract_fm "$r1f" | parse_frontmatter)" issue_count)"
[ "$r1_before" = "$r1_after2" ] \
  && ok "(T3u6) round 1's capture survives a rejected overflowing round" \
  || bad "(T3u6) round 1 survives overflow round" "issue_count changed from '$r1_before' to '$r1_after2'"

# --- T4: list-captured --------------------------------------------------------
lst="$scripts/list-captured.sh"
run_lst() { SDLC_CAPTURE_ROOT="$root" bash "$lst" "$@"; }

tsv="$(run_lst --kind rule --story AB-1)"
[ "$(printf '%s\n' "$tsv" | wc -l | tr -d ' ')" -eq 4 ] \
  && ok "(T4a) four rule captures listed" || bad "(T4a) rule capture count" "got: $tsv"
printf '%s\n' "$tsv" | head -1 | cut -f1 | grep -q "^$root/rules/" \
  && ok "(T4b) TSV field 1 is the path" || bad "(T4b) TSV path leads" "got '$(printf '%s\n' "$tsv" | head -1 | cut -f1)'"
printf '%s\n' "$tsv" | head -1 | cut -f2 | grep -qx rule \
  && ok "(T4c) TSV field 2 is the kind" || bad "(T4c) TSV kind" "got '$(printf '%s\n' "$tsv" | head -1 | cut -f2)'"

run_lst --kind rule --agent mobile-engineer | grep -q cross-cutting-thing \
  && ok "(T4d) --agent filters on the agent list" || bad "(T4d) --agent filter" "shared capture not returned"
[ -z "$(run_lst --kind rule --agent platform-engineer)" ] \
  && ok "(T4e) --agent excludes non-matching" || bad "(T4e) --agent exclusion" "returned rows for platform-engineer"

json="$(run_lst --json --kind review)"
printf '%s' "$json" | grep -q '"count"' && ok "(T4f) --json has count" || bad "(T4f) --json count" "got '$json'"
printf '%s' "$json" | grep -q '"promoteTarget"' && ok "(T4g) --json has promoteTarget" || bad "(T4g) --json promoteTarget" "missing"
printf '%s' "$json" | grep -q 'findings' && ok "(T4h) review summary is '<N> findings — ...'" || bad "(T4h) review summary" "missing"

empty="$tmp/empty-root"
[ -z "$(SDLC_CAPTURE_ROOT="$empty" bash "$lst")" ] \
  && ok "(T4i) empty staging area prints nothing" || bad "(T4i) empty TSV" "printed output"
[ "$(SDLC_CAPTURE_ROOT="$empty" bash "$lst" --json)" = '{"entries":[],"count":0}' ] \
  && ok "(T4j) empty staging area JSON" || bad "(T4j) empty JSON" "got '$(SDLC_CAPTURE_ROOT="$empty" bash "$lst" --json)'"

# --- T4j2-3: root-resolution failure (vs T4i/T4j's resolved-but-empty root) --------------------
nongit="$tmp/not-a-repo"; mkdir -p "$nongit"
nongit_out="$tmp/nongit_out"; nongit_err="$tmp/nongit_err"
( cd "$nongit" && env -u SDLC_CAPTURE_ROOT -u SDLC_MEMORY_ROOT bash "$lst" ) >"$nongit_out" 2>"$nongit_err"
nongit_rc=$?
if [ "$nongit_rc" -ne 0 ] && [ -z "$(cat "$nongit_out")" ] && [ -s "$nongit_err" ]; then
  pass_lst=1
else
  pass_lst=0
fi
[ "$pass_lst" -eq 1 ] && ok "(T4j2) resolution failure outside a git checkout is a hard error" \
  || bad "(T4j2) resolution failure hard error" "rc=$nongit_rc stdout='$(cat "$nongit_out")' stderr='$(cat "$nongit_err")'"
( cd "$nongit" && env -u SDLC_CAPTURE_ROOT -u SDLC_MEMORY_ROOT bash "$lst" --json ) >"$nongit_out" 2>"$nongit_err"
nongit_json_rc=$?
[ "$nongit_json_rc" -ne 0 ] && ! grep -q '"entries"' "$nongit_out" \
  && ok "(T4j3) resolution failure (--json) is a hard error, not a quiet empty corpus" \
  || bad "(T4j3) resolution failure --json hard error" "rc=$nongit_json_rc stdout='$(cat "$nongit_out")'"

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

# --- T6c-e: the documented frontmatter-only review marker (issue_count: 0) never warns ---------
marker_repo="$tmp/markerrepo"
SDLC_CAPTURE_ROOT="$marker_repo/.claude/memories/captured" bash "$cap" review AB-1 2026-08-04 1 - >/dev/null
mkdir -p "$marker_repo/.claude/memories/captured/reviews"
cf2_out="$(bash "$scripts/check-frontmatter.sh" "$marker_repo" 2>&1)"; cf2_rc=$?
[ "$cf2_rc" -eq 0 ] && ok "(T6c) frontmatter-only review marker never fails the gate" || bad "(T6c) exit code" "got $cf2_rc"
printf '%s' "$cf2_out" | grep -qi '2026-08-04-AB-1' \
  && bad "(T6d) frontmatter-only review marker (issue_count: 0) does not warn" "$cf2_out" \
  || ok "(T6d) frontmatter-only review marker (issue_count: 0) does not warn"

bad_marker_repo="$tmp/badmarkerrepo"; mkdir -p "$bad_marker_repo/.claude/memories/captured/reviews"
cat > "$bad_marker_repo/.claude/memories/captured/reviews/2026-08-04-AB-2.md" <<'EOF'
---
story: AB-2
date: 2026-08-04
domains: []
root_causes: []
issue_count: 2
captured: 2026-08-04T00:00:00Z
origin: qa-round
promote-target: .claude/memories/reviews/2026-08-04-AB-2.md
---
EOF
cf3_out="$(bash "$scripts/check-frontmatter.sh" "$bad_marker_repo" 2>&1)"
printf '%s' "$cf3_out" | grep -qi "empty field 'domains'" \
  && ok "(T6e) issue_count > 0 with empty domains/root_causes still warns" \
  || bad "(T6e) genuinely malformed review still warns" "$cf3_out"

# --- T4l/T4m/T4n (NA-101): dual-root listing — resolved root + legacy primary-checkout root --
dr_repo="$tmp/dualrepo"; mkdir -p "$dr_repo"
dr_repo="$(cd "$dr_repo" && pwd -P)"
git -C "$dr_repo" init -q
git -C "$dr_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
# SDLC_MEMORY_ROOT names the memory ROOT; its staging area is <root>/captured. Seed one capture in
# the LEGACY in-repo staging root and one in the RESOLVED root's staging area.
dr_root="$tmp/dual-root"
SDLC_CAPTURE_ROOT="$dr_repo/.claude/memories/captured" bash "$cap" rule web-engineer/legacy-only AB-1 "$tmp/payload.md" >/dev/null
SDLC_CAPTURE_ROOT="$dr_root/captured" bash "$cap" rule web-engineer/resolved-only AB-1 "$tmp/payload.md" >/dev/null
dr_out="$( cd "$dr_repo" && env -u SDLC_CAPTURE_ROOT SDLC_MEMORY_ROOT="$dr_root" bash "$lst" --kind rule 2>/dev/null )"
{ printf '%s' "$dr_out" | grep -q 'legacy-only' && printf '%s' "$dr_out" | grep -q 'resolved-only'; } \
  && ok "(T4l) both the resolved root and the legacy in-repo root are listed" \
  || bad "(T4l) dual-root listing" "got '$dr_out'"

# T4m: the same <kind>/<basename> in both roots is emitted ONCE, resolved root winning
SDLC_CAPTURE_ROOT="$dr_repo/.claude/memories/captured" bash "$cap" rule web-engineer/dupe-both AB-1 "$tmp/payload.md" >/dev/null
SDLC_CAPTURE_ROOT="$dr_root/captured" bash "$cap" rule web-engineer/dupe-both AB-1 "$tmp/payload.md" >/dev/null
dupe_all="$( cd "$dr_repo" && env -u SDLC_CAPTURE_ROOT SDLC_MEMORY_ROOT="$dr_root" bash "$lst" --kind rule 2>/dev/null | grep 'AB-1--dupe-both.md' )"
dupe_n="$(printf '%s\n' "$dupe_all" | grep -c 'AB-1--dupe-both.md')"
dupe_win="$(printf '%s\n' "$dupe_all" | head -1 | cut -f1)"
{ [ "$dupe_n" -eq 1 ] && [ "$dupe_win" = "$dr_root/captured/rules/AB-1--dupe-both.md" ]; } \
  && ok "(T4m) a capture present in both roots is emitted once, resolved root winning" \
  || bad "(T4m) dedupe precedence" "count=$dupe_n winner='$dupe_win'"

# T4n: resolver failure WITH a legacy root -> warning on stderr, legacy-only listing, exit 0
n_out="$( cd "$dr_repo" && env -u SDLC_CAPTURE_ROOT -u XDG_DATA_HOME SDLC_MEMORY_ROOT="relative-path" bash "$lst" --kind rule 2>"$tmp/dr_warn" )"; n_rc=$?
{ [ "$n_rc" -eq 0 ] && [ -s "$tmp/dr_warn" ] && printf '%s' "$n_out" | grep -q 'legacy-only'; } \
  && ok "(T4n) resolver failure with a legacy root warns and lists the legacy root alone" \
  || bad "(T4n) resolver-failure fallback" "rc=$n_rc out='$n_out'"

exit "$fail"
