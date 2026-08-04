#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../ci-retry.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

assert_eq() {
  if [ "$1" = "$2" ]; then
    printf 'ok   %s\n' "$3"
  else
    printf 'FAIL %s\n     expected: %s\n     got:      %s\n' "$3" "$1" "$2"
    fail=1
  fi
}

# --- fixture: a command that always succeeds, counting invocations ---
always_ok="$work/always-ok.sh"
cat > "$always_ok" <<'EOF'
#!/usr/bin/env bash
counter="$1"
count=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter"
exit 0
EOF
chmod +x "$always_ok"

# --- fixture: a command that always fails, counting invocations ---
always_fail="$work/always-fail.sh"
cat > "$always_fail" <<'EOF'
#!/usr/bin/env bash
counter="$1"
count=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter"
exit 7
EOF
chmod +x "$always_fail"

# --- fixture: a command that fails N times then succeeds ---
fail_n_then_ok="$work/fail-n-then-ok.sh"
cat > "$fail_n_then_ok" <<'EOF'
#!/usr/bin/env bash
counter="$1"
fail_until="$2"
count=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter"
if [ "$count" -le "$fail_until" ]; then
  exit 3
fi
exit 0
EOF
chmod +x "$fail_n_then_ok"

# --- fixture project-context files ---
ctx_default="$work/ctx-default"
mkdir -p "$ctx_default/.claude/project"
cat > "$ctx_default/.claude/project/project-context.md" <<'EOF'
## CI

| Token        | Value |
| ------------ | ----- |
| Max attempts | `5`   |
EOF

ctx_two="$work/ctx-two"
mkdir -p "$ctx_two/.claude/project"
cat > "$ctx_two/.claude/project/project-context.md" <<'EOF'
## CI

| Token        | Value |
| ------------ | ----- |
| Max attempts | `2`   |
EOF

ctx_missing_section="$work/ctx-missing-section"
mkdir -p "$ctx_missing_section/.claude/project"
cat > "$ctx_missing_section/.claude/project/project-context.md" <<'EOF'
## Something Else

| Token | Value |
| ----- | ----- |
| Foo   | bar   |
EOF

ctx_malformed="$work/ctx-malformed"
mkdir -p "$ctx_malformed/.claude/project"
cat > "$ctx_malformed/.claude/project/project-context.md" <<'EOF'
## CI

| Token        | Value  |
| ------------ | ------ |
| Max attempts | `many` |
EOF

ctx_absent="$work/ctx-absent"
mkdir -p "$ctx_absent"

# 1. succeeds first time -> exactly 1 run, exit 0
counter="$work/c1"
( cd "$ctx_default" && bash "$tool" "$always_ok" "$counter" )
status=$?
assert_eq "0" "$status" "success-first-time: exit code"
assert_eq "1" "$(cat "$counter")" "success-first-time: exactly 1 invocation"

# 2. always fails -> exactly Max attempts (5, default) runs, exits with command's own status
counter="$work/c2"
( cd "$ctx_default" && bash "$tool" "$always_fail" "$counter" )
status=$?
assert_eq "7" "$status" "always-fails: exits with command's own status (7)"
assert_eq "5" "$(cat "$counter")" "always-fails: exactly 5 invocations (default ceiling)"

# 3. fails twice then succeeds -> exit 0, exactly 3 invocations
counter="$work/c3"
( cd "$ctx_default" && bash "$tool" "$fail_n_then_ok" "$counter" 2 )
status=$?
assert_eq "0" "$status" "fails-twice-then-ok: exit code"
assert_eq "3" "$(cat "$counter")" "fails-twice-then-ok: exactly 3 invocations"

# 4. ceiling actually read from fixture project-context (non-default value 2, exact)
counter="$work/c4"
( cd "$ctx_two" && bash "$tool" "$always_fail" "$counter" )
status=$?
assert_eq "7" "$status" "custom-ceiling: exits with command's own status"
assert_eq "2" "$(cat "$counter")" "custom-ceiling: exactly 2 invocations (config Max attempts = 2, NOT default 5)"

# 5a. missing section falls back to 5, does not fail the wrapper itself
counter="$work/c5a"
( cd "$ctx_missing_section" && bash "$tool" "$always_fail" "$counter" ) 2>"$work/c5a.err"
status=$?
assert_eq "7" "$status" "missing-section: exits with command's own status"
assert_eq "5" "$(cat "$counter")" "missing-section: falls back to default 5 invocations"
grep -q "WARNING" "$work/c5a.err" && printf 'ok   missing-section: warns on stderr\n' || { printf 'FAIL missing-section: expected WARNING on stderr\n'; fail=1; }

# 5b. malformed value falls back to 5
counter="$work/c5b"
( cd "$ctx_malformed" && bash "$tool" "$always_fail" "$counter" ) 2>"$work/c5b.err"
status=$?
assert_eq "5" "$(cat "$counter")" "malformed-value: falls back to default 5 invocations"
grep -q "WARNING" "$work/c5b.err" && printf 'ok   malformed-value: warns on stderr\n' || { printf 'FAIL malformed-value: expected WARNING on stderr\n'; fail=1; }

# 5c. absent file falls back to 5
counter="$work/c5c"
( cd "$ctx_absent" && bash "$tool" "$always_fail" "$counter" ) 2>"$work/c5c.err"
status=$?
assert_eq "5" "$(cat "$counter")" "absent-file: falls back to default 5 invocations"
grep -q "WARNING" "$work/c5c.err" && printf 'ok   absent-file: warns on stderr\n' || { printf 'FAIL absent-file: expected WARNING on stderr\n'; fail=1; }

# 6. CI_MAX_ATTEMPTS env override wins over the file (file says 5, env says 3)
counter="$work/c6"
( cd "$ctx_default" && CI_MAX_ATTEMPTS=3 bash "$tool" "$always_fail" "$counter" )
status=$?
assert_eq "3" "$(cat "$counter")" "env-override: CI_MAX_ATTEMPTS=3 wins over file's 5"

exit "$fail"
