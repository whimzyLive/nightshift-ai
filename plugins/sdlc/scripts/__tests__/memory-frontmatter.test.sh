#!/usr/bin/env bash
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
scripts_dir="$here/.."
fixtures_dir="$here/fixtures/memory-v2"
valid_dir="$fixtures_dir/valid"
invalid_dir="$fixtures_dir/invalid"
legacy_dir="$fixtures_dir/legacy"

check_frontmatter="$scripts_dir/check-frontmatter.sh"
collect_memory="$scripts_dir/collect-memory.sh"

failures=0

echo "=== check-frontmatter.sh <valid> ==="
valid_out="$(bash "$check_frontmatter" "$valid_dir" 2>&1)"
valid_exit=$?
if [ "$valid_exit" -eq 0 ]; then
  echo "PASS: check-frontmatter.sh valid fixture exits 0"
else
  echo "FAIL: check-frontmatter.sh valid fixture — expected exit 0, got $valid_exit"
  printf '%s\n' "$valid_out"
  failures=$((failures + 1))
fi

echo "=== check-frontmatter.sh <invalid> ==="
invalid_out="$(bash "$check_frontmatter" "$invalid_dir" 2>&1)"
invalid_exit=$?
if [ "$invalid_exit" -eq 1 ]; then
  echo "PASS: check-frontmatter.sh invalid fixture exits 1"
else
  echo "FAIL: check-frontmatter.sh invalid fixture — expected exit 1, got $invalid_exit"
  failures=$((failures + 1))
fi

for needle in \
  "id-mismatch.md" \
  "duplicate id 'duplicate-rule-id'" \
  "omits-self.md" \
  "single-agent-shared.md" \
  "root_causes token 'not-a-real-token'" \
  "2026-07-25-NA-81.md"; do
  if printf '%s' "$invalid_out" | grep -qF "$needle"; then
    echo "PASS: invalid fixture output names offender matching '$needle'"
  else
    echo "FAIL: invalid fixture output missing offender matching '$needle'"
    failures=$((failures + 1))
  fi
done

echo "=== check-frontmatter.sh <legacy> ==="
legacy_out="$(bash "$check_frontmatter" "$legacy_dir" 2>&1)"
legacy_exit=$?
if [ "$legacy_exit" -eq 0 ]; then
  echo "PASS: check-frontmatter.sh legacy fixture exits 0"
else
  echo "FAIL: check-frontmatter.sh legacy fixture — expected exit 0, got $legacy_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$legacy_out" | grep -qF "WARNING"; then
  echo "PASS: check-frontmatter.sh legacy fixture warns on stderr"
else
  echo "FAIL: check-frontmatter.sh legacy fixture produced no WARNING"
  failures=$((failures + 1))
fi

echo "=== collect-memory.sh web-engineer <valid> ==="
collect_out="$(bash "$collect_memory" web-engineer "$valid_dir" 2>&1)"
collect_exit=$?
if [ "$collect_exit" -eq 0 ]; then
  echo "PASS: collect-memory.sh valid fixture exits 0"
else
  echo "FAIL: collect-memory.sh valid fixture — expected exit 0, got $collect_exit"
  failures=$((failures + 1))
fi
for needle in \
  "RULE prefer-server-component" \
  "RULE stage-explicit-paths" \
  "ADR 0001"; do
  if printf '%s' "$collect_out" | grep -qF "$needle"; then
    echo "PASS: collect-memory.sh valid fixture emits '$needle'"
  else
    echo "FAIL: collect-memory.sh valid fixture missing '$needle'"
    failures=$((failures + 1))
  fi
done
if printf '%s' "$collect_out" | grep -q "reviews"; then
  echo "FAIL: collect-memory.sh valid fixture emitted a reviews/ reference — reviews are never collected"
  failures=$((failures + 1))
else
  echo "PASS: collect-memory.sh valid fixture never emits review files"
fi

echo "=== collect-memory.sh web-engineer <legacy> ==="
legacy_collect_out="$(bash "$collect_memory" web-engineer "$legacy_dir" 2>&1)"
legacy_collect_exit=$?
if [ "$legacy_collect_exit" -eq 0 ]; then
  echo "PASS: collect-memory.sh legacy fixture exits 0"
else
  echo "FAIL: collect-memory.sh legacy fixture — expected exit 0, got $legacy_collect_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$legacy_collect_out" | grep -qF "LEGACY"; then
  echo "PASS: collect-memory.sh legacy fixture emits the LEGACY banner"
else
  echo "FAIL: collect-memory.sh legacy fixture missing the LEGACY banner"
  failures=$((failures + 1))
fi

echo "=== collect-memory.sh with no argument ==="
noarg_out="$(bash "$collect_memory" 2>&1)"
noarg_exit=$?
if [ "$noarg_exit" -eq 1 ]; then
  echo "PASS: collect-memory.sh with no argument exits 1"
else
  echo "FAIL: collect-memory.sh with no argument — expected exit 1, got $noarg_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$noarg_out" | grep -qF "usage:"; then
  echo "PASS: collect-memory.sh with no argument prints a usage line"
else
  echo "FAIL: collect-memory.sh with no argument printed no usage line"
  failures=$((failures + 1))
fi

echo "=== collect-memory.sh dual-root mode (NA-101) ==="
dual_tmp="$(mktemp -d)"; dual_tmp="$(cd "$dual_tmp" && pwd -P)"
dual_repo="$dual_tmp/repo"; mkdir -p "$dual_repo/.claude/memories/agents/web-engineer"
git -C "$dual_repo" init -q
git -C "$dual_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
dual_root="$dual_tmp/memroot"; mkdir -p "$dual_root/agents/web-engineer"

write_rule() { # $1 = path, $2 = id, $3 = rule text
  cat > "$1" <<EOF
---
id: $2
agent: [web-engineer]
trigger: [a trigger phrase]
rule: $3
evidence: [AB-1]
uses: 0
status: active
---
EOF
}
write_rule "$dual_repo/.claude/memories/agents/web-engineer/legacy-rule.md" legacy-rule "Legacy copy."
write_rule "$dual_root/agents/web-engineer/resolved-rule.md" resolved-rule "Resolved copy."
write_rule "$dual_repo/.claude/memories/agents/web-engineer/both-rule.md" both-rule "Legacy version of both-rule."
write_rule "$dual_root/agents/web-engineer/both-rule.md" both-rule "Resolved version of both-rule."

dual_out="$( cd "$dual_repo" && SDLC_MEMORY_ROOT="$dual_root" bash "$collect_memory" web-engineer 2>/dev/null )"
for needle in "RULE legacy-rule" "RULE resolved-rule"; do
  if printf '%s' "$dual_out" | grep -qF "$needle"; then
    echo "PASS: dual mode emits '$needle'"
  else
    echo "FAIL: dual mode missing '$needle'"; failures=$((failures + 1))
  fi
done
dup_n="$(printf '%s\n' "$dual_out" | grep -c '^RULE both-rule ')"
if [ "$dup_n" -eq 1 ] && printf '%s' "$dual_out" | grep -qF "Resolved version of both-rule."; then
  echo "PASS: a rule id present in both roots is emitted once, resolved root winning"
else
  echo "FAIL: dedupe/precedence wrong — count=$dup_n"; failures=$((failures + 1))
fi

# resolver failure in DUAL mode -> WARNING on stderr, legacy root still collected, exit 0
warn_file="$dual_tmp/warn"
warn_out="$( cd "$dual_repo" && env -u XDG_DATA_HOME SDLC_MEMORY_ROOT="relative-path" bash "$collect_memory" web-engineer 2>"$warn_file" )"; warn_rc=$?
if [ "$warn_rc" -eq 0 ] && [ -s "$warn_file" ] && printf '%s' "$warn_out" | grep -qF "RULE legacy-rule"; then
  echo "PASS: resolver failure warns, falls back to the legacy root, and still exits 0"
else
  echo "FAIL: resolver-failure fallback — rc=$warn_rc"; failures=$((failures + 1))
fi
rm -rf "$dual_tmp"

echo "=== check-frontmatter.sh dual-root mode (NA-101) ==="
cf_tmp="$(mktemp -d)"; cf_tmp="$(cd "$cf_tmp" && pwd -P)"
cf_repo="$cf_tmp/repo"; mkdir -p "$cf_repo/.claude/memories/agents/web-engineer"
git -C "$cf_repo" init -q
git -C "$cf_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
cf_root="$cf_tmp/memroot"; mkdir -p "$cf_root/agents/web-engineer"

cat > "$cf_root/agents/web-engineer/broken-in-resolved.md" <<'EOF'
---
id: wrong-id-stem
agent: [web-engineer]
trigger: [a trigger phrase]
rule: A rule.
evidence: [AB-1]
uses: 0
status: active
---
EOF
out="$( cd "$cf_repo" && SDLC_MEMORY_ROOT="$cf_root" bash "$check_frontmatter" 2>&1 )"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF "broken-in-resolved.md"; then
  echo "PASS: an offender in the resolved root fails the dual-mode gate"
else
  echo "FAIL: resolved-root offender not caught — rc=$rc"; failures=$((failures + 1))
fi
rm -f "$cf_root/agents/web-engineer/broken-in-resolved.md"

# the SAME id in both roots is expected mid-migration and must NOT be a duplicate-id offender
for r in "$cf_repo/.claude/memories" "$cf_root"; do
  mkdir -p "$r/agents/web-engineer"
  cat > "$r/agents/web-engineer/same-id.md" <<'EOF'
---
id: same-id
agent: [web-engineer]
trigger: [a trigger phrase]
rule: A rule.
evidence: [AB-1]
uses: 0
status: active
---
EOF
done
out="$( cd "$cf_repo" && SDLC_MEMORY_ROOT="$cf_root" bash "$check_frontmatter" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qF "duplicate id 'same-id'"; then
  echo "PASS: duplicate-id detection is scoped per root, never across roots"
else
  echo "FAIL: cross-root duplicate id wrongly reported — rc=$rc"; failures=$((failures + 1))
fi
if printf '%s' "$out" | grep -qF "file(s) validated under $cf_root"; then
  echo "PASS: dual mode prints a per-root validated-file count"
else
  echo "FAIL: per-root count line missing"; failures=$((failures + 1))
fi

# neither root present -> the new absent-root line, exit 0
absent_repo="$cf_tmp/absent"; mkdir -p "$absent_repo"
git -C "$absent_repo" init -q
git -C "$absent_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
out="$( cd "$absent_repo" && SDLC_MEMORY_ROOT="$cf_tmp/never-created" bash "$check_frontmatter" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "no memory root present (0 files validated)"; then
  echo "PASS: absent roots print the new absent-root line and exit 0"
else
  echo "FAIL: absent-root contract — rc=$rc out='$out'"; failures=$((failures + 1))
fi

# resolver failure in dual mode -> RESOLVER-FAILED on stderr, legacy validated anyway, exit 1
err_file="$cf_tmp/err"
out="$( cd "$cf_repo" && env -u XDG_DATA_HOME SDLC_MEMORY_ROOT="relative-path" bash "$check_frontmatter" 2>"$err_file" )"; rc=$?
if [ "$rc" -eq 1 ] && grep -qF "RESOLVER-FAILED" "$err_file"; then
  echo "PASS: a resolver failure never reads as a green gate"
else
  echo "FAIL: RESOLVER-FAILED contract — rc=$rc"; failures=$((failures + 1))
fi
rm -rf "$cf_tmp"

if [ "$failures" -ne 0 ]; then
  echo
  echo "memory-frontmatter.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "memory-frontmatter.test.sh: PASS — all assertions passed"
exit 0
