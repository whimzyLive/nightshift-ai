#!/usr/bin/env bash
# session-complete.sh — signal an automation harness that this session's driven phase is done.
# Vendored functional equivalent of the sdlc plugin's session-complete.sh — standalone, no sdlc dependency.
#
# OPTIONAL integration. If you run gtm commands (e.g. `/gtm:init`) non-interactively under an
# automation harness (one that drives an interactive `claude` session and watches its output
# stream), this prints a unique completion marker so the harness can release the session's slot
# immediately instead of waiting for an idle timeout. Outside such a harness it is a silent
# no-op — always safe to run.
#
# Invoked as the FINAL step of each TOP-LEVEL gtm slash command — exactly once per driven session.
#
# Usage:
#   bash session-complete.sh              # bare marker
#
# Contract for harness authors:
#   - Inject GTM_SESSION_KEY into the session's environment per spawn. When it is unset (e.g. a
#     normal local dev session), this script prints nothing and exits 0.
#   - Watch the session output for the marker below and parse it:
#       <<<GTM_SESSION_COMPLETE:KEY>>>

set -uo pipefail   # match the sibling scripts; all vars below are :-guarded so -u is safe

# Dir of this script (fork-free; fall back to "." on a slash-less invocation, e.g. the documented
# `bash session-complete.sh` from the scripts dir — otherwise the sibling resolve would miss and
# cleanup would silently skip while the sentinel still emitted).
here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."

# Happy-path temp cleanup: remove this session's OWN scoped temp dir. Uses the shared resolver
# (GTM_SESSION_KEY / CLAUDE_CODE_SESSION_ID via session-key.sh) so an interactive session is
# cleaned here too, not just a worker session. Scoped-only — it never sweeps loose ./.tmp/*
# files; the trailing rmdir prunes the parent only if already empty, so it is safe when several
# sessions share one checkout (it cannot delete a concurrent session's in-flight files). The
# guard lives in session-key.sh, so a malformed key resolves empty and no rm -rf runs. The
# SessionEnd hook (cleanup-tmp.sh) is the safety net for sessions that never reach this final
# step; this is the normal-completion clean.
clean_key="$(bash "$here/session-key.sh" 2>/dev/null || true)"
[ -n "$clean_key" ] && rm -rf "./.tmp/$clean_key" 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true

# Completion sentinel — WORKER CONTRACT ONLY. Emitted solely when GTM_SESSION_KEY is set (the
# harness injects it). An interactive session (key unset) prints nothing and exits 0 here — but
# its temp dir was already cleaned above, regardless of the sentinel.
key="${GTM_SESSION_KEY:-}"
[ -z "$key" ] && exit 0

printf '<<<GTM_SESSION_COMPLETE:%s>>>\n' "$key"
exit 0
