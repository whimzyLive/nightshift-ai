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

exit "$fail"
