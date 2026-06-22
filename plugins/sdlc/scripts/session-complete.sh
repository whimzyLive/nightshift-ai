#!/usr/bin/env bash
# session-complete.sh — signal an automation harness that this session's driven phase is done.
#
# OPTIONAL integration. If you run the SDLC commands non-interactively under an automation harness
# (one that drives an interactive `claude` session and watches its output stream), this prints a
# unique completion marker so the harness can release the session's slot immediately instead of
# waiting for an idle timeout. Outside such a harness it is a silent no-op — always safe to run.
#
# Invoked as the FINAL step of each TOP-LEVEL SDLC slash command — exactly once per driven session.
# A command that runs ANOTHER command's logic as a sub-step must apply that command's *ref* inline
# (e.g. /auto and /impl apply refs/triage.md) rather than invoking the nested *command*, so this
# script fires only once, at the end of the top-level flow. Calling it from a nested command would
# emit the sentinel mid-flow and release the worker slot before the parent finishes.
#
# Usage:
#   bash session-complete.sh              # bare marker — no PR (refine/review-fix/folded-plan)
#   bash session-complete.sh <pr-url>     # marker with optional |PR=<url> suffix (spec/plan/impl)
#
# Contract for harness authors:
#   - Inject SDLC_SESSION_KEY into the session's environment per spawn. When it is unset (e.g. a
#     normal local dev session), this script prints nothing and exits 0.
#   - Watch the session output for the marker below and parse the optional PR URL from it:
#       Bare form:  <<<SDLC_SESSION_COMPLETE:KEY>>>
#       PR form:    <<<SDLC_SESSION_COMPLETE:KEY|PR=URL>>>

key="${SDLC_SESSION_KEY:-}"
[ -z "$key" ] && exit 0

# AC-2/AC-3: remove this session's scoped temp dir before signalling completion,
# so no dangling temp files remain after a normally-completed session. Guard against path
# traversal: only run rm -rf when $key is a single safe path segment (matches tmp-dir.sh).
# An unsafe key (path separator or `..`) skips cleanup but STILL emits the sentinel below,
# so the harness releases the slot — we never run rm -rf on a key that could escape ./.tmp.
case "$key" in
  */* | *..*) : ;;                 # unsafe key — skip cleanup, still signal completion
  *) rm -rf "./.tmp/$key" ;;
esac
rm -f ./.tmp/commit-msg.txt ./.tmp/acli-* ./.tmp/*.tmp 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true

pr_url="${1:-}"
if [ -n "$pr_url" ]; then
  printf '<<<SDLC_SESSION_COMPLETE:%s|PR=%s>>>\n' "$key" "$pr_url"
else
  printf '<<<SDLC_SESSION_COMPLETE:%s>>>\n' "$key"
fi
exit 0
