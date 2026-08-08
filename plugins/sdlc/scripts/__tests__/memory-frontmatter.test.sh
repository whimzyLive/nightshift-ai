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

# neither root present -> the explicit SKIP line (NA-103), exit 0 — never a silent pass
absent_repo="$cf_tmp/absent"; mkdir -p "$absent_repo"
git -C "$absent_repo" init -q
git -C "$absent_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
out="$( cd "$absent_repo" && SDLC_MEMORY_ROOT="$cf_tmp/never-created" bash "$check_frontmatter" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "SKIP: no memory root"; then
  echo "PASS: absent roots print the explicit SKIP: no memory root line and exit 0"
else
  echo "FAIL: absent-root SKIP contract — rc=$rc out='$out'"; failures=$((failures + 1))
fi

# resolver failure in dual mode -> RESOLVER-FAILED on stderr, legacy validated anyway, exit 1
err_file="$cf_tmp/err"
out="$( cd "$cf_repo" && env -u XDG_DATA_HOME SDLC_MEMORY_ROOT="relative-path" bash "$check_frontmatter" 2>"$err_file" )"; rc=$?
if [ "$rc" -eq 1 ] && grep -qF "RESOLVER-FAILED" "$err_file"; then
  echo "PASS: a resolver failure never reads as a green gate"
else
  echo "FAIL: RESOLVER-FAILED contract — rc=$rc"; failures=$((failures + 1))
fi
# --- Success-path stderr contamination regression (QA re-review): a hasher that warns to stderr
# but exits 0 must not contaminate the resolved value — a naive `resolved="$(sdlc_memory_root
# 2>&1)"` on the SUCCESS path would prepend that warning text to the path, making `[ -d "$resolved"
# ]` fail and silently dropping the resolved root (1 validated instead of 2, no RESOLVER-FAILED).
# SDLC_MEMORY_ROOT bypasses the hasher entirely (it short-circuits before sdlc_repo_key), so this
# MUST exercise the XDG_DATA_HOME default-resolution path, which does call sdlc_mr_hash8.
warn_bin="$cf_tmp/warn-bin"; mkdir -p "$warn_bin"
for c in bash git sed cut basename dirname tr head awk mkdir grep sort uniq paste cat find; do
  real="$(command -v "$c" 2>/dev/null)" || continue
  ln -sf "$real" "$warn_bin/$c"
done
cat > "$warn_bin/shasum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf 'perl: warning: Setting locale failed.\n' >&2
printf 'perl: warning: Falling back to the standard locale ("C").\n' >&2
printf '%s\n' "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  -"
EOF
chmod +x "$warn_bin/shasum"

warn_repo="$cf_tmp/warnrepo"; mkdir -p "$warn_repo/.claude/memories/agents/web-engineer"
git -C "$warn_repo" init -q
git -C "$warn_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
warn_xdg="$cf_tmp/warn-xdg"
# Compute the key using the SAME stub hasher the actual run below uses (its fixed fake hash),
# not the real one — otherwise the pre-seeded content lands under a DIFFERENT path than the one
# the warning-hasher run resolves to.
warn_key="$( cd "$warn_repo" && env -u SDLC_MEMORY_ROOT -u XDG_DATA_HOME PATH="$warn_bin" bash "$here/../memory-root.sh" --print-key 2>/dev/null )"
warn_resolved="$warn_xdg/sdlc/memories/$warn_key"
mkdir -p "$warn_resolved/agents/web-engineer"
write_rule "$warn_resolved/agents/web-engineer/resolved-under-warning.md" resolved-under-warning "Seen despite the warning."

out="$( cd "$warn_repo" && env -u SDLC_MEMORY_ROOT PATH="$warn_bin" XDG_DATA_HOME="$warn_xdg" HOME="$cf_tmp/home" \
  bash "$check_frontmatter" 2>&1 )"; rc=$?
validated_lines="$(printf '%s' "$out" | grep -c 'file(s) validated under')"
if [ "$rc" -eq 0 ] && [ "$validated_lines" -eq 2 ] \
  && printf '%s' "$out" | grep -qF "file(s) validated under $warn_resolved" \
  && ! printf '%s' "$out" | grep -qi 'warning: Setting locale'; then
  echo "PASS: a warning-emitting hasher on the success path does not contaminate the resolved root; both roots still validated"
else
  echo "FAIL: success-path stderr contamination — rc=$rc validated-lines=$validated_lines out='$out'"; failures=$((failures + 1))
fi

# --- Important-1 regression (PR #234 review): from a LINKED worktree, a capture staged in the
# PRIMARY checkout must still be seen. captured/** is untracked and lives only in the primary, so
# the legacy entry's captured-scan must resolve via sdlc_primary_worktree, not <git-toplevel> (which
# is the linked worktree's own — empty — tree). SDLC_MEMORY_ROOT points at a never-created dir so
# only the legacy (primary-resolved) entry is active, isolating the exact behaviour under test.
li_tmp="$(mktemp -d)"; li_tmp="$(cd "$li_tmp" && pwd -P)"
li_primary="$li_tmp/primary"; mkdir -p "$li_primary/.claude/memories/agents/shared"
git -C "$li_primary" init -q
# .claude/memories/** is TRACKED content (per /sdlc:init scaffolding) so it exists identically in
# every worktree — only captured/** (gitignored) is primary-only. Commit a placeholder so the
# linked worktree below has a real .claude/memories dir, matching a real post-init checkout.
: > "$li_primary/.claude/memories/agents/shared/.gitkeep"
git -C "$li_primary" add .claude
git -C "$li_primary" -c user.email=t@t -c user.name=t commit -q -m "seed .claude/memories"
git -C "$li_primary" worktree add -q "$li_tmp/linked" -b linked-cf-test >/dev/null 2>&1
mkdir -p "$li_primary/.claude/memories/captured/rules"
cat > "$li_primary/.claude/memories/captured/rules/AB-9--broken.md" <<'EOF'
---
id: mismatched-id
agent: [web-engineer]
trigger: [a trigger phrase]
rule: A rule.
evidence: [AB-9]
uses: 0
status: captured
captured: 2026-08-04T00:00:00Z
story: AB-9
origin: domain-agent
promote-target: /absolute/bogus/path.md
---
EOF
li_out="$( cd "$li_tmp/linked" && env -u SDLC_MEMORY_ROOT SDLC_MEMORY_ROOT="$li_tmp/never-created" bash "$check_frontmatter" 2>&1 )"; li_rc=$?
if [ "$li_rc" -eq 0 ] && printf '%s' "$li_out" | grep -qF "AB-9--broken.md" \
  && printf '%s' "$li_out" | grep -qF "1 file(s) validated under $li_tmp/linked/.claude/memories"; then
  echo "PASS: check-frontmatter.sh from a linked worktree sees a capture staged in the primary (Important-1, PR #234)"
else
  echo "FAIL: linked-worktree primary-capture blindness — rc=$li_rc out='$li_out'"; failures=$((failures + 1))
fi
rm -rf "$li_tmp"

rm -rf "$cf_tmp"

# --- NA-103 Critical 1: AC5 + AC2 combined to kill AC3 — a fresh CI checkout has NOTHING tracked
# under `.claude/memories/` (AC5 deletes the last tracked file), so the resolver's SKIP path used
# to `exit 0` BEFORE the docs/adr/*.md frontmatter loop ever ran, silently disabling the only ADR
# frontmatter guard in the repo. This is a base-vs-head comparison, not a message assertion — it
# proves the OLD script misses a planted violation and the CURRENT script catches it, on the
# identical fixture. "Base" is reconstructed by re-mutating the LIVE, checked-out script (re-insert
# the one `exit 0` the fix removed) rather than `git show <sha>:...` — self-contained, no
# dependency on any commit staying reachable after this branch merges (re-review Minor finding).
c1_tmp="$(mktemp -d)"; c1_tmp="$(cd "$c1_tmp" && pwd -P)"

# Fresh-CI-checkout fixture: a git repo with NOTHING under .claude/memories/ (not even the
# directory) and one ADR whose frontmatter opens on line 2, not line 1.
c1_repo="$c1_tmp/repo"; mkdir -p "$c1_repo/docs/adr"
git -C "$c1_repo" init -q
cat > "$c1_repo/docs/adr/0099-bad-adr.md" <<'EOF'

---
status: accepted
agents: [web-engineer]
---

# 0099. A bad ADR whose frontmatter does not open on line 1
EOF
git -C "$c1_repo" -c user.email=t@t -c user.name=t add -A
git -C "$c1_repo" -c user.email=t@t -c user.name=t commit -q -m "fresh checkout fixture"

# Base: the live check-frontmatter.sh with the historical bug re-inserted — an `exit 0` right
# after the SKIP line, exactly as it read before this fix. Derived from today's actual file (never
# a frozen duplicate that can drift), and asserted below to have actually applied.
c1_base_dir="$c1_tmp/base-scripts"; mkdir -p "$c1_base_dir"
awk '{print} /SKIP: no memory root/{print "  exit 0"}' "$check_frontmatter" > "$c1_base_dir/check-frontmatter.sh"
if grep -A1 -F 'SKIP: no memory root' "$c1_base_dir/check-frontmatter.sh" | grep -qF 'exit 0'; then
  echo "PASS: base mutation actually re-inserted the historical exit 0 after the SKIP line"
else
  echo "FAIL: base mutation did not apply — the SKIP line's shape in check-frontmatter.sh changed; update this test's awk pattern"
  failures=$((failures + 1))
fi
cp "$scripts_dir/memory-root.sh" "$c1_base_dir/memory-root.sh"
chmod +x "$c1_base_dir/check-frontmatter.sh"

# HEAD: the currently checked-out (fixed) script.
c1_home="$c1_tmp/home"; mkdir -p "$c1_home"          # hermetic; never resolves to a real corpus
run_c1() { # $1 = script path
  ( cd "$c1_repo" && env -i HOME="$c1_home" PATH="$PATH" XDG_DATA_HOME="$c1_tmp/never-created" \
      SDLC_MEMORY_ROOT="$c1_tmp/never-created" bash "$1" )
}

base_out="$(run_c1 "$c1_base_dir/check-frontmatter.sh" 2>&1)"; base_rc=$?
if [ "$base_rc" -eq 0 ]; then
  echo "PASS: base (pre-fix mutation) reproduces the defect — exits 0, missing the planted bad ADR"
else
  echo "FAIL: base (pre-fix mutation) did not reproduce the defect — expected exit 0, got $base_rc: $base_out"
  failures=$((failures + 1))
fi

head_out="$(run_c1 "$check_frontmatter" 2>&1)"; head_rc=$?
if [ "$head_rc" -eq 1 ] && printf '%s' "$head_out" | grep -qF "0099-bad-adr.md"; then
  echo "PASS: head (fixed) catches the planted bad ADR — exits 1, names the file"
else
  echo "FAIL: head did not catch the planted bad ADR — rc=$head_rc out='$head_out'"
  failures=$((failures + 1))
fi
rm -rf "$c1_tmp"

if [ "$failures" -ne 0 ]; then
  echo
  echo "memory-frontmatter.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "memory-frontmatter.test.sh: PASS — all assertions passed"
exit 0
