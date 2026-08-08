#!/usr/bin/env bash
# migrate-memory-root.sh — NA-102. One-shot migration of the in-repo memory corpus
# (.claude/memories/{agents,reviews}) to the external root resolved by memory-root.sh (NA-101).
#
# usage:
#   migrate-memory-root.sh [--dry-run] [--force]
#
# SAFETY CONTRACT — copy, then verify, then delete, in that order, no exceptions:
#   1. cp -R the two tracked trees to the resolved external root.
#   2. Verify BOTH file count and per-file checksum between source and destination.
#   3. Only if verification passes: git rm -r --cached the two trees, delete the working
#      copies, and commit. A failure anywhere before verification passes leaves the repo
#      byte-for-byte untouched.
#
# Never a raw `mv` — the source stays intact on disk until verification has already succeeded.
#
# Idempotent: once the corpus has been migrated, the source trees no longer exist, so a
# re-run finds nothing to do and exits 0 without touching anything.
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
# memory-root.sh already uses. Non-zero + stderr if none is available.
sdlc_mm_checksum() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v cksum >/dev/null 2>&1; then
    cksum "$f" | awk '{print $1"-"$2}'
  else
    printf 'migrate-memory-root: no shasum, sha256sum or cksum available — cannot verify\n' >&2
    return 1
  fi
}

# sdlc_mm_verify_dir <src-dir> <dest-dir> <label> -> 0 iff file count AND every checksum match.
# Read-only on both trees; prints every mismatch it finds to stderr before returning.
#
# "File count" is deliberately the count of SOURCE files successfully verified at the
# destination (by relative path, then by checksum) — not a raw `find $dest | wc -l` total.
# A raw dest total would false-positive under --force (AC4): merging into a destination that
# already holds unrelated pre-existing files inflates its total without any truncation having
# occurred. Comparing "how many of the N source files verified" against N still catches a
# truncated copy (missing files) exactly as required, without penalising a legitimate merge.
sdlc_mm_verify_dir() {
  local src="$1" dest="$2" label="$3"
  local src_count=0 matched=0 bad=0 f rel s_sum d_sum
  while IFS= read -r f; do
    src_count=$((src_count + 1))
    rel="${f#"$src"/}"
    if [ ! -f "$dest/$rel" ]; then
      printf 'migrate-memory-root: %s missing in destination: %s\n' "$label" "$rel" >&2
      bad=1
      continue
    fi
    s_sum="$(sdlc_mm_checksum "$f")" || return 1
    d_sum="$(sdlc_mm_checksum "$dest/$rel")" || return 1
    if [ "$s_sum" != "$d_sum" ]; then
      printf 'migrate-memory-root: %s checksum mismatch: %s\n' "$label" "$rel" >&2
      bad=1
      continue
    fi
    matched=$((matched + 1))
  done < <(find "$src" -type f)
  if [ "$matched" -ne "$src_count" ]; then
    printf 'migrate-memory-root: %s file count mismatch: %s of %s source files verified at the destination\n' \
      "$label" "$matched" "$src_count" >&2
    bad=1
  fi
  [ "$bad" -eq 0 ]
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

  local src_agents="$repo_root/.claude/memories/agents"
  local src_reviews="$repo_root/.claude/memories/reviews"
  local have_agents=0 have_reviews=0
  [ -d "$src_agents" ] && have_agents=1
  [ -d "$src_reviews" ] && have_reviews=1

  if [ "$have_agents" -eq 0 ] && [ "$have_reviews" -eq 0 ]; then
    printf 'migrate-memory-root: nothing to migrate — %s and %s are both absent; already migrated (no-op)\n' \
      "$src_agents" "$src_reviews"
    return 0
  fi
  if [ "$have_agents" -eq 0 ] || [ "$have_reviews" -eq 0 ]; then
    printf 'migrate-memory-root: partial corpus — exactly one of agents/ or reviews/ is missing under %s/.claude/memories; refusing to guess, resolve manually\n' \
      "$repo_root" >&2
    return 1
  fi

  local dest_root
  dest_root="$(sdlc_memory_root)" || return 1
  local dest_agents="$dest_root/agents"
  local dest_reviews="$dest_root/reviews"

  local dest_nonempty=0
  [ -d "$dest_agents" ] && [ -n "$(find "$dest_agents" -type f 2>/dev/null)" ] && dest_nonempty=1
  [ -d "$dest_reviews" ] && [ -n "$(find "$dest_reviews" -type f 2>/dev/null)" ] && dest_nonempty=1
  if [ "$dest_nonempty" -eq 1 ] && [ "$force" -eq 0 ]; then
    printf 'migrate-memory-root: destination already has content under %s (agents/ or reviews/) — pass --force to merge into it\n' \
      "$dest_root" >&2
    return 1
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf '[dry-run] would resolve memory root: %s\n' "$dest_root"
    printf '[dry-run] would copy: %s -> %s\n' "$src_agents" "$dest_agents"
    printf '[dry-run] would copy: %s -> %s\n' "$src_reviews" "$dest_reviews"
    printf '[dry-run] would verify file count and checksums match between source and destination\n'
    printf '[dry-run] would run: git -C %s rm -r --cached -- .claude/memories/agents .claude/memories/reviews\n' \
      "$repo_root"
    printf '[dry-run] would delete the working copies: %s %s\n' "$src_agents" "$src_reviews"
    printf '[dry-run] would commit the removal\n'
    return 0
  fi

  sdlc_memory_ensure "$dest_root" || return 1

  cp -R "$src_agents/." "$dest_agents/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$src_agents" >&2
    return 1
  }
  cp -R "$src_reviews/." "$dest_reviews/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$src_reviews" >&2
    return 1
  }

  if ! sdlc_mm_verify_dir "$src_agents" "$dest_agents" "agents"; then
    printf 'migrate-memory-root: verification FAILED for agents — repo left untouched; the destination copy is not authoritative, safe to retry\n' >&2
    return 1
  fi
  if ! sdlc_mm_verify_dir "$src_reviews" "$dest_reviews" "reviews"; then
    printf 'migrate-memory-root: verification FAILED for reviews — repo left untouched; the destination copy is not authoritative, safe to retry\n' >&2
    return 1
  fi
  printf 'migrate-memory-root: verification passed — file count and checksums match for agents and reviews\n'

  git -C "$repo_root" rm -r --cached --quiet -- .claude/memories/agents .claude/memories/reviews || {
    printf 'migrate-memory-root: git rm --cached failed — repo left in its prior committed state; nothing further touched\n' >&2
    return 1
  }

  rm -rf "$src_agents" "$src_reviews"

  git -C "$repo_root" commit --quiet -m 'chore(memory): migrate agent and review memory corpus to the external memory root' || {
    printf 'migrate-memory-root: commit failed — the removal is staged; inspect git status under %s and commit manually\n' \
      "$repo_root" >&2
    return 1
  }

  printf 'migrate-memory-root: migrated %s and %s to %s; repo committed\n' "$src_agents" "$src_reviews" "$dest_root"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  sdlc_mm_main "$@"
  exit $?
fi
