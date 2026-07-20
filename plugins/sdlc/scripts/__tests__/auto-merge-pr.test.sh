#!/usr/bin/env bash
# auto-merge-pr.test.sh — regression test pinning the gh `pr merge --yes` removal (NA-45).
#
# gh >=2.90 dropped the `--yes` flag from `gh pr merge` ("unknown flag: --yes"). This test mocks
# `gh` to reproduce that exact contract and asserts auto-merge-pr.sh's 1-arg back-compat path
# still prints MERGED and exits 0 through it — i.e. the script must resolve the merge method and
# call `gh pr merge <pr> <method>` WITHOUT `--yes`.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/auto-merge-pr.test.sh
# Exit 0 = PASS, non-zero = FAIL.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/auto-merge-pr.sh"

mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

# Mock `gh` mirroring the real gh (>=2.90) contract this script depends on:
#   - `gh repo view --json nameWithOwner -q .nameWithOwner`  -> a repo slug
#   - `gh api repos/<slug> --jq '...'`                        -> an allowed merge method
#   - `gh pr merge <pr> <method> --yes`                       -> "unknown flag: --yes", exit 1
#   - `gh pr merge <pr> <method>` (no --yes)                  -> succeeds, exit 0
#   - `gh pr view <pr> --json state -q .state`                -> MERGED
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
case "${1:-}" in
  repo)
    [ "${2:-}" = "view" ] && { echo "example-org/example-repo"; exit 0; }
    ;;
  api)
    echo "--merge"
    exit 0
    ;;
  pr)
    case "${2:-}" in
      merge)
        for arg in "$@"; do
          if [ "$arg" = "--yes" ]; then
            echo "unknown flag: --yes" >&2
            exit 1
          fi
        done
        echo "Merged pull request #${3:-}"
        exit 0
        ;;
      view)
        echo "MERGED"
        exit 0
        ;;
    esac
    ;;
esac
echo "mock gh: unhandled invocation: $*" >&2
exit 1
MOCK_GH
chmod +x "$mockdir/gh"

# Stub `acli` as a harmless no-op so the 1-arg path (no STORY_KEY/DONE_STATUS, transition block
# skipped entirely) is exercised cleanly even if it were ever invoked.
cat >"$mockdir/acli" <<'MOCK_ACLI'
#!/usr/bin/env bash
exit 0
MOCK_ACLI
chmod +x "$mockdir/acli"

stderr_file="$mockdir/stderr.log"
out="$(PATH="$mockdir:$PATH" bash "$script" 999999 2>"$stderr_file")"
status=$?

if [ "$status" -eq 0 ] && [ "$out" = "MERGED" ]; then
  echo "PASS: auto-merge-pr.sh (1-arg path) exits 0 and prints MERGED under a gh that rejects --yes"
  exit 0
else
  echo "FAIL: auto-merge-pr.sh (1-arg path) — exit=$status output=${out:-<empty>}"
  echo "--- script stderr ---"
  cat "$stderr_file"
  exit 1
fi
