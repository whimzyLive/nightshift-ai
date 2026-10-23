#!/usr/bin/env bash
# assess-ready.test.sh — /auto Step 1 label probes (AI-Ready, Spec-Approved) against a mocked acli.
#   bash plugins/sdlc/scripts/__tests__/assess-ready.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../assess-ready.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/bin"
cp "$src" "$work/scripts/assess-ready.sh"
cat > "$work/scripts/jira-site-guard.sh" <<'EOF'
#!/usr/bin/env bash
[ "${MOCK_GUARD_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF

# MOCK_READY / MOCK_SPEC: hit | none | other | error | garbage — answer for that label's probe.
# Real acli 1.3.22 shapes: full objects without --fields; `[null]` per hit with `--fields key`.
cat > "$work/bin/acli" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'"AI-Ready"'*) mode="${MOCK_READY:-none}" ;;
  *'"Spec-Approved"'*) mode="${MOCK_SPEC:-none}" ;;
  *) mode=none ;;
esac
fields=no; case "$*" in *--fields*) fields=yes ;; esac
case "$mode" in
  hit) if [ "$fields" = yes ]; then echo '[null]'; else echo '[{"key":"S-1","fields":{"summary":"s"}}]'; fi ;;
  other) if [ "$fields" = yes ]; then echo '[null]'; else echo '[{"key":"S-10","fields":{"summary":"s"}}]'; fi ;;
  none) echo '[]' ;;
  error) exit 1 ;;
  garbage) echo 'not-json' ;;
esac
EOF
chmod +x "$work/bin/acli" "$work/scripts/"*.sh

pass=0 fail=0
check() {
  local name="$1" want_rc="$2" want="$3"; shift 3
  local out rc
  out="$(env PATH="$work/bin:$PATH" "$@" bash "$work/scripts/assess-ready.sh" S-1 2>&1 | tr '\n' ' ')"; rc=${PIPESTATUS[0]}
  out="${out% }"
  if [ "$rc" -eq "$want_rc" ] && [ "$out" = "$want" ]; then
    pass=$((pass + 1)); echo "ok   $name"
  else
    fail=$((fail + 1)); echo "FAIL $name (rc=$rc, want $want_rc, out '$out', want '$want')"
  fi
}

check "ready, spec not approved"               0 "AI_READY=yes SPEC_APPROVED=no"          MOCK_READY=hit
check "ready and spec approved"                0 "AI_READY=yes SPEC_APPROVED=yes"         MOCK_READY=hit MOCK_SPEC=hit
check "neither label"                          0 "AI_READY=no SPEC_APPROVED=no"
check "a different key never counts"           0 "AI_READY=no SPEC_APPROVED=no"           MOCK_READY=other MOCK_SPEC=other
check "acli error is unknown, not 'no'"        1 "AI_READY=unknown SPEC_APPROVED=no"      MOCK_READY=error
check "unparseable output is unknown"          1 "AI_READY=yes SPEC_APPROVED=unknown"     MOCK_READY=hit MOCK_SPEC=garbage
check "site guard failure is unknown for both" 1 "AI_READY=unknown SPEC_APPROVED=unknown" MOCK_GUARD_FAIL=1 MOCK_READY=hit

echo "assess-ready: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
