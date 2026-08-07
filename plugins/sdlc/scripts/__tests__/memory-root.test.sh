#!/usr/bin/env bash
# memory-root.test.sh — NA-101. Contract suite for memory-root.sh (R1-R14 of the spec).
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/memory-root.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# HERMETICITY: every case that resolves a root runs with HOME and XDG_DATA_HOME (or
# SDLC_MEMORY_ROOT) pointed inside $tmp. An unguarded --print-root/--ensure would otherwise
# materialise ${HOME}/.local/share/sdlc/memories/... on every dev machine and CI runner, which
# nothing cleans up.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../memory-root.sh"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

tmp="$(mktemp -d)"; tmp="$(cd "$tmp" && pwd -P)"   # canonicalise: git porcelain resolves symlinks
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/xdg"

mk_repo() { # $1 = dir, $2 = optional remote url
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  [ -n "${2:-}" ] && git -C "$1" remote add origin "$2"
  return 0
}
key_of() { # $1 = dir — hermetic, never inherits an operator's own override
  ( cd "$1" && env -u SDLC_MEMORY_ROOT -u XDG_DATA_HOME HOME="$tmp/home" bash "$mr" --print-key )
}
root_of() { # $1 = dir
  ( cd "$1" && env -u SDLC_MEMORY_ROOT XDG_DATA_HOME="$tmp/xdg" HOME="$tmp/home" bash "$mr" --print-root )
}

repo_ssh="$tmp/r-ssh"; mk_repo "$repo_ssh" "git@github.com:acme/widget.git"
repo_http="$tmp/r-http"; mk_repo "$repo_http" "https://github.com/acme/widget.git"
repo_no_remote="$tmp/r-none"; mk_repo "$repo_no_remote"

# --- R1: SDLC_MEMORY_ROOT verbatim, beats XDG_DATA_HOME, trailing / stripped ---------------
got="$( cd "$repo_ssh" && SDLC_MEMORY_ROOT="$tmp/explicit/" XDG_DATA_HOME="$tmp/xdg" HOME="$tmp/home" bash "$mr" --print-root )"
[ "$got" = "$tmp/explicit" ] \
  && ok "(R1) SDLC_MEMORY_ROOT verbatim, beats XDG_DATA_HOME, trailing / stripped" \
  || bad "(R1) SDLC_MEMORY_ROOT verbatim" "got '$got'"

# --- R2: relative SDLC_MEMORY_ROOT -> non-zero, names the variable, creates nothing --------
before="$(find "$tmp" | sort)"
err="$( cd "$repo_ssh" && SDLC_MEMORY_ROOT="rel/path" bash "$mr" --print-root 2>&1 >/dev/null )"; rc=$?
after="$(find "$tmp" | sort)"
{ [ "$rc" -ne 0 ] && printf '%s' "$err" | grep -q 'SDLC_MEMORY_ROOT' && [ "$before" = "$after" ]; } \
  && ok "(R2) relative SDLC_MEMORY_ROOT is a hard error that creates nothing" \
  || bad "(R2) relative SDLC_MEMORY_ROOT" "rc=$rc err='$err'"

# --- R3: XDG_DATA_HOME honoured -----------------------------------------------------------
[ "$(root_of "$repo_ssh")" = "$tmp/xdg/sdlc/memories/$(key_of "$repo_ssh")" ] \
  && ok "(R3) XDG_DATA_HOME honoured" || bad "(R3) XDG_DATA_HOME honoured" "got '$(root_of "$repo_ssh")'"

# --- R4: XDG_DATA_HOME unset -> $HOME/.local/share — PRINT ONLY, create nothing ------------
before="$(find "$tmp" | sort)"
got="$( cd "$repo_ssh" && env -u SDLC_MEMORY_ROOT -u XDG_DATA_HOME HOME="$tmp/home" bash "$mr" --print-root )"
after="$(find "$tmp" | sort)"
{ [ "$got" = "$tmp/home/.local/share/sdlc/memories/$(key_of "$repo_ssh")" ] && [ "$before" = "$after" ]; } \
  && ok "(R4) unset XDG_DATA_HOME falls back to \$HOME/.local/share, creating nothing" \
  || bad "(R4) HOME fallback" "got '$got'"

# --- R5: SSH and HTTPS remotes for the same repo produce one key ---------------------------
k_ssh="$(key_of "$repo_ssh")"; k_http="$(key_of "$repo_http")"
{ [ "$k_ssh" = "$k_http" ] && [ "$k_ssh" = "github-com-acme-widget" ] \
  && printf '%s' "$k_ssh" | grep -qE '^[a-z0-9][a-z0-9-]*$'; } \
  && ok "(R5) SSH and HTTPS remotes agree; .git stripped; lowercase; key shape valid" \
  || bad "(R5) remote slug" "ssh='$k_ssh' http='$k_http'"

# --- R6: no remote -> <basename>-<hash8>; empty slug -> repo-<hash8>; path disambiguates ---
k_none="$(key_of "$repo_no_remote")"
printf '%s' "$k_none" | grep -qE '^r-none-[0-9a-f]{8}$' \
  && ok "(R6a) no remote -> <basename>-<hash8>" || bad "(R6a) no-remote key" "got '$k_none'"
repo_punct="$tmp/+++"; mk_repo "$repo_punct"
k_punct="$(key_of "$repo_punct")"
printf '%s' "$k_punct" | grep -qE '^repo-[0-9a-f]{8}$' \
  && ok "(R6b) all-punctuation basename -> repo-<hash8>" || bad "(R6b) empty-slug fallback" "got '$k_punct'"
mkdir -p "$tmp/a" "$tmp/b"
repo_a="$tmp/a/same"; mk_repo "$repo_a"; repo_b="$tmp/b/same"; mk_repo "$repo_b"
k_a="$(key_of "$repo_a")"; k_b="$(key_of "$repo_b")"
[ "$k_a" != "$k_b" ] \
  && ok "(R6c) same basename at different paths -> different keys" \
  || bad "(R6c) path disambiguation" "both '$k_a'"
shape_bad=""
for k in "$k_none" "$k_punct" "$k_a" "$k_b"; do
  printf '%s' "$k" | grep -qE '^[a-z0-9][a-z0-9-]*$' || shape_bad="$shape_bad '$k'"
done
[ -z "$shape_bad" ] && ok "(R6d) every derived key matches ^[a-z0-9][a-z0-9-]*\$" \
  || bad "(R6d) key shape" "bad keys:$shape_bad"

# --- R7: a linked worktree resolves to the primary's key, with and without a remote --------
git -C "$repo_ssh" worktree add -q "$tmp/linked-ssh" -b l1 >/dev/null 2>&1
git -C "$repo_no_remote" worktree add -q "$tmp/linked-none" -b l2 >/dev/null 2>&1
[ "$(key_of "$tmp/linked-ssh")" = "$k_ssh" ] \
  && ok "(R7a) linked worktree (remote) resolves to the primary's key" \
  || bad "(R7a) linked worktree key" "got '$(key_of "$tmp/linked-ssh")'"
[ "$(key_of "$tmp/linked-none")" = "$k_none" ] \
  && ok "(R7b) linked worktree (no remote) resolves to the primary's key" \
  || bad "(R7b) linked worktree key, no remote" "got '$(key_of "$tmp/linked-none")'"
pw_primary="$( cd "$repo_ssh" && bash -c '. "$1"; sdlc_primary_worktree' _ "$mr" )"
pw_linked="$( cd "$tmp/linked-ssh" && bash -c '. "$1"; sdlc_primary_worktree' _ "$mr" )"
{ [ "$pw_primary" = "$repo_ssh" ] && [ "$pw_linked" = "$repo_ssh" ]; } \
  && ok "(R7c) sdlc_primary_worktree returns the primary from both checkouts" \
  || bad "(R7c) sdlc_primary_worktree" "primary='$pw_primary' linked='$pw_linked'"

# --- R8: two clones of the same remote share a key ----------------------------------------
clone_a="$tmp/clone-a"; mk_repo "$clone_a" "git@github.com:acme/shared.git"
clone_b="$tmp/clone-b"; mk_repo "$clone_b" "https://github.com/acme/shared.git"
[ "$(key_of "$clone_a")" = "$(key_of "$clone_b")" ] \
  && ok "(R8) two clones of one remote share a key" \
  || bad "(R8) clone key sharing" "'$(key_of "$clone_a")' vs '$(key_of "$clone_b")'"

# --- R9: bare repository -> non-zero, no stdout -------------------------------------------
git init -q --bare "$tmp/bare.git"
out="$( cd "$tmp/bare.git" && env -u SDLC_MEMORY_ROOT HOME="$tmp/home" bash "$mr" --print-root 2>/dev/null )"; rc=$?
{ [ "$rc" -ne 0 ] && [ -z "$out" ]; } \
  && ok "(R9) bare repository is a hard error with no stdout" || bad "(R9) bare repository" "rc=$rc out='$out'"

# --- R10: outside any git repo ------------------------------------------------------------
mkdir -p "$tmp/nogit"
out="$( cd "$tmp/nogit" && env -u SDLC_MEMORY_ROOT HOME="$tmp/home" bash "$mr" --print-root 2>/dev/null )"; rc=$?
{ [ "$rc" -ne 0 ] && [ -z "$out" ]; } \
  && ok "(R10a) outside a git repo with SDLC_MEMORY_ROOT unset is a hard error" \
  || bad "(R10a) outside a repo" "rc=$rc out='$out'"
out="$( cd "$tmp/nogit" && SDLC_MEMORY_ROOT="$tmp/outside" bash "$mr" --print-root )"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$out" = "$tmp/outside" ]; } \
  && ok "(R10b) SDLC_MEMORY_ROOT resolves outside a repo without probing git" \
  || bad "(R10b) SDLC_MEMORY_ROOT outside a repo" "rc=$rc out='$out'"

# --- R11: sourcing creates nothing, exits nothing, mutates no shell option -----------------
before="$(find "$tmp" | sort)"
for state in on off; do
  probe="$(
    if [ "$state" = on ]; then set -o pipefail; set -u; shopt -s nullglob
    else set +o pipefail; set +u; shopt -u nullglob; fi
    b4="$(set -o | grep -E '^(pipefail|nounset)'; shopt nullglob)"
    . "$mr"
    af="$(set -o | grep -E '^(pipefail|nounset)'; shopt nullglob)"
    [ "$b4" = "$af" ] && printf 'SAME\n' || printf 'CHANGED\n%s\n---\n%s\n' "$b4" "$af"
  )"
  [ "$probe" = "SAME" ] \
    && ok "(R11-$state) sourcing mutates no shell option (pipefail/nounset/nullglob $state)" \
    || bad "(R11-$state) shell-option mutation on source" "$probe"
done
after="$(find "$tmp" | sort)"
[ "$before" = "$after" ] && ok "(R11c) sourcing creates nothing" || bad "(R11c) sourcing created files" "tree changed"

# --- R13: a >100-char key is truncated, still ends in -<hash8>, still valid ----------------
long="$tmp/$(printf 'x%.0s' $(seq 1 140))"
mk_repo "$long"
k_long="$(key_of "$long")"
{ [ "${#k_long}" -le 100 ] && printf '%s' "$k_long" | grep -qE '^[a-z0-9][a-z0-9-]*-[0-9a-f]{8}$'; } \
  && ok "(R13) over-long key truncated to <= 100, still ends in -<hash8>, still valid" \
  || bad "(R13) key truncation" "len=${#k_long} key='$k_long'"

# --- R14: relative XDG_DATA_HOME is IGNORED (not an error) — print only --------------------
before="$(find "$tmp" | sort)"
pwd_before="$(find "$repo_ssh" | sort)"
got="$( cd "$repo_ssh" && env -u SDLC_MEMORY_ROOT XDG_DATA_HOME="rel/xdg" HOME="$tmp/home" bash "$mr" --print-root )"; rc=$?
after="$(find "$tmp" | sort)"
pwd_after="$(find "$repo_ssh" | sort)"
{ [ "$rc" -eq 0 ] && [ "$got" = "$tmp/home/.local/share/sdlc/memories/$k_ssh" ] \
  && [ "$before" = "$after" ] && [ "$pwd_before" = "$pwd_after" ]; } \
  && ok "(R14) relative XDG_DATA_HOME is ignored, falls back to \$HOME, creates nothing" \
  || bad "(R14) relative XDG_DATA_HOME" "rc=$rc got='$got'"

# --- R12: --ensure creates exactly the five entries; second run is a no-op -----------------
ens="$tmp/ensure-root"
out="$( cd "$repo_ssh" && SDLC_MEMORY_ROOT="$ens" bash "$mr" --ensure )"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$out" = "$ens" ]; } \
  && ok "(R12a) --ensure prints the resolved root" || bad "(R12a) --ensure stdout" "rc=$rc out='$out'"
missing=""
for d in "$ens/agents/shared" "$ens/reviews" "$ens/captured/rules" "$ens/captured/reviews"; do
  [ -d "$d" ] || missing="$missing $d"
done
[ -z "$missing" ] && ok "(R12b) --ensure created the four directories" || bad "(R12b) --ensure directories" "missing:$missing"
[ "$(cat "$ens/captured/.gitignore")" = "$(printf '*\n!.gitignore')" ] \
  && ok "(R12c) captured/.gitignore has the exact bytes" \
  || bad "(R12c) .gitignore bytes" "got '$(cat "$ens/captured/.gitignore")'"
[ -z "$(find "$ens" -name '.gitkeep')" ] \
  && ok "(R12d) --ensure creates no .gitkeep and no per-agent directory" \
  || bad "(R12d) unexpected .gitkeep" "$(find "$ens" -name '.gitkeep')"
printf 'do not clobber\n' > "$ens/agents/shared/keeper.md"
snap1="$(find "$ens" | sort)"
( cd "$repo_ssh" && SDLC_MEMORY_ROOT="$ens" bash "$mr" --ensure >/dev/null )
snap2="$(find "$ens" | sort)"
{ [ "$snap1" = "$snap2" ] && [ "$(cat "$ens/agents/shared/keeper.md")" = "do not clobber" ]; } \
  && ok "(R12e) a second --ensure is a no-op that touches no existing content" \
  || bad "(R12e) --ensure idempotency" "tree or content changed"

# --- R12f: --ensure that cannot create the root is a hard error that creates nothing --------
printf 'not a dir\n' > "$tmp/ensure-blocker"
before="$(find "$tmp" | sort)"
err="$( cd "$repo_ssh" && SDLC_MEMORY_ROOT="$tmp/ensure-blocker/nested" bash "$mr" --ensure 2>&1 >/dev/null )"; rc=$?
after="$(find "$tmp" | sort)"
{ [ "$rc" -ne 0 ] && printf '%s' "$err" | grep -qF "$tmp/ensure-blocker/nested" && [ "$before" = "$after" ]; } \
  && ok "(R12f) an uncreatable root is a hard error naming the path, creating nothing" \
  || bad "(R12f) uncreatable root" "rc=$rc err='$err'"

# --- R12g: --ensure with a SUB-PATH (not the root) blocked by a regular file creates NOTHING,
# not a partial layout (mkdir -p continues past a failed operand — this is the probe-first guard).
ens2="$tmp/ensure-root2"
mkdir -p "$ens2"
printf 'not a dir either\n' > "$ens2/captured"
err2="$( cd "$repo_ssh" && SDLC_MEMORY_ROOT="$ens2" bash "$mr" --ensure 2>&1 >/dev/null )"; rc2=$?
{ [ "$rc2" -ne 0 ] && printf '%s' "$err2" | grep -qF "$ens2/captured" \
  && [ ! -d "$ens2/agents" ] && [ ! -d "$ens2/reviews" ]; } \
  && ok "(R12g) a blocked sub-path is a hard error naming it, creating no sibling directory" \
  || bad "(R12g) blocked sub-path" "rc=$rc2 err='$err2' agents=$([ -d "$ens2/agents" ] && echo present) reviews=$([ -d "$ens2/reviews" ] && echo present)"

# --- R15: HOME, XDG_DATA_HOME and SDLC_MEMORY_ROOT all unset -> hard error, correct message ----
out15="$( cd "$repo_ssh" && env -u SDLC_MEMORY_ROOT -u XDG_DATA_HOME -u HOME bash "$mr" --print-root 2>&1 >/dev/null )"; rc15=$?
{ [ "$rc15" -ne 0 ] && printf '%s' "$out15" | grep -qF 'neither XDG_DATA_HOME (absolute) nor HOME is set'; } \
  && ok "(R15) HOME + XDG_DATA_HOME + SDLC_MEMORY_ROOT all unset is a hard error with the exact reason" \
  || bad "(R15) all-unset hard error" "rc=$rc15 out='$out15'"

# --- R16: no shasum/sha256sum/cksum on PATH -> hard error, correct message ---------------------
stub_bin="$tmp/stub-bin"; mkdir -p "$stub_bin"
for c in bash git sed cut basename tr head awk mkdir; do
  real="$(command -v "$c" 2>/dev/null)" || continue
  ln -sf "$real" "$stub_bin/$c"
done
out16="$( cd "$repo_ssh" && env -u SDLC_MEMORY_ROOT PATH="$stub_bin" HOME="$tmp/home" bash "$mr" --print-root 2>&1 >/dev/null )"; rc16=$?
{ [ "$rc16" -ne 0 ] && printf '%s' "$out16" | grep -qF 'no shasum, sha256sum or cksum available'; } \
  && ok "(R16) no shasum/sha256sum/cksum on PATH is a hard error with the exact reason" \
  || bad "(R16) missing-hasher hard error" "rc=$rc16 out='$out16'"

exit "$fail"
