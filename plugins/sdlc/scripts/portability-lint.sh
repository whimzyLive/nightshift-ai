#!/usr/bin/env bash
# Fails if any project token leaks into the generic plugin tree.
#
# Excluded by design:
#   portability-lint.sh  — self-matches its own pattern string.
#   session-complete.sh  — the jugaad-worker completion-IPC shim. Its JUGAAD_SESSION_KEY /
#                          JUGAAD_SESSION_COMPLETE contract is intentionally coupled to that
#                          worker (and is a silent no-op in every other repo). Cannot be
#                          genericized without editing the worker source, which is out of scope.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pattern='jugaad-bot|EdgeTechStudio|ET-[0-9]|edgetechstudio\.atlassian|agent-sandbox|\bSST\b|electrodb|\bhono\b|powersync|Next\.js|\bExpo\b|TypeORM|Zustand|\bpnpm\b|apps/(web|mobile|backend)|packages/'
hits=$(grep -rInE "$pattern" \
  --exclude=portability-lint.sh --exclude=session-complete.sh \
  "$root/agents" "$root/commands" "$root/refs" "$root/skills" "$root/scripts" \
  2>/dev/null || true)
if [ -n "$hits" ]; then
  echo "PORTABILITY LINT FAILED — project tokens in generic tree:"
  echo "$hits"
  exit 1
fi
echo "portability-lint: clean (0 project tokens)"
