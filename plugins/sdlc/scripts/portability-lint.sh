#!/usr/bin/env bash
# Fails if any project token leaks into the generic plugin tree.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pattern='jugaad-bot|EdgeTechStudio|ET-[0-9]|edgetechstudio\.atlassian|agent-sandbox|\bSST\b|electrodb|hono|powersync|Next\.js|Expo|TypeORM|Zustand|\bpnpm\b|apps/(web|mobile|backend)|packages/'
hits=$(grep -rInE "$pattern" "$root/agents" "$root/commands" "$root/refs" "$root/skills" "$root/scripts" 2>/dev/null || true)
if [ -n "$hits" ]; then
  echo "PORTABILITY LINT FAILED — project tokens in generic tree:"
  echo "$hits"
  exit 1
fi
echo "portability-lint: clean (0 project tokens)"
