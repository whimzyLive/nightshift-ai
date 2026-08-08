#!/usr/bin/env bash
# migrate-memory-root.sh — NA-102. One-shot migration of the in-repo memory corpus
# (.claude/memories/{agents,reviews}) to the external root resolved by memory-root.sh (NA-101).
#
# usage:
#   migrate-memory-root.sh [--dry-run] [--force]
#
# SAFETY CONTRACT — copy, then verify, then delete, in that order, no exceptions:
#   1. Enumerate the tracked corpus via `git ls-files` — this is the EXACT set `git rm --cached`
#      will later remove. Verification and deletion always operate over this same set, never
#      over a directory walk that could silently diverge from it (a tracked-but-locally-deleted
#      file, a broken `find`, a symlinked directory `find` won't descend into, ...).
#   2. Refuse outright if that set is empty but the working tree still holds something at those
#      paths (inconsistent state), if it is non-empty in only one of agents/ or reviews/
#      (partial corpus), if any listed path is missing from disk or is a symlink, or if the
#      resolved destination sits inside this repository.
#   3. cp -R the two tracked trees to the resolved external root.
#   4. Verify EVERY tracked path individually: present at the destination AND checksum-equal.
#      A verification pass requires the matched count to equal the tracked count — an empty or
#      partially-enumerated set can never pass vacuously, because step 2 already refused it.
#   5. Only if verification passes: `git rm --cached --pathspec-from-file` the SAME enumerated
#      list from step 1 (never a directory pathspec, which `git rm` would re-glob against the
#      live index at execution time), delete the working copies (checking its exit status), and
#      commit — scoped to just those two paths, so an operator's unrelated staged work is never
#      swept in. A failure anywhere before step 5 completes leaves the repo's commit history
#      untouched; a failure WITHIN step 5 (e.g. the working-tree delete fails after the index
#      removal already landed) attempts to restore the index via `git reset` and reports whether
#      that restoration itself succeeded, rather than assuming it did.
#
# Never a raw `mv` — the source stays intact on disk until verification has already succeeded.
#
# Every "is X occupied/empty" check in this script (the destination-occupancy probe, the
# collision pre-scan) is written so that an EMPTY result can only mean "confirmed nothing is
# there" — never "a directory walk didn't happen to find anything" (`find` does not descend into
# a symlinked directory, so a destination that IS a symlink to a populated external directory
# would read as empty to a `find`-based probe). The collision pre-scan runs unconditionally,
# never gated behind that occupancy flag.
#
# --force additionally allows merging into an already non-empty destination (AC4), but still
# refuses if any tracked file would collide with — and silently clobber — existing destination
# content, checked via `-e || -L` so a dangling symlink squatting on the path still counts.
#
# Idempotent: once the corpus has been migrated, nothing is left tracked under those two paths,
# so a re-run finds nothing to do and exits 0 without touching anything.
#
# `.claude/memories/captured/` is untracked/gitignored and is intentionally NOT part of this
# migration — see NA-102.
#
# Bash 3.2 compatible: no associative arrays, no mapfile.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/memory-root.sh"

usage() {
  printf 'usage: migrate-memory-root.sh [--dry-run] [--force]\n' >&2
}

# sdlc_mm_checksum <file> -> a content checksum, portable across the same hasher fallback chain
# memory-root.sh already uses. Returns non-zero (and prints why) if no hasher is available OR
# the file could not actually be read (e.g. a dangling symlink target) — a silent empty
# checksum must never be treated as "matches" by coincidence.
sdlc_mm_checksum() {
  local f="$1" line rc
  if command -v shasum >/dev/null 2>&1; then
    line="$(shasum -a 256 -- "$f" 2>/dev/null)"; rc=$?
  elif command -v sha256sum >/dev/null 2>&1; then
    line="$(sha256sum -- "$f" 2>/dev/null)"; rc=$?
  elif command -v cksum >/dev/null 2>&1; then
    line="$(cksum -- "$f" 2>/dev/null)"; rc=$?
  else
    printf 'migrate-memory-root: no shasum, sha256sum or cksum available — cannot verify\n' >&2
    return 1
  fi
  if [ "$rc" -ne 0 ] || [ -z "$line" ]; then
    printf 'migrate-memory-root: cannot read %s to checksum it\n' "$f" >&2
    return 1
  fi
  printf '%s\n' "$line" | awk '{print $1}'
}

# sdlc_mm_realpath <path> -> best-effort canonical absolute path: resolves symlinks in the
# longest EXISTING ancestor (the same way `git rev-parse --show-toplevel` resolves repo_root),
# then re-appends any non-existent trailing components literally. A plain string-prefix
# comparison between repo_root and dest_root would otherwise be foolable whenever one side is
# canonicalized and the other isn't (e.g. macOS's /var -> /private/var), which is exactly what
# would let a destination inside the repo slip past a naive check.
sdlc_mm_realpath() {
  local p="$1" tail="" existing
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  existing="$(cd "$p" 2>/dev/null && pwd -P)" || existing="$p"
  printf '%s%s\n' "$existing" "$tail"
}

# sdlc_mm_dir_occupied <path> -> 0 (true) iff <path> is "not safely empty": either it exists as
# a directory (or a symlink to one) holding at least one entry, or it exists as anything else at
# all (a stray file, a dangling symlink squatting on the name). 1 (false) only for "does not
# exist" or "exists as a genuinely empty directory".
#
# Deliberately NOT `find $path -type f | wc -l` (or any recursive walk): `find` does not descend
# into a directory reached via a symlink, so a destination that IS a symlink to a populated
# external directory reads as empty — the exact gap that let an unguarded `cp -R` clobber real
# external data with neither --force nor a warning. `ls -A` resolves the given path exactly the
# way `cp`/`git rm --cached`/every other tool here will, so its emptiness answer cannot diverge
# from theirs the way `find`'s can.
sdlc_mm_dir_occupied() {
  local p="$1"
  if [ -d "$p" ]; then
    [ -n "$(ls -A "$p" 2>/dev/null)" ] && return 0
    return 1
  fi
  { [ -e "$p" ] || [ -L "$p" ]; } && return 0
  return 1
}

# sdlc_mm_prune_empty_dirs <repo_root> <list_file> — best-effort, deepest-first removal of any
# ancestor directory (under .claude/memories/agents or .claude/memories/reviews) left empty by
# the per-file deletes that precede it. Every candidate is derived from the SAME enumerated
# list_file — never a fresh directory walk. `rmdir` only ever removes a directory that is
# ALREADY empty and never forces anything, so a directory still holding something (e.g. a file
# that raced its way in after enumeration — see sdlc_mm_main) is silently left alone. This
# cleanup can therefore only ever remove less than intended, never more; its failure is not
# itself treated as a delete failure.
sdlc_mm_prune_empty_dirs() {
  local repo_root="$1" list_file="$2" relpath d dirs_file
  dirs_file="$(mktemp 2>/dev/null)" || return 0
  while IFS= read -r -d '' relpath; do
    d="$(dirname "$relpath")"
    while :; do
      case "$d" in
        .claude/memories/agents|.claude/memories/reviews)
          printf '%s\n' "$d" >> "$dirs_file"
          break
          ;;
        .claude/memories|.|/)
          break
          ;;
        *)
          printf '%s\n' "$d" >> "$dirs_file"
          d="$(dirname "$d")"
          ;;
      esac
    done
  done < "$list_file"
  # Deepest-first by slash count (not lexicographic — a plain `sort -r` orders "z" ahead of
  # "a/b" despite "a/b" being deeper), so a child directory is always rmdir'd before its parent.
  awk '{ n = gsub(/\//, "&"); print n "\t" $0 }' "$dirs_file" 2>/dev/null \
    | sort -t "$(printf '\t')" -k1,1nr \
    | cut -f2- \
    | while IFS= read -r d; do
        rmdir -- "$repo_root/$d" 2>/dev/null
      done
  rm -f "$dirs_file"
  return 0
}

# sdlc_mm_verify_entry <repo_root> <dest_root> <tracked-relpath> -> 0 iff the tracked path is a
# plain file (not a symlink) present at BOTH the source and destination with matching checksums.
# Read-only; prints one specific diagnostic and returns 1 on any disagreement.
sdlc_mm_verify_entry() {
  local repo_root="$1" dest_root="$2" relpath="$3"
  local src_abs="$repo_root/$relpath"
  local dest_relpath="${relpath#.claude/memories/}"
  local dest_abs="$dest_root/$dest_relpath"
  if [ -L "$src_abs" ]; then
    printf 'migrate-memory-root: symlinked corpus entries are not supported: %s\n' "$relpath" >&2
    return 1
  fi
  if [ ! -f "$src_abs" ]; then
    printf 'migrate-memory-root: tracked but missing on disk: %s\n' "$relpath" >&2
    return 1
  fi
  if [ ! -f "$dest_abs" ]; then
    printf 'migrate-memory-root: missing in destination: %s\n' "$dest_relpath" >&2
    return 1
  fi
  local s_sum d_sum
  s_sum="$(sdlc_mm_checksum "$src_abs")" || return 1
  d_sum="$(sdlc_mm_checksum "$dest_abs")" || return 1
  if [ "$s_sum" != "$d_sum" ]; then
    printf 'migrate-memory-root: checksum mismatch: %s\n' "$dest_relpath" >&2
    return 1
  fi
  return 0
}

sdlc_mm_main() {
  local dry_run=0 force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --force) force=1 ;;
      -h|--help) usage; return 0 ;;
      *) printf 'migrate-memory-root: unknown argument: %s\n' "$arg" >&2; usage; return 1 ;;
    esac
  done

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'migrate-memory-root: not inside a git repository\n' >&2
    return 1
  }

  # The authoritative source-of-truth list: EXACTLY the paths `git rm --cached` will remove.
  # Enumerated into a real temp file with its exit status checked — never a process substitution
  # here, whose failure `set -uo pipefail` (no `-e`, and `< <(...)` is not a pipeline) cannot see.
  local list_file
  list_file="$(mktemp 2>/dev/null)" || {
    printf 'migrate-memory-root: cannot create a temp file to enumerate the tracked corpus\n' >&2
    return 1
  }
  trap 'rm -f "$list_file"' RETURN
  if ! git -C "$repo_root" ls-files -z -- .claude/memories/agents .claude/memories/reviews > "$list_file"; then
    printf 'migrate-memory-root: git ls-files failed — cannot enumerate the tracked corpus\n' >&2
    return 1
  fi

  local total=0 agents_n=0 reviews_n=0 relpath
  while IFS= read -r -d '' relpath; do
    total=$((total + 1))
    case "$relpath" in
      .claude/memories/agents/*) agents_n=$((agents_n + 1)) ;;
      .claude/memories/reviews/*) reviews_n=$((reviews_n + 1)) ;;
    esac
  done < "$list_file"

  if [ "$total" -eq 0 ]; then
    if [ -d "$repo_root/.claude/memories/agents" ] || [ -d "$repo_root/.claude/memories/reviews" ]; then
      printf 'migrate-memory-root: nothing is tracked under .claude/memories/agents or .claude/memories/reviews, but an untracked directory of that name still exists under %s — resolve manually before re-running\n' \
        "$repo_root/.claude/memories" >&2
      return 1
    fi
    printf 'migrate-memory-root: nothing to migrate — .claude/memories/agents and .claude/memories/reviews are both untracked and absent; already migrated (no-op)\n'
    return 0
  fi
  if [ "$agents_n" -eq 0 ] || [ "$reviews_n" -eq 0 ]; then
    printf 'migrate-memory-root: partial corpus — %s tracked file(s) under agents/, %s under reviews/; refusing to guess, resolve manually\n' \
      "$agents_n" "$reviews_n" >&2
    return 1
  fi

  local dest_root
  dest_root="$(sdlc_memory_root)" || return 1

  local dest_root_real
  dest_root_real="$(sdlc_mm_realpath "$dest_root")"
  case "$dest_root_real" in
    "$repo_root")
      printf 'migrate-memory-root: destination root %s is the repository root — refusing\n' "$dest_root" >&2
      return 1
      ;;
    "$repo_root"/*)
      printf 'migrate-memory-root: destination root %s is inside the repository %s — refusing to copy the corpus into itself\n' \
        "$dest_root" "$repo_root" >&2
      return 1
      ;;
  esac

  local dest_agents="$dest_root/agents"
  local dest_reviews="$dest_root/reviews"
  local dest_nonempty=0
  sdlc_mm_dir_occupied "$dest_agents" && dest_nonempty=1
  sdlc_mm_dir_occupied "$dest_reviews" && dest_nonempty=1
  if [ "$dest_nonempty" -eq 1 ] && [ "$force" -eq 0 ]; then
    printf 'migrate-memory-root: destination already has content under %s (agents/ or reviews/) — pass --force to merge into it\n' \
      "$dest_root" >&2
    return 1
  fi

  # Every tracked path must exist on disk, as a plain file, BEFORE anything destructive runs —
  # a path git still tracks but that is missing from the working tree (e.g. deleted-but-
  # uncommitted) would otherwise be silently dropped from both the copy and the eventual
  # `git rm --cached`, never having been inspected by verification at all.
  local disk_bad=0 abs
  while IFS= read -r -d '' relpath; do
    abs="$repo_root/$relpath"
    if [ -L "$abs" ]; then
      printf 'migrate-memory-root: symlinked corpus entries are not supported: %s\n' "$relpath" >&2
      disk_bad=1
    elif [ ! -f "$abs" ]; then
      printf 'migrate-memory-root: tracked but missing on disk: %s\n' "$relpath" >&2
      disk_bad=1
    fi
  done < "$list_file"
  if [ "$disk_bad" -eq 1 ]; then
    printf 'migrate-memory-root: refusing — the tracked corpus and the working tree disagree; repo left untouched\n' >&2
    return 1
  fi

  # A per-file collision pre-scan against the destination — run UNCONDITIONALLY, never gated
  # behind the dest_nonempty flag above (or behind --force). That flag answering "empty" only
  # means the occupancy probe found nothing at the top two levels; it must never be the SOLE
  # reason a real per-tracked-file collision goes unscanned before a copy that can silently
  # overwrite irreplaceable external data with no git history to recover it from. Checks
  # `-e || -L` (not `-e` alone), so a dangling symlink squatting on the exact destination path
  # still counts as a collision rather than reading as "nothing there".
  local collision=0 dest_relpath dest_abs
  while IFS= read -r -d '' relpath; do
    dest_relpath="${relpath#.claude/memories/}"
    dest_abs="$dest_root/$dest_relpath"
    if [ -e "$dest_abs" ] || [ -L "$dest_abs" ]; then
      printf 'migrate-memory-root: destination already has %s\n' "$dest_relpath" >&2
      collision=1
    fi
  done < "$list_file"
  if [ "$collision" -eq 1 ]; then
    printf 'migrate-memory-root: refusing — one or more tracked files already exist at the destination (even under --force, a collision is never overwritten); repo left untouched\n' >&2
    return 1
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf '[dry-run] would resolve memory root: %s\n' "$dest_root"
    printf '[dry-run] would copy %s tracked file(s): %s -> %s and %s -> %s\n' \
      "$total" "$repo_root/.claude/memories/agents" "$dest_agents" "$repo_root/.claude/memories/reviews" "$dest_reviews"
    printf '[dry-run] would verify every tracked path exists at the destination with a matching checksum\n'
    printf '[dry-run] would run: git -C %s rm --cached --pathspec-from-file=<the enumerated %s tracked paths> --pathspec-file-nul\n' \
      "$repo_root" "$total"
    printf '[dry-run] would delete the %s enumerated working-tree files individually, then prune any directory left empty (never a directory-level rm -rf)\n' \
      "$total"
    printf '[dry-run] would commit the removal, scoped to those two paths\n'
    return 0
  fi

  sdlc_memory_ensure "$dest_root" || return 1

  cp -R "$repo_root/.claude/memories/agents/." "$dest_agents/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$repo_root/.claude/memories/agents" >&2
    return 1
  }
  cp -R "$repo_root/.claude/memories/reviews/." "$dest_reviews/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$repo_root/.claude/memories/reviews" >&2
    return 1
  }

  local matched=0 verify_bad=0
  while IFS= read -r -d '' relpath; do
    if sdlc_mm_verify_entry "$repo_root" "$dest_root" "$relpath"; then
      matched=$((matched + 1))
    else
      verify_bad=1
    fi
  done < "$list_file"
  if [ "$verify_bad" -eq 1 ] || [ "$matched" -ne "$total" ]; then
    printf 'migrate-memory-root: verification FAILED — %s of %s tracked files verified at the destination; repo left untouched, the destination copy is not authoritative, safe to retry\n' \
      "$matched" "$total" >&2
    return 1
  fi
  printf 'migrate-memory-root: verification passed — all %s tracked files match at the destination\n' "$total"

  # --pathspec-from-file on the SAME enumerated list_file used for verification — not a
  # directory pathspec (`-- .claude/memories/agents .claude/memories/reviews`), which `git rm`
  # would re-glob against the LIVE index at execution time. A file staged into that directory
  # after enumeration but before this point would then be removed having never been enumerated,
  # copied, or verified. Reading from the same list makes the verified set and the deleted set
  # identical by construction, matching this script's own stated invariant. No `-r` needed —
  # the list already names individual files, not directories.
  git -C "$repo_root" rm --cached --quiet --pathspec-from-file="$list_file" --pathspec-file-nul || {
    printf 'migrate-memory-root: git rm --cached failed — repo left in its prior committed state; nothing further touched\n' >&2
    return 1
  }

  # Per-file `rm -f` over the SAME enumerated list_file — never a directory-level `rm -rf`,
  # which would delete EVERYTHING physically under those two directories regardless of whether
  # it was ever enumerated, copied, or verified (the same "operate over the exact verified set,
  # nothing broader" discipline as the `git rm --cached` call above, applied to the working-tree
  # side too). Empty ancestor directories are then pruned best-effort; anything left non-empty
  # (e.g. a file that raced its way in after enumeration) is silently left in place rather than
  # forced.
  local rm_rc=0
  while IFS= read -r -d '' relpath; do
    rm -f -- "$repo_root/$relpath" || rm_rc=1
  done < "$list_file"
  sdlc_mm_prune_empty_dirs "$repo_root" "$list_file"
  if [ "$rm_rc" -ne 0 ]; then
    printf 'migrate-memory-root: deleting the working copies failed (rc=%s) — attempting to restore the index so nothing is staged uncommitted\n' \
      "$rm_rc" >&2
    local reset_rc
    git -C "$repo_root" reset -q --pathspec-from-file="$list_file" --pathspec-file-nul 2>/dev/null
    reset_rc=$?
    if [ "$reset_rc" -eq 0 ]; then
      printf 'migrate-memory-root: index restored; inspect %s manually (some files may already be gone) and re-run once the underlying issue is fixed\n' \
        "$repo_root/.claude/memories" >&2
    else
      printf 'migrate-memory-root: index restoration FAILED (git reset exit=%s) — the removal may still be staged; run `git reset -- .claude/memories/agents .claude/memories/reviews` manually before doing anything else, then re-run once the underlying issue is fixed\n' \
        "$reset_rc" >&2
    fi
    return 1
  fi

  git -C "$repo_root" commit --quiet -m 'chore(memory): migrate agent and review memory corpus to the external memory root' \
    -- .claude/memories/agents .claude/memories/reviews || {
    printf 'migrate-memory-root: commit failed — the removal is staged; inspect git status under %s and commit manually\n' \
      "$repo_root" >&2
    return 1
  }

  printf 'migrate-memory-root: migrated %s tracked files to %s; repo committed\n' "$total" "$dest_root"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  sdlc_mm_main "$@"
  exit $?
fi
