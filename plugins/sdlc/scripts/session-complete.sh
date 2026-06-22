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

here="${BASH_SOURCE[0]%/*}"

# Happy-path temp cleanup, BOTH modes: remove this session's OWN scoped temp dir. Uses the shared
# resolver (SDLC_SESSION_KEY / CLAUDE_CODE_SESSION_ID via session-key.sh) so an interactive session
# is cleaned here too, not just a worker session. Scoped-only — it never sweeps loose ./.tmp/* files,
# so it is safe when several sessions share one checkout (it cannot delete a concurrent session's
# in-flight files). The traversal guard lives in session-key.sh, so a malformed key resolves empty
# and no rm -rf runs. The SessionEnd hook (cleanup-tmp.sh) is the safety net for sessions that never
# reach this final step; this is the normal-completion clean.
clean_key="$(bash "$here/session-key.sh" 2>/dev/null || true)"
[ -n "$clean_key" ] && rm -rf "./.tmp/$clean_key" 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true

# Completion sentinel — WORKER CONTRACT ONLY. Emitted solely when SDLC_SESSION_KEY is set (the
# harness injects it). An interactive session (key unset) prints nothing and exits 0 here — but
# its temp dir was already cleaned above, regardless of the sentinel.
key="${SDLC_SESSION_KEY:-}"
[ -z "$key" ] && exit 0

pr_url="${1:-}"
if [ -n "$pr_url" ]; then
  printf '<<<SDLC_SESSION_COMPLETE:%s|PR=%s>>>\n' "$key" "$pr_url"
else
  printf '<<<SDLC_SESSION_COMPLETE:%s>>>\n' "$key"
fi
exit 0
