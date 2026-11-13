#!/usr/bin/env bash
# artefact-checks.test.sh — pins check-spec.sh, check-plan.sh and check-commits.sh, the artefact
# checks that replace `Skills loaded` set coverage. Hermetic: temp files and a temp git repo.
#   bash plugins/sdlc/scripts/__tests__/artefact-checks.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
scripts="$(cd "$here/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
rc() { "$@" >/dev/null 2>&1; echo $?; }

# --- check-spec ------------------------------------------------------------------------------
spec="$work/spec.md"
{
  echo "# Feature — Technical Spec"
  for h in "Overview" "Data Model" "API Surface" "Backend Implementation" "Design & Dev Notes" "Reuse" "Error Handling" "Out of Scope" "Decisions"; do
    printf '\n## %s\n\nN/A\n' "$h"
  done
} >"$spec"
check "spec: complete spec passes" "check-spec: OK" "$(bash "$scripts/check-spec.sh" "$spec")"
check "spec: complete spec exits 0" 0 "$(rc bash "$scripts/check-spec.sh" "$spec")"

grep -v -E '^## (Reuse|Decisions)$' "$spec" >"$work/spec-missing.md"
check "spec: missing headings are named" "MISSING=Reuse
MISSING=Decisions" "$(bash "$scripts/check-spec.sh" "$work/spec-missing.md")"
check "spec: missing headings exit 1" 1 "$(rc bash "$scripts/check-spec.sh" "$work/spec-missing.md")"

{ cat "$spec"; printf '\nTBD: pick a store\n'; } >"$work/spec-tbd.md"
check "spec: TBD is reported with its line" 1 "$(bash "$scripts/check-spec.sh" "$work/spec-tbd.md" | grep -c '^TBD=')"
check "spec: TBD exits 1" 1 "$(rc bash "$scripts/check-spec.sh" "$work/spec-tbd.md")"

{ cat "$spec"; printf '\n```text\n## Reuse\nTBD\n```\n'; } >"$work/spec-fence.md"
check "spec: a TBD inside a fence is ignored" 0 "$(rc bash "$scripts/check-spec.sh" "$work/spec-fence.md")"
sed 's/^## Reuse$/```\n## Reuse\n```/' "$spec" >"$work/spec-fenced-heading.md"
check "spec: a heading inside a fence does not count" "MISSING=Reuse" "$(bash "$scripts/check-spec.sh" "$work/spec-fenced-heading.md")"
check "spec: the word TBDs inside another word is fine" 0 "$(printf '%s\nNo ATBDx here\n' "$(cat "$spec")" >"$work/spec-word.md"; rc bash "$scripts/check-spec.sh" "$work/spec-word.md")"
check "spec: unreadable path exits 2" 2 "$(rc bash "$scripts/check-spec.sh" "$work/none.md")"
check "spec: no argument exits 2" 2 "$(rc bash "$scripts/check-spec.sh")"

# --- check-plan ------------------------------------------------------------------------------
plan="$work/plan.md"
cat >"$plan" <<'PLAN'
# Feature — Implementation Plan

**Spec:** docs/superpowers/specs/X-1.md
**Date:** 2026-01-01
**Agents required:** platform-engineer

## Execution order

Phase 1 only.

## Phase 1 — Backend platform-engineer

- [ ] platform-engineer Add the handler
- [ ] platform-engineer Verify: pnpm test
PLAN
check "plan: complete plan passes" "check-plan: OK" "$(bash "$scripts/check-plan.sh" "$plan")"

grep -v '^\*\*Date:\*\*' "$plan" >"$work/plan-nodate.md"
check "plan: missing header line is named" "MISSING=**Date:** line" "$(bash "$scripts/check-plan.sh" "$work/plan-nodate.md")"
grep -v '^## Execution order' "$plan" >"$work/plan-noorder.md"
check "plan: missing execution order is named" "MISSING=## Execution order" "$(bash "$scripts/check-plan.sh" "$work/plan-noorder.md")"
sed '/^## Phase/,$d' "$plan" >"$work/plan-nophase.md"
check "plan: no phase is named" "MISSING=## Phase N section" "$(bash "$scripts/check-plan.sh" "$work/plan-nophase.md")"
sed '/Verify:/d' "$plan" >"$work/plan-noverify.md"
check "plan: a phase not closing on Verify is named" "NO_VERIFY=## Phase 1 — Backend platform-engineer" "$(bash "$scripts/check-plan.sh" "$work/plan-noverify.md")"
sed '/^- \[ \]/d' "$plan" >"$work/plan-notasks.md"
check "plan: a phase with no tasks is named" "NO_TASKS=## Phase 1 — Backend platform-engineer" "$(bash "$scripts/check-plan.sh" "$work/plan-notasks.md")"
sed 's/Add the handler/TBD handler/' "$plan" >"$work/plan-tbd.md"
check "plan: TBD exits 1" 1 "$(rc bash "$scripts/check-plan.sh" "$work/plan-tbd.md")"
{ cat "$plan"; printf '\n## Phase 2 — Web web-engineer\n\n- [ ] web-engineer Add the page\n'; } >"$work/plan-two.md"
check "plan: only the last task decides Verify" "NO_VERIFY=## Phase 2 — Web web-engineer" "$(bash "$scripts/check-plan.sh" "$work/plan-two.md")"
check "plan: unreadable path exits 2" 2 "$(rc bash "$scripts/check-plan.sh" "$work/none.md")"

# --- check-commits ---------------------------------------------------------------------------
repo="$work/repo"; mkdir "$repo"
g() { git -C "$repo" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "$@"; }
g init -q -b main; g commit -q --allow-empty -m "chore: root"
base="$(g rev-parse HEAD)"
check "commits: empty range is OK" "check-commits: OK" "$(bash "$scripts/check-commits.sh" "$base..HEAD" "$repo")"
for s in "feat(sdlc): add a thing" "fix: a bug" "feat(sdlc)!: break it" "docs(a/b-c.d): words" "revert: undo"; do g commit -q --allow-empty -m "$s"; done
check "commits: conventional commits pass" "check-commits: OK" "$(bash "$scripts/check-commits.sh" "$base..HEAD" "$repo")"
g commit -q --allow-empty -m "Add a thing"
g commit -q --allow-empty -m "feat(sdlc) missing colon"
g commit -q --allow-empty -m "wip: not a type"
g commit -q --allow-empty -m "feat:no space"
out="$(bash "$scripts/check-commits.sh" "$base..HEAD" "$repo")"
check "commits: four bad subjects are reported" 4 "$(grep -c '^BAD=' <<<"$out")"
check "commits: the subject is shown" 1 "$(grep -c 'BAD=.* Add a thing$' <<<"$out")"
check "commits: bad range exits 1" 1 "$(rc bash "$scripts/check-commits.sh" "$base..HEAD" "$repo")"
check "commits: unresolvable range exits 2" 2 "$(rc bash "$scripts/check-commits.sh" "nope..alsonope" "$repo")"
check "commits: no argument exits 2" 2 "$(rc bash "$scripts/check-commits.sh")"
g checkout -q -b side "$base"; g commit -q --allow-empty -m "feat: on side"
g checkout -q main; g merge -q --no-ff side -m "Merge branch 'side'"
tip="$(g rev-parse HEAD)"
check "commits: merge commits are skipped" "check-commits: OK" "$(bash "$scripts/check-commits.sh" "HEAD^..HEAD" "$repo")"
check "commits: the range tip alone resolves" 0 "$(rc bash "$scripts/check-commits.sh" "$tip~0..$tip" "$repo")"

if [ "$failures" -eq 0 ]; then echo "PASS: artefact-checks"; exit 0; fi
echo "FAIL: $failures artefact-checks case(s) failed"; exit 1
