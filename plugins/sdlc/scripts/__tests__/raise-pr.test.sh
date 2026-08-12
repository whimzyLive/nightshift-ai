#!/usr/bin/env bash
# raise-pr.test.sh — regression test pinning case-insensitive --phase handling (NA-104 PR #239
# review-fix pass 2, copilot-pull-request-reviewer finding on raise-pr.sh:77).
#
# The unconditional spec/plan reviewer-request skip compared `$PHASE` against the lowercase
# literals `spec`/`plan` directly, with no normalisation — a caller passing `--phase Spec` (or
# any non-lowercase token) fell through the skip and requested a reviewer anyway, silently
# breaking the "unconditional" contract this story is built on. This test mocks `gh` and
# verifies:
#   1. `--phase Spec` (mixed case) still suppresses the reviewer request.
#   2. `--phase PLAN` (upper case) still suppresses the reviewer request.
#   3. `--phase impl` (an unaffected phase, lower case) still requests the reviewer — proving
#      the fix didn't overcorrect into suppressing every phase.
#   4. `--phase impl` under a `claude-inline` fixture requests NO reviewer — closing a vacuous
#      axis case 3 alone leaves open (see below).
#
# Hermeticity: raise-pr.sh -> read-review-config.sh resolves `.claude/project/project-context.md`
# RELATIVE TO CWD, with no way to pass a context-file override through raise-pr.sh. Every case
# below therefore runs from an ISOLATED cwd carrying its own pinned fixture context — never this
# repo's own `.claude/project/project-context.md`.
#
# Two DISTINCT fixtures, deliberately:
#   - $fixture (cases 1-3): Review agent github-copilot / Review mode on-update — happens to be
#     BYTE-IDENTICAL to raise-pr.sh:76-77's own belt-and-suspenders fallback defaults. That makes
#     case 3 alone vacuous on the "did the reader actually run" axis: if read-review-config.sh
#     were broken or missing, the eval would set nothing, raise-pr.sh's fallback would apply the
#     SAME values, and case 3 would still (wrongly) PASS.
#   - $fixture_inline (case 4 only): Review agent claude-inline — deliberately DIFFERENT from the
#     fallback default, so a broken/stubbed reader would leave REVIEW_AGENT at its
#     github-copilot fallback and case 4 would (correctly) go red requesting a reviewer it should
#     have suppressed. This is the case that actually proves the reader ran.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/raise-pr.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/raise-pr.sh"

mockdir="$(mktemp -d)"
workdir="$(mktemp -d)"
trap 'rm -rf "$mockdir" "$workdir"' EXIT

# Fixture repo roots: raise-pr.sh is run with one of these as cwd, so read-review-config.sh
# resolves ./.claude/project/project-context.md to THAT fixture, never the host repo's.
fixture="$workdir/fixture-repo"
mkdir -p "$fixture/.claude/project"
cat >"$fixture/.claude/project/project-context.md" <<'FIXTURE_CTX'
## Code Review

| Token        | Value          |
| ------------ | -------------- |
| Review agent | `github-copilot` |
| Review mode  | `on-update`    |
FIXTURE_CTX

fixture_inline="$workdir/fixture-repo-inline"
mkdir -p "$fixture_inline/.claude/project"
cat >"$fixture_inline/.claude/project/project-context.md" <<'FIXTURE_CTX_INLINE'
## Code Review

| Token        | Value           |
| ------------ | --------------- |
| Review agent | `claude-inline` |
| Review mode  | `on-update`     |
FIXTURE_CTX_INLINE

# Mock `gh`: pr create/ready/view always succeed; pr edit --add-reviewer records the attempt to
# $MOCK_MARKER_FILE so the test can assert whether a reviewer request was ever made, without
# caring about the (unmocked) verification step's own gh api calls.
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
case "${1:-}" in
  repo)
    [ "${2:-}" = "view" ] && { echo "example-org/example-repo"; exit 0; }
    ;;
  pr)
    case "${2:-}" in
      create) echo "https://github.com/example-org/example-repo/pull/42"; exit 0 ;;
      ready)  exit 0 ;;
      view)   echo "https://github.com/example-org/example-repo/pull/42"; exit 0 ;;
      edit)
        for arg in "$@"; do
          [ "$arg" = "--add-reviewer" ] && printf 'REVIEWER-REQUESTED\n' >> "${MOCK_MARKER_FILE:?}"
        done
        exit 0
        ;;
    esac
    ;;
  api)
    printf '[]\n'
    exit 0
    ;;
esac
echo "mock gh: unhandled invocation: $*" >&2
exit 1
MOCK_GH
chmod +x "$mockdir/gh"

printf 'PR body.\n' > "$workdir/body.md"

failures=0

run_case() {
  # $1 = fixture dir, $2 = phase arg, $3 = expect ('requested' | 'not-requested'), $4 = label
  local fx="$1" phase="$2" expect="$3" label="$4"
  local marker="$workdir/marker-$RANDOM"
  : > "$marker"
  ( cd "$fx" && PATH="$mockdir:$PATH" MOCK_MARKER_FILE="$marker" \
      bash "$script" --phase "$phase" "headbranch" "develop" "title" "$workdir/body.md" \
      >/dev/null 2>"$workdir/stderr.log" )
  local status=$?
  local requested="not-requested"
  [ -s "$marker" ] && requested="requested"
  if [ "$status" -eq 0 ] && [ "$requested" = "$expect" ]; then
    echo "PASS: $label — reviewer $requested (expected $expect)"
  else
    echo "FAIL: $label — exit=$status reviewer=$requested (expected $expect)"
    cat "$workdir/stderr.log"
    failures=$((failures + 1))
  fi
}

# Case 1: mixed-case phase must still suppress the reviewer request (the fix).
run_case "$fixture" "Spec" "not-requested" "--phase Spec (mixed case) suppresses the reviewer request"

# Case 2: upper-case phase must still suppress the reviewer request.
run_case "$fixture" "PLAN" "not-requested" "--phase PLAN (upper case) suppresses the reviewer request"

# Case 3: an unaffected phase, unaffected case, must still request a reviewer — proves the fix
# didn't overcorrect into suppressing every phase.
run_case "$fixture" "impl" "requested" "--phase impl (unaffected) still requests the reviewer"

# Case 4: same unaffected phase, but under a claude-inline fixture — the reviewer must NOT be
# requested. Unlike case 3, this fixture value differs from raise-pr.sh's own fallback default,
# so a broken/stubbed read-review-config.sh cannot silently produce the same (wrong) outcome.
run_case "$fixture_inline" "impl" "not-requested" "--phase impl under claude-inline requests no reviewer"

if [ "$failures" -eq 0 ]; then
  echo "PASS: all raise-pr.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures raise-pr.sh regression case(s) failed"
  exit 1
fi
