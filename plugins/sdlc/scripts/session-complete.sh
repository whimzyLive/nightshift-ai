#!/usr/bin/env bash
# session-complete.sh — signal the jugaad SDLC worker that this session's driven phase is done.
#
# The worker drives an INTERACTIVE `claude` session over a PTY (to bill the flat subscription,
# not metered headless credits) and watches the PTY output stream for a unique completion marker.
# Printing that marker lets the worker terminate this session and release its concurrency slot
# immediately, instead of waiting for the idle-timeout fallback.
#
# Invoked as the FINAL step of each SDLC slash command (see ${CLAUDE_PLUGIN_ROOT}/commands/*.md).
#
# Usage:
#   bash session-complete.sh              # bare marker — no PR (refine/review-fix/folded-plan)
#   bash session-complete.sh <pr-url>     # marker with optional |PR=<url> suffix (spec/plan/impl)
#
# - Reads JUGAAD_SESSION_KEY, injected per-spawn by the worker (packages/worker/src/sessions/
#   pty-session.ts -> buildSpawnEnv). Outside the worker the var is unset -> silent no-op, so the
#   command is harmless to run in a normal local dev session.
# - CONTRACT: the printed marker MUST stay in lockstep with completionSentinel() AND
#   parseSentinelPrUrl() in packages/worker/src/sessions/completion-watcher.ts.
#   Bare form:    <<<JUGAAD_SESSION_COMPLETE:KEY>>>
#   PR form:      <<<JUGAAD_SESSION_COMPLETE:KEY|PR=URL>>>

key="${JUGAAD_SESSION_KEY:-}"
[ -z "$key" ] && exit 0

pr_url="${1:-}"
if [ -n "$pr_url" ]; then
  printf '<<<JUGAAD_SESSION_COMPLETE:%s|PR=%s>>>\n' "$key" "$pr_url"
else
  printf '<<<JUGAAD_SESSION_COMPLETE:%s>>>\n' "$key"
fi
exit 0
