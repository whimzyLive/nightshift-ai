#!/usr/bin/env bash
# library-blockers.test.sh — pins scripts/library-blockers.sh: the JQL it sends (label from the
# `Library label` token, default Library), the BLOCKERS line, and the fail-closed exits. acli is mocked.
#   bash plugins/sdlc/scripts/__tests__/library-blockers.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/bin"
cp "$here/../library-blockers.sh" "$work/scripts/"
printf '#!/usr/bin/env bash\n[ "${MOCK_GUARD_FAIL:-0}" = 1 ] && { echo wrong-site >&2; exit 1; }\nexit 0\n' >"$work/scripts/jira-site-guard.sh"
cat >"$work/bin/acli" <<'EOF2'
#!/usr/bin/env bash
echo "$*" >>"$MOCK_LOG"
[ "${MOCK_ACLI_FAIL:-0}" = 1 ] && exit 1
case "${MOCK_RESULT:-none}" in
  two)  echo '[{"key":"L-1"},{"key":"L-2"}]' ;;
  junk) echo 'not json' ;;
  *)    echo '[]' ;;
esac
EOF2
chmod +x "$work/bin/acli" "$work/scripts/"*.sh

failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
run() { env PATH="$work/bin:$PATH" MOCK_LOG="$work/log" "$@" bash "$work/scripts/library-blockers.sh" EP-1 --context "$work/ctx.md" 2>&1; echo "rc=$?"; }
: >"$work/log"; printf '| Library label | `Widgets` |\n' >"$work/ctx.md"

out="$(run MOCK_RESULT=two | paste -sd' ' -)"
check "lists blockers"            "BLOCKERS=L-1 L-2 rc=0" "$out"
check "label from the token"      1 "$(grep -c 'labels = "Widgets"' "$work/log")"
check "excludes Done, scopes to the Epic" 1 "$(grep -c 'parent = EP-1 AND .* statusCategory != Done' "$work/log")"
check "none -> empty list"        "BLOCKERS= rc=0" "$(run MOCK_RESULT=none | paste -sd' ' -)"
rm "$work/ctx.md"; : >"$work/log"; run MOCK_RESULT=none >/dev/null
check "default label"             1 "$(grep -c 'labels = "Library"' "$work/log")"
check "--label wins" 1 "$(env PATH="$work/bin:$PATH" MOCK_LOG="$work/log" bash "$work/scripts/library-blockers.sh" EP-1 --label Foo >/dev/null 2>&1; grep -c 'labels = "Foo"' "$work/log")"
check "acli failure fails closed" "REASON=cannot list library stories of EP-1 (cannot verify) rc=1" "$(run MOCK_ACLI_FAIL=1 | paste -sd' ' -)"
check "junk output fails closed"  "rc=1" "$(run MOCK_RESULT=junk | grep -o 'rc=.*')"
check "site guard fails closed"   "rc=1" "$(run MOCK_GUARD_FAIL=1 | grep -o 'rc=.*')"
check "bad label rejected" "rc=1" "$(env PATH="$work/bin:$PATH" MOCK_LOG="$work/log" bash "$work/scripts/library-blockers.sh" EP-1 --label 'a"b' >/dev/null 2>&1; echo "rc=$?")"

if [ "$failures" -eq 0 ]; then echo "PASS: library-blockers"; exit 0; fi
echo "FAIL: $failures library-blockers case(s) failed"; exit 1
